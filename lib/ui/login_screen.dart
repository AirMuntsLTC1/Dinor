import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'dinor_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final supabase = Supabase.instance.client;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tell Supabase to initiate the Google OAuth flow
      final success = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // This URL must be added to your Google Cloud Console Authorized Redirect URIs
        redirectTo: 'https://skvgbzftnbditpztqewl.supabase.co/auth/v1/callback',
      );

      if (success) {
        // Once successful, navigate to Home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() => _errorMessage = 'Login was cancelled.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);
    const Color googleWhite = Color(0xFFF1F1F1);

    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo / Title
              const Icon(Icons.chat_bubble_rounded, size: 90, color: brandBlue),
              const SizedBox(height: 24),
              const Text(
                'Dinor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect with friends and AI in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DinorTheme.textGrey, fontSize: 16),
              ),
              const SizedBox(height: 60),

              // Google Login Button
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: brandBlue))
              else
                ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: googleWhite,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Official Google 'G' Logo shape (using a custom icon)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // Base white
                        ),
                        child: const Center(
                          // We use the text 'G' as a fallback for the logo
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.blueAccent, // Blue for Google
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Roboto', // Standard font
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),

              const SizedBox(height: 40),

              // Terms of Service text
              const Text(
                'By continuing, you agree to Dinor\'s Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DinorTheme.textGrey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
