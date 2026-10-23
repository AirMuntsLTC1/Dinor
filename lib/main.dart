import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/login_screen.dart';
import 'ui/home_screen.dart';
import 'ui/dinor_theme.dart';
import 'ui/internet_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://skvgbzftnbditpztqewl.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdmdiemZ0bmJkaXRwenRxZXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NDA1NDEsImV4cCI6MjEwODMxNjU0MX0.zHDtiHxAUBb-n2HpXjBbOHaO58pp4SgF__r9zq5JmkM',
  );
  
  runApp(const DinorApp());
}

class DinorApp extends StatelessWidget {
  const DinorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return InternetBanner(
      child: MaterialApp(
        title: 'Dinor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
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
            backgroundColor: DinorTheme.bgDark,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// This widget listens to Supabase session changes automatically
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. Show loading while Supabase reads the local storage
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: DinorTheme.bgDark,
            body: Center(child: CircularProgressIndicator(color: DinorTheme.brandBlue)),
          );
        }

        // 2. Get the current session
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        // 3. Route based on session
        if (session != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
