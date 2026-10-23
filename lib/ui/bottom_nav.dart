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
      // Smaller margins to make the whole bar more compact
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DinorTheme.surfaceDark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DinorTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distributes items evenly without massive gaps
        children: [
          _buildNavItem(0, Icons.chat_bubble, Icons.chat_bubble_outline, 'Chats'),
          _buildNavItem(1, Icons.people, Icons.people_outline, 'Friends'),
          _buildNavItem(2, Icons.settings, Icons.settings_outlined, 'Settings'),
          
          // Profile Item (Custom Circle)
          GestureDetector(
            onTap: () => onTap(3),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 60, // Fixed width to prevent jumping
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
        width: 60, // Fixed width for equal spacing
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
            ),
          ],
        ),
      ),
    );
  }
}
