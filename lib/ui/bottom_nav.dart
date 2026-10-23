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
      // Small margins for the floating pill
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: DinorTheme.surfaceDark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: DinorTheme.softShadow,
      ),
      child: Row(
        // This is the magic fix: It forces each item to take equal space
        children: [
          Expanded(child: _buildNavItem(0, Icons.chat_bubble, Icons.chat_bubble_outline, 'Chats')),
          Expanded(child: _buildNavItem(1, Icons.people, Icons.people_outline, 'Friends')),
          Expanded(child: _buildNavItem(2, Icons.settings, Icons.settings_outlined, 'Settings')),
          
          // Profile Item (Custom Circle)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(3),
              behavior: HitTestBehavior.opaque,
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
    );
  }
}
