import 'package:flutter/material.dart';

class AnimatedEmoji extends StatefulWidget {
  final String emoji;
  final double size;
  final VoidCallback? onTap; // New callback

  const AnimatedEmoji({super.key, required this.emoji, this.size = 40, this.onTap});

  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Springy scale animation
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    // Subtle 3D rotation
    _rotateAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void playAnimation() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        playAnimation();
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scaleByDouble(_scaleAnimation.value, _scaleAnimation.value, _scaleAnimation.value, 1.0)
              ..rotateZ(_rotateAnimation.value),
            alignment: Alignment.center,
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: widget.size,
                // Crisp text rendering for emojis
                fontFamily: 'Noto Color Emoji', 
              ),
            ),
          );
        },
      ),
    );
  }
}
