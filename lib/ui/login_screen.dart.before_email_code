import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      // 1. Initialize the Native Google Sign-In (v7+ API)
      await GoogleSignIn.instance.initialize(
        serverClientId: '358994083024-bn76a0pgeac7vndqan8u8l313scec8rd.apps.googleusercontent.com',
      );

      // 2. Show the native account selector
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 3. Get the authentication tokens (v7+ API)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final idToken = googleAuth.idToken;
      // Note: accessToken is no longer provided directly in v7. 
      // Supabase can use just the idToken for login.

      if (idToken == null) {
        throw Exception('No ID Token found. Check your Google Client ID configuration.');
      }

      // 4. Log into Supabase using the Google tokens
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // 5. Navigate to Home
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google Login Failed: $e');
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
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
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
