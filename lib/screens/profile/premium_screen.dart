import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

/// Premium/Pro Screen
/// Shows premium features and subscription options
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
                  color: const Color(0xFFFFC700).withValues(alpha: 0.2),
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
                          'SeaYou Premium',
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

                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Premium Plan Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC700),
                                border: Border.all(
                                  color: const Color(0xFF824E00),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Premium',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF824E00),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: const [
                                          Text(
                                            'NGN6500.00/month',
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF824E00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      Text(
                                        'NGN50,000 per year',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF824E00),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save 25%',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF824E00),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Features List
                            _buildFeature(
                              '♾️',
                              'Unlimited Messages',
                              'Send an unlimited number of messages per day without the 3 bottles daily limit.',
                            ),
                            const SizedBox(height: 16),
                            _buildFeature(
                              '😊',
                              'Full Access to Mood',
                              'Complete access to the five different moods instead of the usual two.',
                            ),
                            const SizedBox(height: 16),
                            _buildFeature(
                              '🔧',
                              'Secret Souls',
                              'Ability to view all members pictures, voices and quotes ',
                            ),
                            const SizedBox(height: 16),
                            _buildFeature(
                              '🧩',
                              'Door of Desires',
                              'View all secret fantasies and gain ability to send anonymous message directly.',
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'And many more...',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF000000),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
