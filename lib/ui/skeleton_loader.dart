import 'package:flutter/material.dart';

import 'dinor_theme.dart';

/// One shared shimmer driver. Every skeleton in the app uses this, so the
/// loading look is consistent and each screen runs a single animation controller.
class ShimmerArea extends StatefulWidget {
  final Widget Function(BuildContext context, Animation<double> shimmer) builder;
  const ShimmerArea({super.key, required this.builder});

  @override
  State<ShimmerArea> createState() => _ShimmerAreaState();
}

class _ShimmerAreaState extends State<ShimmerArea> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// A single shimmering placeholder block.
class ShimmerBlock extends StatelessWidget {
  final Animation<double> shimmer;
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const ShimmerBlock({
    super.key,
    required this.shimmer,
    required this.height,
    this.width,
    this.radius = 12,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final t = shimmer.value * 2 - 1; // -1 .. 1
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + t, 0),
              end: Alignment(1.5 + t, 0),
              colors: [
                DinorTheme.surfaceDark,
                DinorTheme.surfaceDark.withValues(alpha: 0.35),
                DinorTheme.surfaceDark,
              ],
              stops: const [0.2, 0.5, 0.8],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for the conversation list shown on startup when no cache exists.
class ConversationListSkeleton extends StatelessWidget {
  final int rows;
  const ConversationListSkeleton({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerArea(
      builder: (context, shimmer) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: rows,
        itemBuilder: (context, _) => Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: DinorTheme.surfaceDark.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              ShimmerBlock(shimmer: shimmer, height: 44, width: 44, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBlock(shimmer: shimmer, height: 14, width: 140, radius: 6),
                    const SizedBox(height: 8),
                    ShimmerBlock(shimmer: shimmer, height: 12, width: 220, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for chat messages shown while a conversation loads with no cache.
class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerArea(
      builder: (context, shimmer) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          final isMe = index.isEven;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShimmerBlock(
                shimmer: shimmer,
                height: 45,
                width: isMe ? 180 : 220,
                radius: 16,
              ),
            ),
          );
        },
      ),
    );
  }
}
