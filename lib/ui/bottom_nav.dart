import 'package:flutter/material.dart';
import 'dinor_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Container(
      margin: const EdgeInsets.only(left: 40, right: 40, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: DinorTheme.surfaceDark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DinorTheme.softShadow,
      ),
      // Use a Row with spaceEvenly and fixed widths to keep gaps small
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.chat_bubble, Icons.chat_bubble_outline, 'Chats'),
          const SizedBox(width: 12), // Tiny gap
          _buildNavItem(1, Icons.people, Icons.people_outline, 'Friends'),
          const SizedBox(width: 12), // Tiny gap
          _buildNavItem(2, Icons.settings, Icons.settings_outlined, 'Settings'),
          const SizedBox(width: 12), // Tiny gap
          
          // Profile Item (Custom Circle)
          GestureDetector(
            onTap: () => onTap(3),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 50, // Fixed width for the profile circle
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: DinorTheme.bgDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: currentIndex == 3 ? brandBlue : DinorTheme.textGrey,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: currentIndex == 3 ? brandBlue : DinorTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: currentIndex == 3 ? FontWeight.bold : FontWeight.normal,
                      color: currentIndex == 3 ? brandBlue : DinorTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    const Color brandBlue = Color(0xFF229ED9);
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 50, // Fixed width for each item so they stay tight
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? brandBlue : DinorTheme.textGrey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? brandBlue : DinorTheme.textGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


============================================================
