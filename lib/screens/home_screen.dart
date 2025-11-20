import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/warm_gradient_background.dart';
import 'bottle_detail_screen.dart';
import 'all_bottles_screen.dart';
import 'send_bottle_screen.dart';
import 'chat/chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/voice_chat_modal.dart';
import '../widgets/photo_stamp_modal.dart';
import '../widgets/received_bottles_viewer.dart';

/// Home Screen - Pixel-perfect match to Figma design
/// Frame: Home/active expanded (1:3604)
/// Dimensions: 402x1050px
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Scrollable content
            Positioned.fill(
              bottom: 76, // Space for navigation bar
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 402,
                      minWidth: screenWidth > 402 ? 402 : screenWidth,
                    ),
                    child: Column(
                      children: [
                        // Hero section with decorative circles
                        SizedBox(
                          height: 570,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Ellipse 2 - Top blur circle
                              Positioned(
                                left: 0,
                                top: -303,
                                child: Container(
                                  width: 400,
                                  height: 400,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0AC5C5)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                              // Ellipse 3 - Middle blur circle
                              Positioned(
                                left: 9,
                                top: 72,
                                child: Container(
                                  width: 400,
                                  height: 400,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0AC5C5)
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              // Hero Image centered horizontally
                              Positioned(
                                top: 1,
                                left: 0,
                                right: 0,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Image.asset(
                                    'assets/images/hero_image.png',
                                    width: 360,
                                    height: 460,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Header with profile
                              Positioned(
                                left: 15,
                                top: 78,
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
                              // Bottles received text
                              const Positioned(
                                left: 15,
                                top: 453,
                                right: 15,
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
                            ],
                          ),
                        ),

                        // View bottle messages button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ReceivedBottlesViewer(),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFAFA),
                                border: Border.all(
                                  color: const Color(0xFF0AC5C5),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Text(
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

                        const SizedBox(height: 16),

                        // Sent Bottles section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
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
                              mainAxisSize: MainAxisSize.min,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            barrierColor: Colors.black
                                                .withValues(alpha: 0.5),
                                            builder: (context) =>
                                                VoiceChatModal(
                                              isReceived: false,
                                              onReply: () {
                                                Navigator.pop(context);
                                              },
                                            ),
                                          );
                                        },
                                        child: _buildBottleCard(
                                          color: const Color(0xFFFFFFFF),
                                          iconPath:
                                              'assets/icons/microphone.svg',
                                          title: 'Voice Chat',
                                          hasAudio: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const BottleDetailScreen(
                                                mood: 'Curious',
                                                messageType: 'Text',
                                                message:
                                                    'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
                                                isReceived: false,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _buildBottleCard(
                                          color: const Color(0xFFFCF8FF),
                                          iconPath:
                                              'assets/icons/chat_lines.svg',
                                          title: 'Text',
                                          message:
                                              'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            barrierColor: Colors.black
                                                .withValues(alpha: 0.5),
                                            builder: (context) =>
                                                PhotoStampModal(
                                              imageUrl:
                                                  'assets/images/photo_stamp.png',
                                              caption: 'The picture',
                                              isReceived: false,
                                              onReply: () {
                                                Navigator.pop(context);
                                              },
                                              onPrevious: () {},
                                              onNext: () {},
                                            ),
                                          );
                                        },
                                        child: _buildBottleCard(
                                          color: const Color(0xFFFFFBF5),
                                          iconPath:
                                              'assets/icons/media_image.svg',
                                          title: 'Photo Stamp',
                                          hasImage: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const AllBottlesScreen(
                                                isSent: true,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          height: 128,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF8FB),
                                            border: Border.all(
                                              color: const Color(0xFFE3E3E3),
                                              width: 0.8,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'See all',
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF363636),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                SvgPicture.asset(
                                                  'assets/icons/nav_arrow_down.svg',
                                                  width: 16,
                                                  height: 16,
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                    Color(0xFF363636),
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ],
                                            ),
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

                        // Bottom padding for scrolling
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Fixed Floating Action Button (Plus Icon)
            Positioned(
              right: 16,
              bottom: 100,
              child: GestureDetector(
                onTap: () {
                  // Navigate to send bottle screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SendBottleScreen(),
                    ),
                  );
                },
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
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/plus.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Fixed Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Already on home, do nothing or refresh
                      },
                      child: _buildNavItem(
                        iconPath: 'assets/icons/home_simple.svg',
                        label: 'Home',
                        isActive: true,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to chat screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                      child: _buildNavItem(
                        iconPath: 'assets/icons/chat_lines.svg',
                        label: 'Chat',
                        isActive: false,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: _buildNavItem(
                        iconPath: null,
                        label: 'Profile',
                        isActive: false,
                        hasAvatar: true,
                      ),
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
    String? iconPath,
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
              if (iconPath != null)
                SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF151515),
                    BlendMode.srcIn,
                  ),
                ),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final perBar = 3 + 4;
                final count = (constraints.maxWidth / perBar).floor();
                final heights = [12.0, 20.0, 28.0, 16.0, 24.0, 14.0, 22.0, 18.0];
                return Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(count, (index) {
                      return Container(
                        width: 3,
                        height: heights[index % heights.length],
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0AC5C5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              },
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
    String? iconPath,
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
        else if (iconPath != null)
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
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
            color: isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
            letterSpacing: 0.24,
          ),
        ),
      ],
    );
  }
}
