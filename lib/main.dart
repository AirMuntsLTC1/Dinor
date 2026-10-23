import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() => runApp(const DinorApp());

class DinorApp extends StatelessWidget {
  const DinorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dinor Light Blue Brand Color
    const Color brandBlue = Color(0xFF229ED9);

    return MaterialApp(
      title: 'Dinor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
          onPrimary: Colors.white, // White text on blue buttons/appbar
          surface: Colors.white,   // Light background
          onSurface: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white, // White title and icons
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
