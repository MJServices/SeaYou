import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        border: Border(
          top: BorderSide(
            color: Color(0x0D000000),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            index: 0,
            icon: 'assets/icons/home_simple.svg',
            label: 'Home',
          ),
          _buildNavItem(
            index: 1,
            icon: 'assets/icons/chat_lines.svg',
            label: 'Chat',
          ),
          _buildNavItem(
            index: 2,
            icon: null,
            label: 'Profile',
            isProfile: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    String? icon,
    required String label,
    bool isProfile = false,
  }) {
    final isActive = currentIndex == index;
    final color = isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProfile)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/profile_avatar.png'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(
                    color: color,
                    width: 1.5,
                  ),
                ),
              )
            else
              SvgPicture.asset(
                icon!,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  color,
                  BlendMode.srcIn,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: color,
                letterSpacing: 0.24,
                height: 1.33,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
