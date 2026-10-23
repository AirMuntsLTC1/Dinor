import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dinor_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = supabase.auth.currentUser;
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Logged out')))),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    // Get user metadata from Google Auth
    final metadata = _user?.userMetadata;
    final fullName = metadata?['full_name'] ?? 'Dinor User';
    final avatarUrl = metadata?['avatar_url'];
    final email = _user?.email ?? 'No email linked';

    return Scaffold(
      backgroundColor: DinorTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // 1. Profile Picture (Google Avatar or Placeholder)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: brandBlue, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: brandBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(brandBlue),
                          )
                        : _buildPlaceholder(brandBlue),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 2. Display Name
              Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),

              // 3. Email
              Text(
                email,
                style: const TextStyle(
                  color: DinorTheme.textGrey,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              // 4. Settings List
              Container(
                decoration: BoxDecoration(
                  color: DinorTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: DinorTheme.softShadow,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: Colors.white),
                      title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: DinorTheme.textGrey),
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: DinorTheme.bgDark),
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: Colors.white),
                      title: const Text('Privacy & Security', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: DinorTheme.textGrey),
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: DinorTheme.bgDark),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                      onTap: _signOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color brandBlue) {
    return Container(
      color: DinorTheme.surfaceDark,
      child: const Icon(
        Icons.person,
        size: 60,
        color: DinorTheme.textGrey,
      ),
    );
  }
}
