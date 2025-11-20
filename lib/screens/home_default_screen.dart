import 'package:flutter/material.dart';

/// Home Default Screen - Empty state when no bottles have been sent
class HomeDefaultScreen extends StatelessWidget {
  const HomeDefaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background blur circles
          Positioned(
            top: 72,
            left: 9,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0AC5C5).withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            top: -303,
            left: 0,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0AC5C5).withValues(alpha: 0.2),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),

                // Header with profile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image:
                                AssetImage('assets/images/profile_avatar.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hey Alex',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Hero image
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  child: Image.asset(
                    'assets/images/hero_image.png',
                    width: 360,
                    height: 460,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 9),

                // Bottles received text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    '0 bottles received',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Instructions
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    'To get started, send a bottle to the sea and wait for someone to retrieve and respond',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF737373),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Empty state card
          Positioned(
            bottom: 201,
            left: 15,
            right: 15,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFCFCFC),
                border: Border.all(
                  color: const Color(0xFFE3E3E3),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Empty state illustration
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/empty_bottle.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You\'ve not sent any bottle yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap the "+" icon to send a bottle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF737373),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating action button
          Positioned(
            bottom: 102,
            right: 73,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0AC5C5),
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x331E1E1E),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Bottom navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                    isActive: true,
                  ),
                  _buildNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    isActive: false,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isActive: false,
                    hasAvatar: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    bool hasAvatar = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasAvatar)
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/profile_avatar.png'),
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Icon(
            icon,
            size: 24,
            color: isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
          ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
            letterSpacing: 0.24,
          ),
        ),
      ],
    );
  }
}
