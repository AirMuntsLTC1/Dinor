import 'package:flutter/material.dart';

class DinorTheme {
  static const Color brandBlue = Color(0xFF229ED9);
  
  // Dark Theme Colors based on your screenshot
  static const Color bgDark = Color(0xFF14181C);      // Deep dark background
  static const Color surfaceDark = Color(0xFF1E242B); // Slightly lighter dark for cards
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFF8B9AAF);    // Soft grey for subtitles
  
  // Soft glowing shadow for dark mode
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.02), // Subtle highlight for 3D effect
      blurRadius: 2,
      spreadRadius: 0,
      offset: const Offset(0, -1),
    ),
  ];

  // The shiny gradient for primary buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}


============================================================
