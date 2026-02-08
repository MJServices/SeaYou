import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/home_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/profile_screen.dart';
import '../services/database_service.dart';
import '../i18n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Get safe area bottom padding for device compatibility
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        // Add minimal bottom padding - just enough for safe area
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: bottomPadding > 0 ? bottomPadding + 4 : 6, // Minimal padding
        ),
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
        child: SizedBox(
          height: 60, // Reduced from 70 for better spacing
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                iconPath: 'assets/icons/home_simple.svg',
                label: AppLocalizations.of(context).tr('navigation.home'),
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
              StreamBuilder<int>(
                stream: DatabaseService().unreadCountStream,
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  final hasNotification = unreadCount > 0;
                  
                  return _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/chat_lines.svg',
                    label: AppLocalizations.of(context).tr('navigation.chat'),
                    isActive: activeScreen == 'chat',
                    hasNotification: hasNotification,
                    onTap: () {
                      if (activeScreen != 'chat') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatListScreen()),
                        );
                      }
                    },
                  );
                }
              ),
              StreamBuilder<Map<String, dynamic>?>(
                stream: DatabaseService().profileStream(Supabase.instance.client.auth.currentUser?.id ?? ''),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final avatarUrl = profile?['avatar_url'];
                  
                  return _buildNavItem(
                    context: context,
                    iconPath: null,
                    label: AppLocalizations.of(context).tr('navigation.profile'),
                    isActive: activeScreen == 'profile',
                    hasAvatar: true,
                    avatarUrl: avatarUrl,
                    onTap: () {
                      if (activeScreen != 'profile') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      }
                    },
                  );
                }
              ),
            ],
          ),
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
    bool hasNotification = false,
  }) {
    // Determine color:
    // Notification -> Red (0xFFFB3748) (Always takes precedence)
    // Active -> Purple (0xFF9B7FED)
    // Inactive -> Grey (0xFF737373)
    final Color itemColor;
    if (hasNotification) {
      itemColor = const Color(0xFFFF9800);
    } else if (isActive) {
      itemColor = const Color(0xFF9B7FED);
    } else {
      itemColor = const Color(0xFF737373);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    itemColor,
                    BlendMode.srcIn,
                  ),
                ),
                if (hasNotification)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB3748), // Explicit Red
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: itemColor,
              letterSpacing: 0.24,
            ),
          ),
        ],
      ),
    );
  }
}

