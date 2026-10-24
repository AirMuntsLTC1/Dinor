import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'dinor_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _statusMessage;

  static const Color brandBlue = Color(0xFF229ED9);

  Future<void> _requestCode() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address.';
        _statusMessage = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'request-email-code',
        body: {'email': email},
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw Exception(
          data is Map && data['error'] is String
              ? data['error']
              : 'Could not request a code. Please try again.',
        );
      }

      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _statusMessage = data is Map && data['message'] is String
            ? data['message']
            : 'Check your email for a sign-in code.';
      });
    } on FunctionException catch (e) {
      if (!mounted) return;
      final details = e.details;
      setState(() {
        _errorMessage = details is Map && details['error'] is String
            ? details['error'] as String
            : 'Could not send the code. Check your connection and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(() => _errorMessage = 'Enter the eight-digit code from your email.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'verify-email-code',
        body: {'email': email, 'code': code},
      );

      final data = response.data;
      if (response.status < 200 ||
          response.status >= 300 ||
          data is! Map ||
          data['refresh_token'] is! String ||
          (data['refresh_token'] as String).isEmpty) {
        throw Exception(
          data is Map && data['error'] is String
              ? data['error']
              : 'The code is invalid or expired. Request a new code.',
        );
      }

      // Establish a persistent, real Supabase Auth session.
      await _supabase.auth.setSession(data['refresh_token'] as String);

      // Automatically create a profile for the user if it doesn't exist
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final existingProfile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (existingProfile == null) {
          // Use the email prefix as the default username (e.g., 'john' from 'john@gmail.com')
          final defaultUsername = email.split('@')[0];
          await _supabase.from('profiles').insert({
            'id': user.id,
            'username': defaultUsername,
          });
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FunctionException catch (e) {
      if (!mounted) return;
      final details = e.details;
      setState(() {
        _errorMessage = details is Map && details['error'] is String
            ? details['error'] as String
            : 'Could not verify the code. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_rounded,
                    size: 82,
                    color: brandBlue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Dinor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DinorTheme.textGrey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    enabled: !_isLoading && !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: DinorTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!_codeSent && !_isLoading) _requestCode();
                    },
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _codeController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Eight-digit code',
                        hintText: '000000',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: DinorTheme.surfaceDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!_isLoading) _verifyCode();
                      },
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: brandBlue, fontSize: 13),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_codeSent ? _verifyCode : _requestCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _codeSent ? 'Verify and sign in' : 'Send sign-in code',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _codeSent = false;
                                _codeController.clear();
                                _errorMessage = null;
                                _statusMessage = null;
                              });
                            },
                      child: const Text(
                        'Use another email',
                        style: TextStyle(color: DinorTheme.textGrey),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'By continuing, you agree to Dinor’s Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DinorTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


============================================================
