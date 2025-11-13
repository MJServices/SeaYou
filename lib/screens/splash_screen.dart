import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import 'language_selection_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Background decorative circles
          Positioned(
            left: 1,
            top: 105,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 300,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 101,
            top: 184,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.yellow,
              ),
            ),
          ),
          Positioned(
            left: 124,
            top: 209,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            left: 151,
            top: 234,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
              ),
              child: Center(
                child: Text(
                  'SeaYou',
                  style: AppTextStyles.largeTitle.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
          // Profile images scattered
          _buildProfileImage(176, 259, 50),
          _buildProfileImage(268, 159, 50),
          _buildProfileImage(74, 383, 50),
          _buildProfileImage(27, 198, 50),
          _buildProfileImage(243, 458, 50),
          _buildProfileImage(129, 524, 50),
          _buildProfileImage(317, 333, 50),
          // Interest tags
          _buildInterestTag('K-dramas', 226, 505),
          _buildInterestTag('Anime', 17, 240),
          _buildInterestTag('Sports', 301, 140),
          _buildInterestTag('You', 178, 305),
          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'What if your next encounter began with an emotion?',
                        style: AppTextStyles.mediumTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up on SeaYou app to meet your next best person',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.darkGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Get Started',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LanguageSelectionScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
          border: Border.all(color: AppColors.primary, width: 4),
        ),
      ),
    );
  }

  Widget _buildInterestTag(String text, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          text,
          style: AppTextStyles.labelText.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
