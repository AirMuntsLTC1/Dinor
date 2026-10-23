import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'dinor_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  final supabase = Supabase.instance.client;


  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 1. Tell Supabase to open the Google Login
      final success = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.dinor.dinor://login-callback',
        scopes: 'https://www.googleapis.com/auth/gmail.send', // We need this for sending emails
      );

      // 2. Once logged in, Supabase holds the Google tokens
      if (success) {
        // 3. We can grab the provider_token (Access Token) and refresh_token directly!
        final session = supabase.auth.currentSession;
        
        if (session != null) {
          final refreshToken = session.providerRefreshToken; // THIS IS THE TOKEN YOU NEED

          debugPrint("REFRESH TOKEN: $refreshToken");
          
          // 4. Save it to your database so the Edge Function can use it
          if (refreshToken != null) {
            await supabase.from('google_tokens').upsert({
              'id': 1,
              'refresh_token': refreshToken,
            });
          }
        }
        
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google Login Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'auth-otp', 
        body: {'email': email, 'action': 'send'}
      );
      
      if (response.status == 200 && response.data['success'] == true) {
        setState(() => _isOtpSent = true);
      } else {
        setState(() => _errorMessage = response.data['error'] ?? 'Failed to send code.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'auth-otp', 
        body: {'email': email, 'action': 'verify', 'code': otp}
      );

      if (response.status == 200 && response.data['session'] != null) {
        final sessionData = response.data['session'];
        
        // Log the user in using the real session from the backend
        await supabase.auth.setSession(
          sessionData['access_token'],
          sessionData['refresh_token'],
        );

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        setState(() => _errorMessage = response.data['error'] ?? 'Invalid code. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.chat_bubble_rounded, size: 80, color: brandBlue),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Dinor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your email to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: DinorTheme.textGrey, fontSize: 16),
              ),
              const SizedBox(height: 48),

              if (!_isOtpSent) ...[
                // EMAIL INPUT
                Container(
                  decoration: BoxDecoration(
                    color: DinorTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: DinorTheme.softShadow,
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      hintStyle: TextStyle(color: DinorTheme.textGrey),
                      prefixIcon: Icon(Icons.email_outlined, color: DinorTheme.textGrey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ] else ...[
                // OTP INPUT
                Container(
                  decoration: BoxDecoration(
                    color: DinorTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: DinorTheme.softShadow,
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(color: DinorTheme.textGrey, letterSpacing: 8),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify & Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => setState(() => _isOtpSent = false),
                  child: const Text('Change Email', style: TextStyle(color: DinorTheme.textGrey)),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
