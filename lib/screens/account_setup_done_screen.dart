import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'home_screen.dart';

class AccountSetupDoneScreen extends StatelessWidget {
  const AccountSetupDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
          // Background decorative circle
          Positioned(
            left: 0,
            top: -303,
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
          // Bubbles
          _buildBubble(-11, 805, 148),
          _buildBubble(303, 635, 148),
          _buildBubble(-4, 445, 60),
          _buildBubble(164, 360, 200),
          _buildBubble(50, 231, 148),
          _buildBubble(152, 69, 148),
          _buildBubble(62, 594, 100),
          _buildBubble(120, 631, 200),
          _buildBubble(239, 207, 60),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Your profile has been created!',
                      style: AppTextStyles.displayText,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Now you can send a bottle to the sea and wait for who opens it.',
                      style: AppTextStyles.labelText,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'How it works',
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStep(
                      Icons.message,
                      'You send a limited number of anonymous messages tagged with your current mood.',
                    ),
                    const SizedBox(height: 16),
                    _buildStep(
                      Icons.mail,
                      'When a message arrives, you see only the content and emotion.',
                    ),
                    const SizedBox(height: 16),
                    _buildStep(
                      Icons.favorite,
                      'Once you both reply, the feeling bar activates and anonymity is guaranteed till it gets filled.',
                    ),
                    const SizedBox(height: 16),
                    _buildStep(
                      Icons.person,
                      'Upon completion of the bar, the full profile is revealed.',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Want to increase the number of bottles to send per day and unlock more features? Get our pro plan.',
                      style: AppTextStyles.labelText.copyWith(
                        color: AppColors.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Let\'s go!',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
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

  Widget _buildBubble(double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelText.copyWith(
              color: AppColors.darkGrey,
            ),
          ),
        ),
      ],
    );
  }
}
