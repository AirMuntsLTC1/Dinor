import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat/call_service.dart';

/// Full-screen audio call. Reflects real WebRTC state from [CallService].
///
/// Pass [incomingCallId] when answering a call that someone else started.
class CallScreen extends StatefulWidget {
  final String receiverName;
  final String? receiverId;
  final String conversationId;
  final String? incomingCallId;

  const CallScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
    required this.conversationId,
    this.incomingCallId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _ticker;
  int _secondsElapsed = 0;
  bool _started = false;
  bool _closing = false;
  bool get _isIncoming => widget.incomingCallId != null;

  @override
  void initState() {
    super.initState();
    CallService.phase.addListener(_onPhaseChanged);
    CallService.connectedAtMs.addListener(_onConnectedChanged);
    _start();
  }

  Future<void> _start() async {
    _started = true;
    if (_isIncoming) {
      await CallService.acceptCall(widget.incomingCallId!);
    } else if (widget.receiverId != null) {
      await CallService.startCall(widget.receiverId!, widget.conversationId);
    }
    // If the service never left idle (e.g. call already in progress), close.
    if (mounted && CallService.phase.value == CallPhase.idle && CallService.lastEndReason == 'failed') {
      _finish();
    }
  }

  void _onConnectedChanged() {
    if (CallService.connectedAtMs.value != null && _ticker == null && mounted) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final start = CallService.connectedAtMs.value;
        if (start == null) return;
        setState(() {
          _secondsElapsed = (DateTime.now().millisecondsSinceEpoch - start) ~/ 1000;
        });
      });
    }
  }

  void _onPhaseChanged() {
    if (!mounted) return;
    setState(() {});
    // Phase returns to idle when the call is over (ended, declined, missed, failed).
    if (_started && CallService.phase.value == CallPhase.idle) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    _ticker?.cancel();
    CallService.phase.removeListener(_onPhaseChanged);
    CallService.connectedAtMs.removeListener(_onConnectedChanged);

    await _logCallIfNeeded();

    if (mounted) {
      // Brief pause so the user sees "Call ended" / "No answer".
      // Failures stay on screen long enough to read the reason.
      final failed = CallService.lastEndReason == 'failed';
      await Future.delayed(Duration(milliseconds: failed ? 6000 : 700));
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Only the caller writes the call log, so each call produces one entry.
  Future<void> _logCallIfNeeded() async {
    if (_isIncoming) return;
    final reason = CallService.lastEndReason;
    final connectedAt = CallService.connectedAtMs.value;
    final wasConnected = _secondsElapsed > 0 || connectedAt != null;
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    String? text;
    if (wasConnected) {
      text = '📞 Outgoing call (Duration: ${_formatTime(_secondsElapsed)})';
    } else if (reason == 'missed' || reason == 'declined') {
      text = reason == 'declined' ? '📞 Call declined' : '📞 Missed call';
    }
    if (text == null) return;

    try {
      await supabase.from('messages').insert({
        'sender_id': userId,
        'content': text,
        'is_image': false,
        'conversation_id': widget.conversationId,
        'is_read': true,
      });
      await supabase.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.conversationId);
    } catch (e) {
      debugPrint('Failed to log call: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _statusText(CallPhase phase, bool closing) {
    if (closing) {
      switch (CallService.lastEndReason) {
        case 'declined': return 'Call declined';
        case 'missed': return 'No answer';
        case 'failed': return 'Call failed';
        default: return 'Call ended';
      }
    }
    switch (phase) {
      case CallPhase.calling: return 'Calling…';
      case CallPhase.connecting: return 'Connecting…';
      case CallPhase.connected: return _formatTime(_secondsElapsed);
      case CallPhase.idle: return _isIncoming ? 'Connecting…' : 'Calling…';
    }
  }

  Future<void> _endPressed() async {
    await CallService.endCall(reason: 'ended');
    // endCall returns to idle, which triggers _finish via the listener.
  }

@override
  void dispose() {
    _ticker?.cancel();
    CallService.phase.removeListener(_onPhaseChanged);
    CallService.connectedAtMs.removeListener(_onConnectedChanged);
    CallService.endCall(reason: 'ended');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = CallService.phase.value;
    final connected = phase == CallPhase.connected;
    final name = widget.receiverName;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF80AB), Color(0xFFC51162)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                _statusText(phase, _closing),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 2),
              ),
              const SizedBox(height: 60),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 10)],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              if (_closing && CallService.lastErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    CallService.lastErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              const Spacer(),
              if (!connected && !_closing) const AnimatedCallingDots(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: GestureDetector(
                  onTap: _closing ? null : _endPressed,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
            double progress = (t - index * 0.2) % 1.0;
            if (progress < 0) progress += 1.0;
            final scale = 1.0 + (0.8 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: scale,
                child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            );
          }),
        );
      },
    );
  }
}
