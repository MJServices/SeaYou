import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

/// Terms of Service Screen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFEFAEE),
        ),
        child: Stack(
          children: [
            // Decorative ellipse background
            Positioned(
              left: 0,
              top: -303,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0AC5C5).withValues(alpha: 0.2),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 300, sigmaY: 300),
                  child: Container(),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                        const SizedBox(width: 16),
                        const Text(
                          'Terms of Service',
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

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Terms of Service content will be displayed here.\n\nThis page will contain the full terms and conditions for using SeaYou.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
