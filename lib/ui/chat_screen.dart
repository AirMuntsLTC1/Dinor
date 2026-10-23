import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../ffi/dinor_bindings.dart';

class Message {
  final String text;
  final bool isMe;
  Message(this.text, this.isMe);
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
  final GlobalKey _inputKey = GlobalKey(); // Used to track input position

  @override
  void initState() {
    super.initState();
    if (widget.isAi) {
      _messages.add(Message("Hello! I am Dinor AI. How can I help you today?", false));
    }
  }

  void _sendMessage() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;
    
    // Use C++ core to format the text
    final text = DinorCore.load().formatMessage(rawText);

    // 1. Get the position of the input field for the flying animation
    final RenderBox? inputBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset startPosition = inputBox != null
        ? inputBox.localToGlobal(Offset.zero)
        : const Offset(0, 0);

    // 2. Clear text immediately
    _textController.clear();

    // 3. Trigger the flying animation
    _showFlyingMessage(text, startPosition);

    // 4. Add the actual message after a tiny delay (so it looks like the flying text landed)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _messages.add(Message(text, true));
      });
      _scrollToBottom();

      // 5. If it's the AI chat, trigger a response
      if (widget.isAi) {
        _triggerAiResponse(text);
      }
    });
  }

  void _triggerAiResponse(String userText) {
    // Simulate AI thinking delay
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      String response = "I received your message: '$userText'. (Soon I will be connected to a real AI!)";
      
      // Simple logic for demonstration
      if (userText.toLowerCase().contains("hello") || userText.toLowerCase().contains("hi")) {
        response = "Hello there! How can I assist you today?";
      } else if (userText.toLowerCase().contains("dinor")) {
        response = "Dinor is a secure, fast chat system built with Flutter and C++!";
      }

      setState(() {
        _messages.add(Message(response, false));
      });
      _scrollToBottom();
    });
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

  // The Telegram-style "Flying" animation
  void _showFlyingMessage(String text, Offset startPos) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        return _FlyingMessageWidget(
          text: text,
          startPosition: startPos,
          onComplete: () {
            // This is handled by the Stateful widget inside
          },
        );
      },
    );

    overlay.insert(overlayEntry);
    // Remove from overlay after animation completes
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
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
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
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      key: _inputKey, // Key for tracking position
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
                  const SizedBox(width: 8),
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

// Widget that handles the actual flying physics
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
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
    // Target position: top right (approximate location of sent messages)
    final screenSize = MediaQuery.of(context).size;
    final endPosition = Offset(screenSize.width - 100, screenSize.height * 0.2);
    
    // Calculate a curved path using a sine wave
    final controlPoint = Offset(
      widget.startPosition.dx + (endPosition.dx - widget.startPosition.dx) / 2 + 50,
      widget.startPosition.dy - 150, // Arc upwards
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        
        // Quadratic Bezier curve calculation
        final x = pow(1 - t, 2) * widget.startPosition.dx + 
                  2 * (1 - t) * t * controlPoint.dx + 
                  pow(t, 2) * endPosition.dx;
        final y = pow(1 - t, 2) * widget.startPosition.dy + 
                  2 * (1 - t) * t * controlPoint.dy + 
                  pow(t, 2) * endPosition.dy;

        return Positioned(
          left: x.toDouble(),
          top: y.toDouble(),
          child: Opacity(
            opacity: 1.0 - t, // Fade out as it reaches the top
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
        );
      },
    );
  }
}
