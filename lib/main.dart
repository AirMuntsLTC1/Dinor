import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/login_screen.dart';
import 'ui/home_screen.dart';
import 'ui/dinor_theme.dart';
import 'ui/internet_banner.dart';
import 'chat/message_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw the first frame immediately; startup work happens behind the splash.
  runApp(const DinorBootstrap());
}

/// Runs the slow startup work (Supabase, local cache) while a splash is shown.
class DinorBootstrap extends StatefulWidget {
  const DinorBootstrap({super.key});

  @override
  State<DinorBootstrap> createState() => _DinorBootstrapState();
}

class _DinorBootstrapState extends State<DinorBootstrap> {
  late Future<void> _startup = _init();

  static Future<void> _init() async {
    // Run independent work in parallel: cache read and Supabase setup.
    await Future.wait([
      LocalCache.preload(),
      Supabase.initialize(
        url: 'https://skvgbzftnbditpztqewl.supabase.co',
        publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdmdiemZ0bmJkaXRwenRxZXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NDA1NDEsImV4cCI6MjEwODMxNjU0MX0.zHDtiHxAUBb-n2HpXjBbOHaO58pp4SgF__r9zq5JmkM',
      ),
    ]);
  }

  void _retry() => setState(() => _startup = _init());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          return const DinorApp();
        }
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: DinorTheme.bgDark, useMaterial3: true),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Couldn't start Dinor", style: TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _retry, child: const Text('Retry', style: TextStyle(color: DinorTheme.brandBlue))),
                  ],
                ),
              ),
            ),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: DinorTheme.bgDark, useMaterial3: true),
          home: const Scaffold(
            backgroundColor: DinorTheme.bgDark,
            body: Center(child: Text('Dinor', style: TextStyle(color: DinorTheme.brandBlue, fontSize: 32, fontWeight: FontWeight.bold))),
          ),
        );
      },
    );
  }
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      // Seed with the current session so the right screen shows on the first frame.
      initialData: AuthState(AuthChangeEvent.initialSession, auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
