import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PhotoStampModal extends StatelessWidget {
  final String imageUrl;
  final String caption;
  final bool isReceived;
  final VoidCallback? onReply;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PhotoStampModal({
    super.key,
    required this.imageUrl,
    required this.caption,
    this.isReceived = true,
    this.onReply,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background with gradient and bottle
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.5),
                radius: 1.2,
                colors: [
                  Color(0xFF0AC5C5),
                  Color(0xFFF5E6D3),
                ],
                stops: [0.0, 1.0],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/fill bottle.png',
                  width: 200,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        // Modal content
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                const SizedBox(height: 9),
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
                const SizedBox(height: 16),

                  // Header with navigation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Left arrow
                      GestureDetector(
                        onTap: onPrevious,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF151515),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Photo Stamp',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                      const Spacer(),
                      // Right arrow
                      GestureDetector(
                        onTap: onNext,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Transform.rotate(
                            angle: 3.14159,
                            child: SvgPicture.asset(
                              'assets/icons/arrow_left.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF151515),
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
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/xmark.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF151515),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Image display
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            height: 308,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF5F5F5),
                              image: imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          child: imageUrl.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 48,
                                    color: Color(0xFFCCCCCC),
                                  ),
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Caption
                      if (caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            caption,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF363636),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                ),

                // Send reply button
                if (isReceived)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onReply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0AC5C5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Send a reply',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
