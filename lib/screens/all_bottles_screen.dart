import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/warm_gradient_background.dart';

/// All Bottles Screen - Shows all sent or received bottles
class AllBottlesScreen extends StatelessWidget {
  final bool isSent;

  const AllBottlesScreen({
    super.key,
    this.isSent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(
                          'assets/icons/arrow_left.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF151515),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSent ? 'Sent Bottles' : 'Received Bottles',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF151515),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Note
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Note: Bottles disappears into the sea 30 days after connection has not been established.',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF737373),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottles grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return _buildBottleCard(index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottleCard(int index) {
    final types = ['Voice Chat', 'Text', 'Photo Stamp'];
    final colors = [
      Colors.white,
      const Color(0xFFFCF8FF),
      const Color(0xFFFFFBF5),
    ];
    final iconPaths = [
      'assets/icons/microphone.svg',
      'assets/icons/chat_lines.svg',
      'assets/icons/media_image.svg',
    ];

    final type = types[index % types.length];
    final color = colors[index % colors.length];
    final iconPath = iconPaths[index % iconPaths.length];

    return Container(
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
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (type == 'Voice Chat') ...[
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ] else if (type == 'Photo Stamp') ...[
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  image: DecorationImage(
                    image: AssetImage('assets/images/photo_stamp.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ] else ...[
            const Expanded(
              child: Text(
                'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
                style: TextStyle(
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
}
