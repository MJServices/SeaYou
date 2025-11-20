import 'package:flutter/material.dart';
import '../widgets/warm_gradient_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
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
                  // Status bar space
                  const SizedBox(height: 21),

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
                              image: AssetImage(
                                  'assets/images/profile_avatar.png'),
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

                  const SizedBox(height: 297),

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
                      '32\nbottles received',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF151515),
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // View bottle messages button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Container(
                      width: 370,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFAFA),
                        border: Border.all(
                          color: const Color(0xFF0AC5C5),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'View bottle messages',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0AC5C5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),

            // Sent Bottles section
            Positioned(
              bottom: 201,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFC),
                  border: Border.all(
                    color: const Color(0xFFE3E3E3),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sent Bottles (24)',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF151515),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // First row
                    Row(
                      children: [
                        Expanded(
                          child: _buildBottleCard(
                            color: const Color(0xFFFFFFFF),
                            icon: Icons.mic,
                            title: 'Voice Chat',
                            hasAudio: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildBottleCard(
                            color: const Color(0xFFFCF8FF),
                            icon: Icons.chat_bubble_outline,
                            title: 'Text',
                            message:
                                'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Second row
                    Row(
                      children: [
                        Expanded(
                          child: _buildBottleCard(
                            color: const Color(0xFFFFFBF5),
                            icon: Icons.image_outlined,
                            title: 'Photo Stamp',
                            hasImage: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Container(
                            height: 128,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8FB),
                              border: Border.all(
                                color: const Color(0xFFE3E3E3),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'See all',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF363636),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Color(0xFF363636),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
      ),
    );
  }

  Widget _buildBottleCard({
    required Color color,
    required IconData icon,
    required String title,
    String? message,
    bool hasAudio = false,
    bool hasImage = false,
  }) {
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: const Color(0xFFE3E3E3),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: Colors.black),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
            ],
          ),
          if (hasAudio) ...[
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
          if (hasImage) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/photo_stamp.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF151515),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
