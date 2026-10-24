import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedAIAvatar extends StatefulWidget {
  final double size;
  final bool isThinking;

  const AnimatedAIAvatar({
    super.key,
    this.size = 40,
    this.isThinking = false,
  });

  @override
  State<AnimatedAIAvatar> createState() => _AnimatedAIAvatarState();
}

class _AnimatedAIAvatarState extends State<AnimatedAIAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // Only animate at 30fps instead of 60fps to stop frame drops
    _controller.repeat(period: const Duration(seconds: 3));
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AIAvatarPainter(
            animationValue: _controller.value,
            isThinking: widget.isThinking,
          ),
        );
      },
    );
  }
}

class _AIAvatarPainter extends CustomPainter {
  final double animationValue;
  final bool isThinking;

  _AIAvatarPainter({required this.animationValue, required this.isThinking});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final t = animationValue;

    // 1. Draw the base 3D Orb (Gradient makes it look spherical)
    final orbPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF80E5FF), // Bright highlight
          Color(0xFF24A1DE), // Brand blue
          Color(0xFF005A8A), // Dark shadow edge
        ],
        stops: [0.1, 0.6, 1.0],
        center: Alignment(-0.3, -0.3), // Off-center highlight for 3D effect
        radius: 0.9,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, orbPaint);

    // 2. Draw rotating 3D rings (Orbits)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.6);

    final ringPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF24A1DE).withValues(alpha: 0.8);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Ring 1 (Tilted)
    canvas.save();
    canvas.rotate(t * 2 * pi);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 1.8, height: radius * 0.6),
      ringPaint,
    );
    canvas.restore();

    // Ring 2 (Different angle)
    canvas.save();
    canvas.rotate(-t * 2 * pi + pi / 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 1.6, height: radius * 1.2),
      ringPaint2,
    );
    canvas.restore();

    canvas.restore();

    // 3. Draw a glowing "core" in the center
    final corePulse = isThinking ? (sin(t * 10) * 0.2 + 0.8) : 0.5;
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: corePulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(center, radius * 0.3, corePaint);

    // 4. Outer glow if thinking
    if (isThinking) {
      final glowPaint = Paint()
        ..color = const Color(0xFF24A1DE).withValues(alpha: 0.3 * corePulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AIAvatarPainter oldDelegate) {
    return true; // Must be true to rotate the rings, but we reduced the frame rate
  }
}
