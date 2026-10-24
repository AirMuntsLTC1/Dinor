import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../ffi/dinor_bindings.dart';
import '../chat/ai_service.dart';
import '../chat/message_cache.dart';
import '../chat/chat_service.dart';
import 'ai_avatar.dart';
import 'media_picker.dart';
import 'emoji_picker.dart';
import 'media_viewer.dart';
import 'dinor_theme.dart';
import 'call_screen.dart';
import 'skeleton_loader.dart';

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
  bool _isLoadingMessages = true;
  
  // Long press state
  Message? _selectedMessage;
  int? _selectedMessageIndex;
  List<Message> _selectedAlbumImages = [];
  OverlayEntry? _menuOverlay;

  final supabase = Supabase.instance.client;
  RealtimeChannel? _chatChannel;
  String? _currentUserId;
  String? _resolvedConversationId;

  @override
  void initState() {
    super.initState();
    if (widget.isAi) {
      _messages.add(Message('ai_1', "Hello! I am Dinor AI. Ask me anything and I'll search the web.", false));
      _isLoadingMessages = false;
    } else {
      // 1. INSTANT LOAD: Check if we have cached messages
      if (widget.conversationId != null) {
        final cached = MessageCache.getMessages(widget.conversationId!);
        if (cached != null && cached.isNotEmpty) {
          _messages.addAll(cached);
          _isLoadingMessages = false; // Turn off skeleton immediately
        }
      }
      
      // 2. BACKGROUND FETCH: Connect to Supabase and update
      _initSupabaseChat();
    }
  }

  Future<void> _initSupabaseChat() async {
    _currentUserId = supabase.auth.currentUser?.id;
    
    // If we don't have a conversation ID yet (new chat), create it
    if (_resolvedConversationId == null && widget.otherUserId != null) {
      final newId = await ChatService.getOrCreateConversation(widget.otherUserId!);
      // We can't update the widget's final field, so we'll use a local state variable
      _resolvedConversationId = newId;
    } else {
      _resolvedConversationId = _resolvedConversationId;
    }

    if (_resolvedConversationId != null) {
      ChatService.markAsRead(_resolvedConversationId!);
    }
    
    _fetchMessages();

    _chatChannel = supabase.channel('public:messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final newMsg = payload.newRecord;
          if (mounted && newMsg['conversation_id'] == _resolvedConversationId) {
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
                  caption: newMsg['caption'],
                ));
              });
              _scrollToBottom();
              
              // Update cache
              if (_resolvedConversationId != null) {
                MessageCache.saveMessages(_resolvedConversationId!, _messages);
              }
            }
          }
        }
      ).subscribe();
  }

  Future<void> _fetchMessages() async {
    if (_resolvedConversationId == null) {
       // If it's a new chat, create the conversation in the background
       if (widget.otherUserId != null) {
         final newId = await ChatService.getOrCreateConversation(widget.otherUserId!);
         _resolvedConversationId = newId;
         // Now that we have an ID, we can start listening
         _initSupabaseChat(); 
       }
       setState(() => _isLoadingMessages = false);
       return;
    }
    try {
      final data = await supabase.from('messages').select().eq('conversation_id', _resolvedConversationId ?? '').order('created_at', ascending: true);
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
            caption: row['caption'],
          ));
        }
      });
      _scrollToBottom();
      
      // 3. SAVE TO CACHE: Update the memory cache with fresh data
      if (_resolvedConversationId != null) {
        MessageCache.saveMessages(_resolvedConversationId!, _messages);
      }
      
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMessages = false);
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
        'conversation_id': _resolvedConversationId,
        'is_read': false,
      }).select('id').single();

      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = Message(response['id'].toString(), text, true, isRead: false, status: MessageStatus.sent);
        }
      });
      
      // Update cache instantly
      if (_resolvedConversationId != null) {
        MessageCache.saveMessages(_resolvedConversationId!, _messages);
      }

      await supabase.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _resolvedConversationId!);

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
    
    List<Message> albumImages = [];
    if (msg.albumId != null) {
      albumImages = _messages.where((m) => m.albumId == msg.albumId).toList();
    } else {
      albumImages = [msg];
    }

    setState(() {
      _selectedMessage = msg;
      _selectedMessageIndex = index;
      _selectedAlbumImages = albumImages;
    });

    _menuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 1. Blurred Background
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMessageMenu,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            
            // 2. Selected Media Carousel (Un-blurred, shrunk)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              height: MediaQuery.of(context).size.height * 0.5, // Force a height!
              left: 20,
              right: 20,
              child: PageView.builder(
                itemCount: _selectedAlbumImages.length,
                itemBuilder: (context, i) {
                  final img = _selectedAlbumImages[i];
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: img.text,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          memCacheWidth: 1000, 
                          placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                          errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. The Action Menu
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15, // Top center
              left: MediaQuery.of(context).size.width / 2 - 100,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Opacity(opacity: val, child: child),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E242B),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.white70, size: 22),
                          onPressed: _closeMessageMenu,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70, size: 22),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            _closeMessageMenu();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 22),
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

    Overlay.of(context).insert(_menuOverlay!);
  }

  void _deleteMessage(Message msg) {
    List<Message> toDelete = [];
    if (msg.albumId != null) {
      toDelete = _messages.where((m) => m.albumId == msg.albumId).toList();
    } else {
      toDelete = [msg];
    }

    setState(() {
      _messages.removeWhere((m) => toDelete.any((d) => d.id == m.id));
    });

    for (var m in toDelete) {
      if (!m.id.startsWith('temp_')) {
        supabase.from('messages').delete().eq('id', m.id).then((_) {
          debugPrint("Deleted message ${m.id} from Supabase");
        }).catchError((e) {
          debugPrint("Failed to delete message ${m.id}: $e");
        });
      }
    }
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
    const double gap = 2.0;
    const double totalSize = 260.0;

    if (count == 1) {
      return _buildSingleImage(images[0]);
    } else if (count == 2) {
      return Row(
        children: [
          Expanded(child: _buildGridImage(images[0])),
          const SizedBox(width: gap),
          Expanded(child: _buildGridImage(images[1])),
        ],
      );
    } else if (count == 3) {
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
    } else if (count == 4) {
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
                  Expanded(child: _buildGridImage(images[3])),
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
                        Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          child: Center(
                            child: Text(
                              '+${count - 4}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
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
        memCacheWidth: 520,
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
        memCacheWidth: 520,
        placeholder: (c, u) => Container(color: Colors.grey[800]),
        errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white)),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, int index, {bool isOverlay = false}) {
    Widget messageBubble;
                
    if (msg.isImage) {
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
                          onTap: isOverlay ? null : () {
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
                          child: CachedNetworkImage(
                            imageUrl: msg.text, 
                            width: 240, 
                            fit: BoxFit.cover, 
                            memCacheWidth: 480, 
                            placeholder: (c, u) => Container(width: 240, height: 200, color: Colors.grey[800], child: const Center(child: CircularProgressIndicator(color: Colors.white)))
                          ),
                        )
                      : Image.file(File(msg.text), width: 240, fit: BoxFit.cover, cacheWidth: 480),
                  if (msg.text.contains('.mp4') || msg.text.contains('video'))
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.pause, color: Colors.white, size: 32)),
                ],
              ),
            ),
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

    return messageBubble;
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedMessage != null ? Colors.transparent : DinorTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _selectedMessage != null ? [] : DinorTheme.softShadow,
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
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
                    
                    // Call Icon
                    if (!widget.isAi && widget.otherUserId != null && _selectedMessage == null)
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.white, size: 22),
                        onPressed: () {
                          if (_resolvedConversationId != null && widget.otherUserId != null) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => CallScreen(
                                  receiverName: widget.title,
                                  receiverId: widget.otherUserId,
                                  conversationId: _resolvedConversationId!,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: _isLoadingMessages 
              ? const MessageSkeleton() 
              : ListView.builder(
                  controller: _scrollController,
                  physics: _selectedMessage != null ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  // ignore: deprecated_member_use
                  cacheExtent: 1500.0,
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

                    // --- ALBUM GRID LOGIC ---
                    if (msg.isImage && msg.albumId != null) {
                      final albumImages = _messages.where((m) => m.albumId == msg.albumId).toList();
                      if (albumImages.isNotEmpty && albumImages.first.id == msg.id) {
                        String? albumCaption;
                        for (var i in albumImages) {
                          if (i.caption != null && i.caption!.isNotEmpty) {
                            albumCaption = i.caption;
                            break;
                          }
                        }

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
                                    caption: albumCaption,
                                    timestamp: DateTime.now(),
                                  ),
                                ),
                              );
                            },
                            onLongPress: () => _showMessageMenu(context, index, msg),
                            child: AnimatedScale(
                              scale: _selectedMessageIndex == index ? 0.95 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: Column(
                                crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    width: 260,
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: _buildAlbumGrid(albumImages, msg.isMe),
                                  ),
                                  if (albumCaption != null && albumCaption.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: msg.isMe ? DinorTheme.primaryGradient : null,
                                        color: msg.isMe ? null : DinorTheme.surfaceDark,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(albumCaption, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                    // --- END ALBUM LOGIC ---

                    return Align(
                      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Builder(
                        builder: (bubbleContext) {
                          return GestureDetector(
                            onLongPress: () => _showMessageMenu(bubbleContext, index, msg),
                            child: AnimatedScale(
                              scale: _selectedMessageIndex == index ? 0.95 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: _buildMessageBubble(msg, index),
                            ),
                          );
                        }
                      ),
                    );
                  },
                ),
          ),
          
          // Chat Composer
          IgnorePointer(
            ignoring: _selectedMessage != null, // Freeze composer
            child: Container(
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

                                List<File> cachedFiles = [];
                                for (var asset in selectedAssets) {
                                  final file = await asset.file;
                                  if (file != null) cachedFiles.add(file);
                                }

                                if (cachedFiles.isEmpty) return;

                                if (widget.isAi) {
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
                                        'conversation_id': _resolvedConversationId,
                                        'is_read': false,
                                        'album_id': albumId,
                                        'caption': (i == 0 && caption.isNotEmpty) ? caption : null,
                                      }).select('id').single();

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

                                  await supabase.from('conversations').update({
                                    'last_message': '📷 ${cachedFiles.length} Photos',
                                    'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                  }).eq('id', _resolvedConversationId!);
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
                                    } else if (_currentUserId != null && _resolvedConversationId != null) {
                                      int cppTime = 0;
                                      try { cppTime = DinorCore.load().getFastTimestamp(); } catch (_) {}
                                      final tempId = 'temp_$cppTime';
                                      setState(() => _messages.add(Message(tempId, url, true, isImage: true, status: MessageStatus.sending)));
                                      _scrollToBottom();

                                      try {
                                        await CachedNetworkImage.evictFromCache(url);

                                        final response = await supabase.from('messages').insert({
                                          'sender_id': _currentUserId,
                                          'content': url,
                                          'is_image': true,
                                          'conversation_id': _resolvedConversationId,
                                          'is_read': false,
                                        }).select('id').single();

                                        setState(() {
                                          final index = _messages.indexWhere((m) => m.id == tempId);
                                          if (index != -1) _messages[index] = Message(response['id'].toString(), url, true, isImage: true, status: MessageStatus.sent);
                                        });
                                        
                                        await supabase.from('conversations').update({
                                          'last_message': '🎬 GIF',
                                          'last_message_time': DateTime.now().toUtc().toIso8601String(),
                                        }).eq('id', _resolvedConversationId!);
                                      } catch (e) {
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
