import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/status_bar.dart';
import 'account_setup_done_screen.dart';

class UploadPictureScreen extends StatelessWidget {
  const UploadPictureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
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
          SafeArea(
            child: Column(
              children: [
                const CustomStatusBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upload a picture',
                            style: AppTextStyles.displayText,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AccountSetupDoneScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Skip',
                              style: AppTextStyles.bodyText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '5/5',
                        style: AppTextStyles.bodyText,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightPurple,
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: AppTextStyles.largeTitle.copyWith(
                        fontSize: 80,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CustomButton(
                        text: 'Upload from gallery',
                        onPressed: () {
                          // Handle gallery upload
                        },
                      ),
                      const SizedBox(height: 16),
                      const CustomButton(
                        text: 'Take photo',
                        isActive: false,
                        onPressed: null,
                      ),
                      const SizedBox(height: 16),
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
}
