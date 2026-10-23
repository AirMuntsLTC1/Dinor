import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../ffi/dinor_bindings.dart';
import '../chat/ai_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'ai_avatar.dart';
import 'media_picker.dart';
import 'emoji_picker.dart';

class Message {
  final String text;
  final bool isMe;
  final bool isImage;
  final String? caption;
  Message(this.text, this.isMe, {this.isImage = false, this.caption});
}

class ChatScreen extends StatefulWidget {
  final String title;
  final bool isAi;

  const ChatScreen({super.key, required this.title, this.isAi = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final GlobalKey _inputKey = GlobalKey();
  bool _isAiTyping = false;
  
  // Long press menu state
  Message? _selectedMessage;
  int? _selectedMessageIndex;
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    if (widget.isAi) {
      _messages.add(Message("Hello! I am Dinor AI. Ask me anything and I'll search the web.", false));
    }
  }

  void _sendMessage() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    // 1. Format via C++ safely
    String text = rawText;
    try {
      text = DinorCore.load().formatMessage(rawText);
    } catch (e) {
      debugPrint("C++ Format failed, using raw text: $e");
    }

    // 2. Get input position for animation
    final RenderBox? inputBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset startPosition = inputBox != null
        ? inputBox.localToGlobal(Offset.zero)
        : const Offset(0, 0);

    // 3. Clear input field
    _textController.clear();

    // 4. Trigger animation
    _showFlyingMessage(text, startPosition);

    // 5. Add message
    setState(() {
      _messages.add(Message(text, true));
    });
    _scrollToBottom();

    // 6. Trigger AI
    if (widget.isAi) {
      _triggerAiResponse(text);
    }
  }

  void _triggerAiResponse(String userText) async {
    setState(() => _isAiTyping = true);
    _scrollToBottom();

    try {
      String response = await DinorAI.getResponse(userText);
      if (!mounted) return;

      setState(() {
        _isAiTyping = false;
        _messages.add(Message(response, false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        _messages.add(Message("Error connecting to AI: $e", false));
      });
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
    // Don't open multiple menus at once
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
            // Invisible full-screen click catcher to dismiss the menu
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMessageMenu,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // The Actual Menu
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Forward
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.black54, size: 20),
                          onPressed: () {
                            _closeMessageMenu();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forward clicked')));
                          },
                        ),
                        // Copy
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.black54, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            _closeMessageMenu();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                          },
                        ),
                        // Delete
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _messages.removeAt(index);
                            });
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

  void _showFlyingMessage(String text, Offset startPos) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        return _FlyingMessageWidget(
          text: text,
          startPosition: startPos,
          onComplete: () {},
        );
      },
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 400), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        leading: _selectedMessage != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _closeMessageMenu,
              )
            : null,
        title: Row(
          children: [
            if (widget.isAi && _selectedMessage == null) ...[
              AnimatedAIAvatar(size: 32, isThinking: _isAiTyping),
              const SizedBox(width: 12),
            ],
            if (_selectedMessage != null)
              const Text('Message Options')
            else
              Text(widget.title),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              cacheExtent: 1000, // Pre-renders messages slightly off-screen for smooth scrolling
              addAutomaticKeepAlives: true, // Keeps images in memory while scrolling
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
                      color: msg.isMe ? brandBlue : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: msg.isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: msg.isMe ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: msg.isImage
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: msg.text.startsWith('http')
                                    ? Image.network(
                                        msg.text,
                                        width: 200,
                                        fit: BoxFit.cover,
                                        cacheWidth: 400, // Decodes at half-res to save RAM and GPU
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                                      )
                                    : Image.file(
                                        File(msg.text),
                                        width: 200,
                                        fit: BoxFit.cover,
                                        cacheWidth: 400, // Decodes at half-res to save RAM and GPU
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                                      ),
                              ),
                              if (msg.caption != null && msg.caption!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    msg.caption!,
                                    style: TextStyle(
                                      color: msg.isMe ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isMe ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                  );

                // Wrap AI messages with the avatar
                if (!msg.isMe && widget.isAi) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 8),
                        child: AnimatedAIAvatar(size: 28),
                      ),
                      Flexible(child: messageBubble),
                    ],
                  );
                }

                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _showMessageMenu(context, index, msg),
                    child: AnimatedScale(
                      scale: _selectedMessageIndex == index ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: messageBubble,
                    ),
                  ),
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Media Icon
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
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

                        // Add each selected image to the chat
                        for (var asset in selectedAssets) {
                          final file = await asset.file;
                          if (file != null) {
                            setState(() {
                              _messages.add(Message(
                                file.path, 
                                true, 
                                isImage: true, 
                                caption: caption.isNotEmpty ? caption : null
                              ));
                            });
                          }
                        }
                        _scrollToBottom();
                      }
                    },
                  ),
                  
                  // Text Input
                  Expanded(
                    child: Container(
                      key: _inputKey,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.black45),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  
                  // Emoji & GIF Icon (Merged)
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CustomEmojiPicker(
                          onEmojiSelected: (emoji) {
                            // Add the emoji to the text field
                            final newText = _textController.text + emoji;
                            _textController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(offset: newText.length),
                            );
                          },
                          onGifSelected: (url) {
                            // Close picker and send GIF message
                            Navigator.pop(context);
                            setState(() {
                              _messages.add(Message(url, true, isImage: true));
                            });
                            _scrollToBottom();
                          },
                        ),
                      );
                    },
                  ),
                  


                  const SizedBox(width: 4),

                  // Send Button
                  CircleAvatar(
                    backgroundColor: brandBlue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
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

class _FlyingMessageWidget extends StatefulWidget {
  final String text;
  final Offset startPosition;
  final VoidCallback onComplete;

  const _FlyingMessageWidget({
    required this.text,
    required this.startPosition,
    required this.onComplete,
  });

  @override
  State<_FlyingMessageWidget> createState() => _FlyingMessageWidgetState();
}

class _FlyingMessageWidgetState extends State<_FlyingMessageWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final endPosition = Offset(screenSize.width - 100, screenSize.height * 0.2);
    final controlPoint = Offset(
      widget.startPosition.dx + (endPosition.dx - widget.startPosition.dx) / 2 + 50,
      widget.startPosition.dy - 150,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final x = pow(1 - t, 2) * widget.startPosition.dx + 2 * (1 - t) * t * controlPoint.dx + pow(t, 2) * endPosition.dx;
        final y = pow(1 - t, 2) * widget.startPosition.dy + 2 * (1 - t) * t * controlPoint.dy + pow(t, 2) * endPosition.dy;

        return Positioned(
          left: x.toDouble(),
          top: y.toDouble(),
          child: IgnorePointer(
            child: Opacity(
              opacity: 1.0 - t,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF229ED9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
