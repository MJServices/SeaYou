import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'interests_screen.dart';
import '../models/user_profile.dart';

class ExpectationsScreen extends StatefulWidget {
  final UserProfile userProfile;
  const ExpectationsScreen({super.key, required this.userProfile});

  @override
  State<ExpectationsScreen> createState() => _ExpectationsScreenState();
}

class _ExpectationsScreenState extends State<ExpectationsScreen> {
  String? selectedExpectation;
  String? selectedGender;

  final List<String> expectations = [
    'A serious relationship',
    'A casual relationship',
    'To make friends',
    'I do not really know yet',
  ];

  final List<String> genders = [
    'Men',
    'Women',
    'Non-binary',
    'Everyone',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'What are you looking for?',
                            style: AppTextStyles.displayText,
                          ),
                          Text(
                            '3/5',
                            style: AppTextStyles.bodyText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tell us your expectations so we can personalize your experience',
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 24),
                      ...expectations.map((exp) => _buildOption(exp, true)),
                      const SizedBox(height: 32),
                      const Text(
                        'Who do you want to meet?',
                        style: AppTextStyles.displayText,
                      ),
                      const SizedBox(height: 24),
                      ...genders.map((gender) => _buildOption(gender, false)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: 'Next',
                  isActive:
                      selectedExpectation != null && selectedGender != null,
                  onPressed: () {
                    widget.userProfile.expectation = selectedExpectation;
                    widget.userProfile.interestedIn = selectedGender;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InterestsScreen(
                          userProfile: widget.userProfile,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String text, bool isExpectation) {
    final isSelected =
        isExpectation ? selectedExpectation == text : selectedGender == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpectation) {
            selectedExpectation = text;
          } else {
            selectedGender = text;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey,
            width: 0.8,
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyText.copyWith(
            color: isSelected ? AppColors.darkGrey : AppColors.grey,
          ),
        ),
      ),
    );
  }
}
