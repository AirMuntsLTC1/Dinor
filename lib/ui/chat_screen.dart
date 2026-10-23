import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../ffi/dinor_bindings.dart';
import '../chat/ai_service.dart';
import '../chat/chat_service.dart';
import 'ai_avatar.dart';
import 'media_picker.dart';
import 'emoji_picker.dart';
import 'dinor_theme.dart';

class Message {
  final String id;
  final String text;
  final bool isMe;
  final bool isImage;
  final bool isRead;
  final String? caption;
  final bool isSending; // Optimistic state

  Message(this.id, this.text, this.isMe, {this.isImage = false, this.caption, this.isRead = false, this.isSending = false});
}

class ChatScreen extends StatefulWidget {
  final String title;
  final bool isAi;
  final String? conversationId;
  final String? otherUserId;

  const ChatScreen({super.key, required this.title, this.isAi = false, this.conversationId, this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final GlobalKey _inputKey = GlobalKey();
  bool _isAiTyping = false;
  Message? _selectedMessage;
  int? _selectedMessageIndex;
  OverlayEntry? _menuOverlay;
  

  final supabase = Supabase.instance.client;
  RealtimeChannel? _chatChannel;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.isAi) {
      _messages.add(Message('ai_1', "Hello! I am Dinor AI. Ask me anything and I'll search the web.", false));
    } else {
      _initSupabaseChat();
    }
  }

  Future<void> _initSupabaseChat() async {
    _currentUserId = supabase.auth.currentUser?.id;
    
    // Mark messages as read IMMEDIATELY when opening
    if (widget.conversationId != null) {
      ChatService.markAsRead(widget.conversationId!);
    }
    
    _fetchMessages();

    _chatChannel = supabase.channel('public:messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final newMsg = payload.newRecord;
          if (mounted && newMsg['conversation_id'] == widget.conversationId) {
            // Check if we already have this message in our list (prevents double-sending)
            final exists = _messages.any((m) => m.id == newMsg['id'].toString());
            if (!exists) {
              setState(() {
                _messages.add(Message(
                  newMsg['id'].toString(),
                  newMsg['content'],
                  newMsg['sender_id'] == _currentUserId,
                  isImage: newMsg['is_image'] ?? false,
                  isRead: newMsg['is_read'] ?? false,
                ));
              });
              _scrollToBottom();
            }
            // Always mark as read when a new message arrives
            if (widget.conversationId != null && newMsg['sender_id'] != _currentUserId) {
              ChatService.markAsRead(widget.conversationId!);
            }
          }
        }
      ).subscribe();
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await supabase.from('messages').select().eq('conversation_id', widget.conversationId ?? '').order('created_at', ascending: true);
      setState(() {
        _messages.clear();
        for (var row in data) {
          _messages.add(Message(
            row['id'].toString(),
            row['content'],
            row['sender_id'] == _currentUserId,
            isImage: row['is_image'] ?? false,
            isRead: row['is_read'] ?? false,
          ));
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    String text = rawText;
    try {
      final core = DinorCore.load();
      text = core.formatMessage(core.sanitizeInput(rawText));
    } catch (e) {
      debugPrint("C++ Format failed: $e");
    }

    _textController.clear();

    if (widget.isAi) {
      setState(() => _messages.add(Message(DateTime.now().toString(), text, true)));
      _scrollToBottom();
      _triggerAiResponse(text);
      return;
    }

    if (_currentUserId == null) return;

    // 1. OPTIMISTIC UPDATE: Show message instantly
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add(Message(tempId, text, true, isSending: true));
    });
    _scrollToBottom();

    // 2. Save to Database in background
    try {
      final response = await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'content': text,
        'is_image': false,
        'conversation_id': widget.conversationId,
        'is_read': false,
      }).select('id').single();

      // 3. Replace temp message with real DB message
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = Message(
            response['id'].toString(),
            text,
            true,
            isRead: false,
          );
        }
      });

      // 4. Update conversation last message
      await supabase.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.conversationId!);

    } catch (e) {
      debugPrint("Failed to send: $e");
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = Message(tempId, "Failed to send", true, isSending: false);
        }
      });
    }
  }

  void _triggerAiResponse(String userText, {String? imageBase64}) async {
    setState(() => _isAiTyping = true);
    _scrollToBottom();
    try {
      String response = await DinorAI.getResponse(userText, imageBase64: imageBase64);
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        _messages.add(Message(DateTime.now().toString(), response, false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiTyping = false);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  void _showMessageMenu(BuildContext context, int index, Message msg) {
    _closeMessageMenu();
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox bubbleBox = context.findRenderObject() as RenderBox;
    final Offset position = bubbleBox.localToGlobal(Offset.zero, ancestor: overlay);

    setState(() {
      _selectedMessage = msg;
      _selectedMessageIndex = index;
    });

    _menuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMessageMenu,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: position.dy - 50,
              left: msg.isMe ? position.dx - 60 : position.dx,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    alignment: msg.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: DinorTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: DinorTheme.softShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.white70, size: 20),
                          onPressed: _closeMessageMenu,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            _closeMessageMenu();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() => _messages.removeAt(index));
                            _closeMessageMenu();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    final overlayState = Overlay.of(context);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _menuOverlay != null) overlayState.insert(_menuOverlay!);
    });
  }

  void _closeMessageMenu() {
    if (_menuOverlay != null) {
      _menuOverlay!.remove();
      _menuOverlay = null;
      setState(() {
        _selectedMessage = null;
        _selectedMessageIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      body: Column(
        children: [
          // Custom Floating Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DinorTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: DinorTheme.softShadow,
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          turns: animation,
                          child: ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: _selectedMessage != null
                          ? IconButton(
                              key: const ValueKey('close_button'),
                              icon: const Icon(Icons.close, color: Colors.white, size: 22),
                              onPressed: _closeMessageMenu,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : IconButton(
                              key: const ValueKey('back_button'),
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.isAi)
                      AnimatedAIAvatar(size: 36, isThinking: _isAiTyping)
                    else
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: brandBlue.withValues(alpha: 0.2),
                        child: Text(widget.title[0], style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              // ignore: deprecated_member_use
              cacheExtent: 1000.0,
              itemCount: _messages.length + (_isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isAiTyping) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Dinor AI is searching...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                  );
                }

                final msg = _messages[index];
                Widget messageBubble = Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: msg.isMe ? DinorTheme.primaryGradient : null,
                      color: msg.isMe ? null : DinorTheme.surfaceDark,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: msg.isMe ? const Radius.circular(20) : const Radius.circular(4),
                        bottomRight: msg.isMe ? const Radius.circular(4) : const Radius.circular(20),
                      ),
                    ),
                    child: msg.isImage
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    msg.text.startsWith('http')
                                        ? CachedNetworkImage(imageUrl: msg.text, width: 200, fit: BoxFit.cover, memCacheWidth: 400, placeholder: (c, u) => const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(color: Colors.white))))
                                        : Image.file(File(msg.text), width: 200, fit: BoxFit.cover, cacheWidth: 400),
                                    if (msg.text.contains('.mp4') || msg.text.contains('video'))
                                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.pause, color: Colors.white, size: 32)),
                                  ],
                                ),
                              ),
                              if (msg.caption != null && msg.caption!.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(msg.caption!, style: const TextStyle(color: Colors.white, fontSize: 14))),
                            ],
                          )
                        : Text(
                            msg.text, 
                            style: TextStyle(
                              // If my message: White if unread, Grey if read. If other's message: Always white.
                              color: msg.isMe 
                                  ? (msg.isRead ? Colors.grey[400] : Colors.white) 
                                  : Colors.white, 
                              fontSize: 16
                            )
                          ),
                  );

                final interactiveBubble = Builder(
                  builder: (bubbleContext) {
                    return GestureDetector(
                      onLongPress: () => _showMessageMenu(bubbleContext, index, msg),
                      child: AnimatedScale(
                        scale: _selectedMessageIndex == index ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: messageBubble,
                      ),
                    );
                  }
                );

                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: interactiveBubble,
                );
              },
            ),
          ),
          
          // Chat Composer
          Container(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      key: _inputKey,
                      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                      decoration: BoxDecoration(
                        color: DinorTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: DinorTheme.softShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_photo_alternate_outlined, color: DinorTheme.textGrey, size: 22),
                            onPressed: () async {
                              final result = await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const CustomMediaPicker(),
                              );

                              if (result != null) {
                                final List<AssetEntity> selectedAssets = result['media'];
                                final String caption = result['caption'];

                                for (var asset in selectedAssets) {
                                  final file = await asset.file;
                                  if (file != null) {
                                    if (widget.isAi) {
                                      final bytes = await file.readAsBytes();
                                      final base64String = base64Encode(bytes);
                                      setState(() {
                                        _messages.add(Message(DateTime.now().toString(), file.path, true, isImage: true, caption: caption.isNotEmpty ? caption : null));
                                      });
                                      _scrollToBottom();
                                      _triggerAiResponse(caption.isNotEmpty ? caption : "Examine this image.", imageBase64: base64String);
                                    } else if (_currentUserId != null) {
                                      // Optimistic Image upload
                                      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                                      setState(() => _messages.add(Message(tempId, file.path, true, isImage: true, caption: caption.isNotEmpty ? caption : null, isSending: true)));
                                      _scrollToBottom();

                                      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_currentUserId.jpg';
                                      await supabase.storage.from('chat_media').upload(fileName, file);
                                      final publicUrl = supabase.storage.from('chat_media').getPublicUrl(fileName);

                                      final response = await supabase.from('messages').insert({
                                        'sender_id': _currentUserId,
                                        'content': publicUrl,
                                        'is_image': true,
                                        'conversation_id': widget.conversationId,
                                        'is_read': false,
                                      }).select('id').single();

                                      setState(() {
                                        final index = _messages.indexWhere((m) => m.id == tempId);
                                        if (index != -1) _messages[index] = Message(response['id'].toString(), publicUrl, true, isImage: true, caption: caption.isNotEmpty ? caption : null);
                                      });

                                      await supabase.from('conversations').update({
                                        'last_message': '📷 Photo',
                                        'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                      }).eq('id', widget.conversationId!);
                                    }
                                  }
                                }
                              }
                            },
                          ),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: TextField(
                                controller: _textController,
                                textCapitalization: TextCapitalization.sentences,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  hintStyle: TextStyle(color: DinorTheme.textGrey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: DinorTheme.textGrey, size: 22),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CustomEmojiPicker(
                                  onEmojiSelected: (emoji) {
                                    final newText = _textController.text + emoji;
                                   _textController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
                                  },
                                  onGifSelected: (url) async {
                                    Navigator.pop(context);
                                    if (widget.isAi) {
                                      setState(() => _messages.add(Message(DateTime.now().toString(), url, true, isImage: true)));
                                      _scrollToBottom();
                                    } else if (_currentUserId != null && widget.conversationId != null) {
                                      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                                      setState(() => _messages.add(Message(tempId, url, true, isImage: true, isSending: true)));
                                      _scrollToBottom();

                                      final response = await supabase.from('messages').insert({
                                        'sender_id': _currentUserId,
                                        'content': url,
                                        'is_image': true,
                                        'conversation_id': widget.conversationId,
                                        'is_read': false,
                                      }).select('id').single();

                                      setState(() {
                                        final index = _messages.indexWhere((m) => m.id == tempId);
                                        if (index != -1) _messages[index] = Message(response['id'].toString(), url, true, isImage: true);
                                      });
                                      
                                      await supabase.from('conversations').update({
                                        'last_message': '🎬 GIF',
                                        'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                      }).eq('id', widget.conversationId!);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),

                  CircleAvatar(
                    backgroundColor: brandBlue,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
