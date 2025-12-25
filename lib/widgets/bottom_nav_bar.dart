import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/home_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/profile_screen.dart';

class BottomNavBar extends StatelessWidget {
  final String activeScreen; // 'home', 'chat', or 'profile'
  final Map<String, dynamic>? userProfile;

  const BottomNavBar({
    super.key,
    required this.activeScreen,
    this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 10,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context: context,
              iconPath: 'assets/icons/home_simple.svg',
              label: 'Home',
              isActive: activeScreen == 'home',
              onTap: () {
                if (activeScreen != 'home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              },
            ),
            _buildNavItem(
              context: context,
              iconPath: 'assets/icons/chat_lines.svg',
              label: 'Chat',
              isActive: activeScreen == 'chat',
              onTap: () {
                if (activeScreen != 'chat') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatListScreen()),
                  );
                }
              },
            ),
            _buildNavItem(
              context: context,
              iconPath: null,
              label: 'Profile',
              isActive: activeScreen == 'profile',
              hasAvatar: true,
              avatarUrl: userProfile?['avatar_url'],
              onTap: () {
                if (activeScreen != 'profile') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    String? iconPath,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool hasAvatar = false,
    String? avatarUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasAvatar)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0E0E0),
                image: avatarUrl != null && avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : const DecorationImage(
                        image: AssetImage('assets/images/profile_avatar.png'),
                        fit: BoxFit.cover,
                      ),
              ),
            )
          else if (iconPath != null)
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                isActive ? const Color(0xFF9B7FED) : const Color(0xFF737373),
                BlendMode.srcIn,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isActive ? const Color(0xFF9B7FED) : const Color(0xFF737373),
              letterSpacing: 0.24,
            ),
          ),
        ],
      ),
    );
  }
}
