import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/reply_sent_modal.dart';
import '../screens/send_bottle_screen.dart';
import '../widgets/warm_gradient_background.dart';

/// Bottle Detail Screen - Shows the full message from a bottle
class BottleDetailScreen extends StatefulWidget {
  final String mood;
  final String messageType;
  final String message;
  final bool isReceived;

  const BottleDetailScreen({
    super.key,
    required this.mood,
    required this.messageType,
    required this.message,
    this.isReceived = true,
  });

  @override
  State<BottleDetailScreen> createState() => _BottleDetailScreenState();
}

class _BottleDetailScreenState extends State<BottleDetailScreen> {
  int _currentMessageIndex = 0;

  // Sample messages for navigation
  final List<Map<String, String>> _messages = [
    {
      'mood': 'Dreamy',
      'type': 'Text',
      'content':
          'Hi. Prior to our previous conversation, I saw the river you mentioned while taking a walk after a pretty chill day. The sight was truly amazing as you described. The sun on the river was beautiful as you described.\n\nI could attach a picture I took of it if you do not mind. Let me know if you\'ll be willing to rate my non-photography skill.'
    },
    {
      'mood': 'Curious',
      'type': 'Text',
      'content':
          'Hey! I\'ve been thinking about what you said earlier. It really resonated with me and I wanted to share my thoughts on it. Sometimes the best conversations happen when we least expect them.'
    },
    {
      'mood': 'Calm',
      'type': 'Text',
      'content':
          'Good morning! I hope you\'re having a wonderful day. I wanted to reach out and see how things are going with you. It\'s always nice to connect with someone who understands.'
    },
  ];

  void _navigateMessage(int direction) {
    setState(() {
      _currentMessageIndex =
          (_currentMessageIndex + direction) % _messages.length;
      if (_currentMessageIndex < 0) {
        _currentMessageIndex = _messages.length - 1;
      }
    });
  }

  String get mood => _messages[_currentMessageIndex]['mood']!;
  String get messageType => _messages[_currentMessageIndex]['type']!;
  String get message => _messages[_currentMessageIndex]['content']!;
  bool get isReceived => widget.isReceived;

  List<Color> get _moodGradientColors {
    switch (mood.toLowerCase()) {
      case 'dreamy':
        return [
          const Color(0xFFC7CEEA), // Start: lighter color at top
          const Color(0xFF9B98E6), // End: darker color at bottom
        ];
      case 'curious':
        return [
          const Color(0xFFFFC700),
          const Color(0xFFD89736),
        ];
      case 'calm':
        return [
          const Color(0xFF9ECFD4),
          const Color(0xFF65ADA9),
        ];
      case 'playful':
        return [
          const Color(0xFFFF9F9B),
          const Color(0xFFFF6D68),
        ];
      default:
        return [
          const Color(0xFFC7CEEA),
          const Color(0xFF9B98E6),
        ];
    }
  }

  Color get _textColor {
    switch (mood.toLowerCase()) {
      case 'dreamy':
        return const Color(0xFF3B0143);
      case 'curious':
        return const Color(0xFF3A2C02);
      case 'calm':
        return const Color(0xFF151515);
      case 'playful':
        return const Color(0xFF151515);
      default:
        return const Color(0xFF3B0143);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),

                  // Header
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

                  const SizedBox(height: 76),
                ],
              ),
            ),

            // Message card with decorative elements - TALLER MODAL
            Positioned(
              top: 380,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x33000000),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      // Gradient background
                      Opacity(
                        opacity: 0.9,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: _moodGradientColors,
                              stops: const [0.0, 0.56],
                            ),
                          ),
                        ),
                      ),

                      // Decorative stars scattered around (more stars, very subtle)
                      Positioned(top: 30, left: 25, child: _buildStar(16)),
                      Positioned(top: 90, right: 35, child: _buildStar(14)),
                      Positioned(top: 160, left: 45, child: _buildStar(18)),
                      Positioned(top: 210, right: 55, child: _buildStar(16)),
                      Positioned(top: 130, left: 15, child: _buildStar(12)),
                      Positioned(top: 190, right: 25, child: _buildStar(16)),
                      Positioned(top: 260, left: 65, child: _buildStar(14)),
                      Positioned(top: 70, right: 75, child: _buildStar(18)),
                      Positioned(top: 150, left: 85, child: _buildStar(16)),
                      Positioned(top: 230, right: 45, child: _buildStar(12)),
                      Positioned(top: 50, left: 115, child: _buildStar(16)),
                      Positioned(top: 110, right: 95, child: _buildStar(14)),
                      Positioned(top: 180, left: 120, child: _buildStar(14)),
                      Positioned(top: 240, right: 110, child: _buildStar(16)),
                      Positioned(top: 100, left: 140, child: _buildStar(12)),
                      Positioned(top: 200, right: 130, child: _buildStar(18)),
                      Positioned(top: 40, left: 200, child: _buildStar(14)),
                      Positioned(top: 270, right: 150, child: _buildStar(16)),
                      Positioned(top: 120, left: 250, child: _buildStar(12)),
                      Positioned(top: 170, right: 200, child: _buildStar(14)),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 80,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF737373),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Message content with more space
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _textColor,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Decorative stars row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  Icons.star,
                                  size: 16,
                                  color: _textColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Message type header with navigation arrows
                            Row(
                              children: [
                                // Left arrow - Navigate to previous
                                GestureDetector(
                                  onTap: () => _navigateMessage(-1),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/icons/arrow_left.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: ColorFilter.mode(
                                        _textColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  messageType,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: _textColor,
                                  ),
                                ),
                                const Spacer(),
                                // Right arrow - Navigate to next
                                GestureDetector(
                                  onTap: () => _navigateMessage(1),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Transform.rotate(
                                      angle: 3.14159, // 180 degrees
                                      child: SvgPicture.asset(
                                        'assets/icons/arrow_left.svg',
                                        width: 20,
                                        height: 20,
                                        colorFilter: ColorFilter.mode(
                                          _textColor,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Close button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/icons/xmark.svg',
                                      width: 16,
                                      height: 16,
                                      colorFilter: ColorFilter.mode(
                                        _textColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (isReceived) ...[
                              const SizedBox(height: 16),
                              // Send reply button
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SendBottleScreen(),
                                    ),
                                  );
                                  if (context.mounted) {
                                    _showReplySentModal(context);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Send a reply',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStar(double size) {
    return Opacity(
      opacity: 0.3,
      child: Icon(
        Icons.star,
        size: size,
        color: _textColor,
      ),
    );
  }

  void _showReplySentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ReplySentModal(
        onCreateUsername: () {
          Navigator.pop(dialogContext); // Close modal
          Navigator.pop(context); // Return to home
          // Navigate to chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username created! Chat opened.')),
          );
        },
      ),
    );
  }
}
