import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/call_service.dart';

class CallScreen extends StatefulWidget {
  final String receiverName;
  final String? receiverId;
  final String conversationId;

  const CallScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
    required this.conversationId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String _status = 'Calling';
  bool _isEnded = false;
  
  // Timer logic
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    if (widget.receiverId != null) {
      await CallService.startCall(widget.receiverId!, widget.conversationId);
    }
    
    // Simulate the call being picked up after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isEnded) {
        setState(() {
          _status = 'Connected';
          _isConnected = true;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    setState(() => _isEnded = true);
    await CallService.endCall();
    
    // Log the call in the chat
    if (_isConnected) {
      // Insert a call message into Supabase
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser!.id;
        
        String callDuration = _formatTime(_secondsElapsed);
        // Check if I am the caller or receiver to format the message correctly
        // Since this is a simple implementation, we assume the current user is the caller for this screen
        String callText = "📞 Outgoing call (Duration: $callDuration)";
        
        await supabase.from('messages').insert({
          'sender_id': userId,
          'content': callText,
          'is_image': false,
          'conversation_id': widget.conversationId,
          'is_read': true, // Call logs are read by default
        });

        await supabase.from('conversations').update({
          'last_message': callText,
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.conversationId);

      } catch (e) {
        debugPrint("Failed to log call: $e");
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF80AB), // Pink
              Color(0xFFC51162), // Deep Pink/Magenta
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Status Text
              Text(
                _isConnected ? _formatTime(_secondsElapsed) : '$_status...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Big Profile Circle
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Receiver Name
              Text(
                widget.receiverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const Spacer(),
              
              // Calling Dots Animation (Only show if not connected)
              if (!_isEnded && !_isConnected) const AnimatedCallingDots(),
              
              const Spacer(),
              
              // End Call Button
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedCallingDots extends StatefulWidget {
  const AnimatedCallingDots({super.key});

  @override
  State<AnimatedCallingDots> createState() => _AnimatedCallingDotsState();
}

class _AnimatedCallingDotsState extends State<AnimatedCallingDots> with SingleTickerProviderStateMixin {
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            double scale = 1.0;
            double delay = index * 0.2;
            double progress = (t - delay) % 1.0;
            if (progress < 0) progress += 1.0;
            scale = 1.0 + (0.8 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
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
