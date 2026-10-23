import 'package:flutter/material.dart';
import 'ui/home_screen.dart';
import 'ui/dinor_theme.dart';

void main() => runApp(const DinorApp());

class DinorApp extends StatelessWidget {
  const DinorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dinor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark, // Force Dark Mode
        scaffoldBackgroundColor: DinorTheme.bgDark,
        splashFactory: NoSplash.splashFactory, 
        highlightColor: Colors.transparent,    
        colorScheme: ColorScheme.fromSeed(
          seedColor: DinorTheme.brandBlue,
          brightness: Brightness.dark,
          primary: DinorTheme.brandBlue,
          onPrimary: Colors.white,
          surface: DinorTheme.surfaceDark,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Roboto', color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'Roboto', color: Colors.white),
          titleMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DinorTheme.bgDark, // Match the dark background
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: DinorTheme.brandBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
