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
        fontFamily: 'Roboto', // Set global font to Roboto
        splashFactory: NoSplash.splashFactory, // Removes tap highlights globally
        highlightColor: Colors.transparent,    // Removes the long-press text highlight
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
          onPrimary: Colors.white, // White text on blue buttons/appbar
          surface: Colors.white,   // Light background
          onSurface: Colors.black87,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
          bodyLarge: TextStyle(fontFamily: 'Roboto'),
          titleMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
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
