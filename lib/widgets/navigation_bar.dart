import 'package:flutter/material.dart';

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            isActive: currentIndex == 1,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: currentIndex == 2,
            onTap: () {},
            hasAvatar: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool hasAvatar = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAvatar)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x330AC5C5),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Color(0xFF0AC5C5),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 24,
                    color: isActive
                        ? const Color(0xFF0AC5C5)
                        : const Color(0xFF737373),
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.24,
                    color: isActive
                        ? const Color(0xFF0AC5C5)
                        : const Color(0xFF737373),
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
