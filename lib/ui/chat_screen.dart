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
import 'media_viewer.dart';
import 'package:intl/intl.dart';
import 'dinor_theme.dart';

enum MessageStatus { sending, sent, failed }

class Message {
  final String id;
  final String text;
  final bool isMe;
  final bool isImage;
  final bool isRead;
  final String? caption;
  final MessageStatus status;
  final String? albumId;

  Message(this.id, this.text, this.isMe, {
    this.isImage = false, 
    this.caption, 
    this.isRead = false, 
    this.status = MessageStatus.sent,
    this.albumId,
  });
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
    if (widget.conversationId != null) ChatService.markAsRead(widget.conversationId!);
    _fetchMessages();

    _chatChannel = supabase.channel('public:messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final newMsg = payload.newRecord;
          if (mounted && newMsg['conversation_id'] == widget.conversationId) {
            final exists = _messages.any((m) => m.id == newMsg['id'].toString());
            if (!exists) {
              setState(() {
                _messages.add(Message(
                  newMsg['id'].toString(),
                  newMsg['content'],
                  newMsg['sender_id'] == _currentUserId,
                  isImage: newMsg['is_image'] ?? false,
                  isRead: newMsg['is_read'] ?? false,
                  albumId: newMsg['album_id'],
                ));
              });
              _scrollToBottom();
            }
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
            albumId: row['album_id'],
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
      text = core.batchSanitize(rawText);
    } catch (e) {
      debugPrint("C++ Sanitize failed: $e");
    }

    _textController.clear();

    if (widget.isAi) {
      setState(() => _messages.add(Message(DateTime.now().toString(), text, true)));
      _scrollToBottom();
      _triggerAiResponse(text);
      return;
    }

    if (_currentUserId == null) return;

    int cppTime = 0;
    try { cppTime = DinorCore.load().getFastTimestamp(); } catch (_) {}
    final tempId = 'temp_$cppTime';

    setState(() {
      _messages.add(Message(tempId, text, true, status: MessageStatus.sending));
    });
    _scrollToBottom();

    try {
      final response = await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'content': text,
        'is_image': false,
        'conversation_id': widget.conversationId,
        'is_read': false,
      }).select('id').single();

      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = Message(response['id'].toString(), text, true, isRead: false, status: MessageStatus.sent);
        }
      });

      await supabase.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.conversationId!);

    } catch (e) {
      debugPrint("Failed to send: $e");
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = Message(tempId, "Failed to send", true, status: MessageStatus.failed);
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
                            _deleteMessage(msg);
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


  void _deleteMessage(Message msg) {
    // 1. Determine which messages to delete
    List<Message> toDelete = [];
    
    // If it's part of a photo album, delete the whole album
    if (msg.albumId != null) {
      toDelete = _messages.where((m) => m.albumId == msg.albumId).toList();
    } 
    // Otherwise, it's a single message (Text, GIF, or Single Photo)
    else {
      toDelete = [msg];
    }

    // 2. INSTANTLY remove from UI (Optimistic Update)
    setState(() {
      _messages.removeWhere((m) => toDelete.any((d) => d.id == m.id));
    });

    // 3. Delete from Supabase in the background
    for (var m in toDelete) {
      // Only delete from DB if it's a real message (saved in DB)
      if (!m.id.startsWith('temp_')) {
        supabase.from('messages').delete().eq('id', m.id).then((_) {
          debugPrint("Deleted message ${m.id} from Supabase");
        }).catchError((e) {
          debugPrint("Failed to delete message ${m.id}: $e");
        });
      }
    }
    
    // Note: If the deleted message was the last message, the Home Screen will 
    // automatically update its preview via real-time when the DB deletion completes.
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

  Widget _buildMessageStatus(Message msg) {
    if (msg.status == MessageStatus.sending) {
      return const _AnimatedSendingDots();
    } else if (msg.status == MessageStatus.sent) {
      return const Icon(Icons.check_circle, color: Color(0xFF229ED9), size: 14);
    } else if (msg.status == MessageStatus.failed) {
      return const Icon(Icons.error, color: Colors.redAccent, size: 14);
    }
    return const SizedBox.shrink();
  }

  Widget _buildAlbumGrid(List<Message> images, bool isMe) {
    int count = images.length;
    int displayCount = count > 4 ? 3 : count;
    // Telegram uses a very tight 2px gap
    const double gap = 2.0;
    const double totalSize = 260.0;

    if (displayCount == 1) {
      return _buildSingleImage(images[0]);
    } else if (displayCount == 2) {
      return Row(
        children: [
          Expanded(child: _buildGridImage(images[0])),
          const SizedBox(width: gap),
          Expanded(child: _buildGridImage(images[1])),
        ],
      );
    } else if (displayCount == 3) {
      return SizedBox(
        height: totalSize,
        child: Row(
          children: [
            Expanded(child: _buildGridImage(images[0])),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildGridImage(images[1])),
                  const SizedBox(height: gap),
                  Expanded(child: _buildGridImage(images[2])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: totalSize,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildGridImage(images[0])),
                  const SizedBox(width: gap),
                  Expanded(child: _buildGridImage(images[1])),
                ],
              ),
            ),
            const SizedBox(height: gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildGridImage(images[2])),
                  const SizedBox(width: gap),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildGridImage(images[3]),
                        if (count > 4)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Center(
                              child: Text('+${count - 4}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSingleImage(Message img) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: img.text,
        fit: BoxFit.cover,
        placeholder: (c, u) => Container(color: Colors.grey[800], height: 260, child: const Center(child: CircularProgressIndicator())),
        errorWidget: (c, u, e) => Container(color: Colors.grey[800], height: 260, child: const Icon(Icons.broken_image)),
      ),
    );
  }

  Widget _buildGridImage(Message img) {
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: img.text,
        fit: BoxFit.cover,
        placeholder: (c, u) => Container(color: Colors.grey[800]),
        errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white)),
      ),
    );
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
                        child: Text(
                          widget.title[0],
                          style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedMessage != null ? 'Message Options' : widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedMessage == null && widget.isAi)
                            const Text('Online', style: TextStyle(color: brandBlue, fontSize: 12))
                          else if (_selectedMessage == null)
                            const Text('last seen recently', style: TextStyle(color: DinorTheme.textGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Chat Messages
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

                // --- TELEGRAM ALBUM GRID LOGIC ---
                if (msg.isImage && msg.albumId != null) {
                  final albumImages = _messages.where((m) => m.albumId == msg.albumId).toList();
                  if (albumImages.isNotEmpty && albumImages.first.id == msg.id) {
                    return Align(
                      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          final urls = albumImages.map((m) => m.text).toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaViewer(
                                mediaUrls: urls,
                                initialIndex: 0,
                                senderName: msg.isMe ? "You" : widget.title,
                                senderAvatar: "",
                                caption: albumImages.first.caption,
                                timestamp: DateTime.now(),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          width: 260,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildAlbumGrid(albumImages, msg.isMe),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }
                // --- END ALBUM LOGIC ---

                Widget messageBubble;
                
                if (msg.isImage) {
                  // Raw Media (No Bubble Background)
                  messageBubble = Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              msg.text.startsWith('http')
                                  ? GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewer(
            mediaUrls: [msg.text],
            initialIndex: 0,
            senderName: msg.isMe ? "You" : widget.title,
            senderAvatar: "",
            caption: msg.caption,
            timestamp: DateTime.now(),
          ),
        ),
      );
    },
    child: CachedNetworkImage(imageUrl: msg.text, width: 240, fit: BoxFit.cover, memCacheWidth: 480, placeholder: (c, u) => Container(width: 240, height: 200, color: Colors.grey[800], child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
  )
                                  : Image.file(File(msg.text), width: 240, fit: BoxFit.cover, cacheWidth: 480),
                              if (msg.text.contains('.mp4') || msg.text.contains('video'))
                                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.pause, color: Colors.white, size: 32)),
                            ],
                          ),
                        ),
                        // If there's a caption, give the text its own small bubble
                        if (msg.caption != null && msg.caption!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: msg.isMe ? DinorTheme.primaryGradient : null,
                              color: msg.isMe ? null : DinorTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(msg.caption!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ),
                      ],
                    ),
                  );
                } else {
                  // Text Message (With Bubble Background)
                  messageBubble = Container(
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
                    child: Text(
                      msg.text, 
                      style: TextStyle(
                        color: msg.isMe 
                            ? (msg.isRead ? Colors.grey[400] : Colors.white) 
                            : Colors.white, 
                        fontSize: 16
                      )
                    ),
                  );
                }

                if (msg.isMe) {
                  messageBubble = Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      messageBubble,
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: _buildMessageStatus(msg),
                      ),
                    ],
                  );
                }

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
                                final albumId = 'album_${DateTime.now().millisecondsSinceEpoch}';

                                if (selectedAssets.isEmpty) return;

                                // 1. CACHE ALL FILES LOCALLY FIRST
                                List<File> cachedFiles = [];
                                for (var asset in selectedAssets) {
                                  final file = await asset.file;
                                  if (file != null) cachedFiles.add(file);
                                }

                                if (cachedFiles.isEmpty) return;

                                if (widget.isAi) {
                                  // AI handling (unchanged)
                                  for (var file in cachedFiles) {
                                    final bytes = await file.readAsBytes();
                                    final base64String = base64Encode(bytes);
                                    setState(() {
                                      _messages.add(Message(DateTime.now().toString(), file.path, true, isImage: true, caption: caption.isNotEmpty ? caption : null, albumId: albumId));
                                    });
                                    _scrollToBottom();
                                    _triggerAiResponse(caption.isNotEmpty ? caption : "Examine this image.", imageBase64: base64String);
                                  }
                                } else if (_currentUserId != null) {
                                  // 2. SHOW ALL LOCAL IMAGES AT ONCE WITH SENDING DOTS
                                  List<Message> tempMessages = [];
                                  int cppTime = 0;
                                  try { cppTime = DinorCore.load().getFastTimestamp(); } catch (_) {}

                                  for (int i = 0; i < cachedFiles.length; i++) {
                                    final file = cachedFiles[i];
                                    final tempId = 'temp_${cppTime}_$i';
                                    tempMessages.add(Message(
                                      tempId, 
                                      file.path, 
                                      true, 
                                      isImage: true, 
                                      caption: (i == 0 && caption.isNotEmpty) ? caption : null, 
                                      status: MessageStatus.sending, 
                                      albumId: albumId
                                    ));
                                  }

                                  setState(() => _messages.addAll(tempMessages));
                                  _scrollToBottom();

                                  // 3. UPLOAD ALL FILES SIMULTANEOUSLY IN BACKGROUND
                                  for (int i = 0; i < cachedFiles.length; i++) {
                                    final file = cachedFiles[i];
                                    final tempId = tempMessages[i].id;

                                    try {
                                      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}_$_currentUserId.jpg';
                                      await supabase.storage.from('chat_media').upload(fileName, file);
                                      final publicUrl = supabase.storage.from('chat_media').getPublicUrl(fileName);

                                      final response = await supabase.from('messages').insert({
                                        'sender_id': _currentUserId,
                                        'content': publicUrl,
                                        'is_image': true,
                                        'conversation_id': widget.conversationId,
                                        'is_read': false,
                                        'album_id': albumId,
                                      }).select('id').single();

                                      // Replace temp message with sent message
                                      setState(() {
                                        final index = _messages.indexWhere((m) => m.id == tempId);
                                        if (index != -1) {
                                          _messages[index] = Message(
                                            response['id'].toString(), 
                                            publicUrl, 
                                            true, 
                                            isImage: true, 
                                            caption: tempMessages[i].caption, 
                                            status: MessageStatus.sent, 
                                            albumId: albumId
                                          );
                                        }
                                      });

                                    } catch (e) {
                                      // Mark as failed if upload fails
                                      setState(() {
                                        final index = _messages.indexWhere((m) => m.id == tempId);
                                        if (index != -1) {
                                          _messages[index] = Message(
                                            tempId, 
                                            file.path, 
                                            true, 
                                            isImage: true, 
                                            status: MessageStatus.failed, 
                                            albumId: albumId
                                          );
                                        }
                                      });
                                    }
                                  }

                                  // Update conversation last message
                                  await supabase.from('conversations').update({
                                    'last_message': '📷 ${cachedFiles.length} Photos',
                                    'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                  }).eq('id', widget.conversationId!);
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
                                      int cppTime = 0;
                                      try { cppTime = DinorCore.load().getFastTimestamp(); } catch (_) {}
                                      final tempId = 'temp_$cppTime';
                                      setState(() => _messages.add(Message(tempId, url, true, isImage: true, status: MessageStatus.sending)));
                                      _scrollToBottom();

                                      try {
                                        // 1. Pre-cache the GIF locally so it shows instantly
                                        // CachedNetworkImage caches automatically, we just evict the old one if it exists
                                        await CachedNetworkImage.evictFromCache(url);

                                        // 2. Save to database
                                        final response = await supabase.from('messages').insert({
                                          'sender_id': _currentUserId,
                                          'content': url,
                                          'is_image': true,
                                          'conversation_id': widget.conversationId,
                                          'is_read': false,
                                        }).select('id').single();

                                        setState(() {
                                          final index = _messages.indexWhere((m) => m.id == tempId);
                                          if (index != -1) _messages[index] = Message(response['id'].toString(), url, true, isImage: true, status: MessageStatus.sent);
                                        });
                                        
                                        await supabase.from('conversations').update({
                                          'last_message': '🎬 GIF',
                                          'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                        }).eq('id', widget.conversationId!);
                                      } catch (e) {
                                        // Mark as failed if caching or saving fails
                                        setState(() {
                                          final index = _messages.indexWhere((m) => m.id == tempId);
                                          if (index != -1) _messages[index] = Message(tempId, url, true, isImage: true, status: MessageStatus.failed);
                                        });
                                      }
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

class _AnimatedSendingDots extends StatefulWidget {
  const _AnimatedSendingDots();

  @override
  State<_AnimatedSendingDots> createState() => _AnimatedSendingDotsState();
}

class _AnimatedSendingDotsState extends State<_AnimatedSendingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double scale = 1.0;
            try {
              scale = DinorCore.load().getAnimationScale(t, index);
            } catch (e) {
              double delay = index * 0.2;
              double progress = (t - delay) % 1.0;
              if (progress < 0) progress += 1.0;
              scale = 1.0 + (0.6 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: DinorTheme.textGrey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
