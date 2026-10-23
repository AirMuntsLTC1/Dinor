import 'package:flutter/material.dart';

class DinorTheme {
  static const Color brandBlue = Color(0xFF229ED9);
  static const Color bgLight = Color(0xFFF2F5F8); // Soft grey-blue background
  static const Color surfaceWhite = Colors.white;
  
  // Soft floating shadow (Plastic/Glassmorphism look)
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: brandBlue.withValues(alpha: 0.08),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  // The shiny gradient for primary buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
