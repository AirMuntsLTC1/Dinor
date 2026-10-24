import 'package:flutter/material.dart';
import 'dinor_theme.dart';

class SideDrawer extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onMessagesTap;

  const SideDrawer({
    super.key,
    required this.onHomeTap,
    required this.onMessagesTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Drawer(
      backgroundColor: DinorTheme.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: brandBlue, width: 2),
                    ),
                    child: const Icon(Icons.person, color: brandBlue, size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dinor User',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@dinor_app',
                          style: TextStyle(
                            color: DinorTheme.textGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: DinorTheme.surfaceDark, thickness: 1),

            // 2. Navigation Items
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  _buildDrawerItem(
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      onHomeTap();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.message_rounded,
                    title: 'Messages',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      onMessagesTap();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    const Color brandBlue = Color(0xFF229ED9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: brandBlue.withValues(alpha: 0.1),
          highlightColor: brandBlue.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: brandBlue, size: 26),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


============================================================
