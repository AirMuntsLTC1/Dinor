import 'package:flutter/material.dart';
import 'dinor_theme.dart';

class MessageSkeleton extends StatefulWidget {
  const MessageSkeleton({super.key});

  @override
  State<MessageSkeleton> createState() => _MessageSkeletonState();
}

class _MessageSkeletonState extends State<MessageSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: isMe ? 180 : 220,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      DinorTheme.surfaceDark,
                      DinorTheme.surfaceDark.withValues(alpha: 0.5),
                      DinorTheme.surfaceDark,
                    ],
                    stops: [0.0, (index % 2 == 0 ? 0.5 : 0.4) + _animation.value * 0.2, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
