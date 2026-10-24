import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dinor_theme.dart';

class MediaViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final String senderName;
  final String senderAvatar;
  final String? caption;
  final DateTime timestamp;

  const MediaViewer({
    super.key,
    required this.mediaUrls,
    required this.initialIndex,
    required this.senderName,
    required this.senderAvatar,
    this.caption,
    required this.timestamp,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap anywhere to close the viewer
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // 1. The Swipeable Images
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.mediaUrls.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.mediaUrls[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                    ),
                  ),
                );
              },
            ),

            // 2. Top Header (Profile & Name)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: DinorTheme.brandBlue,
                      child: Text(
                        widget.senderName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.senderName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(widget.timestamp),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Caption & Page Indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.caption != null && widget.caption!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          widget.caption!,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    
                    // Swipe indicator (if multiple images)
                    if (widget.mediaUrls.length > 1)
                      Center(
                        child: Text(
                          '${_currentIndex + 1} / ${widget.mediaUrls.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
