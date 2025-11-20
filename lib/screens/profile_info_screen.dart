import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'sexual_orientation_screen.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  bool get isFormValid =>
      _nameController.text.isNotEmpty &&
      _ageController.text.isNotEmpty &&
      _cityController.text.isNotEmpty &&
      _aboutController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Add listeners to update UI when text changes
    _nameController.addListener(_updateFormState);
    _ageController.addListener(_updateFormState);
    _cityController.addListener(_updateFormState);
    _aboutController.addListener(_updateFormState);
  }

  void _updateFormState() {
    setState(() {
      // Force rebuild when any field changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tell us about yourself',
                              style: AppTextStyles.displayText,
                            ),
                            Text(
                              '1/5',
                              style: AppTextStyles.bodyText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Full Name',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Enter your name',
                          controller: _nameController,
                          isActive: _nameController.text.isNotEmpty,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Age',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Enter your age',
                          controller: _ageController,
                          isActive: _ageController.text.isNotEmpty,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'City',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Nairobi',
                          controller: _cityController,
                          isActive: _cityController.text.isNotEmpty,
                          suffixIcon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'About',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Add a short bio description',
                          controller: _aboutController,
                          isActive: _aboutController.text.isNotEmpty,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_aboutController.text.length}/80',
                            style: AppTextStyles.bodyText,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: 'Next',
                    isActive: isFormValid,
                    onPressed: () {
                      if (isFormValid) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SexualOrientationScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _aboutController.dispose();
    super.dispose();
  }
}
