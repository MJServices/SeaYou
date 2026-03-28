import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'sexual_orientation_screen.dart';
import '../services/onboarding_service.dart';

class GenderIdentityScreen extends StatefulWidget {
  final UserProfile userProfile;

  const GenderIdentityScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<GenderIdentityScreen> createState() => _GenderIdentityScreenState();
}

class _GenderIdentityScreenState extends State<GenderIdentityScreen> {
  String? _selectedGender;

  final List<String> genderOptions = [
    'Man',
    'Woman',
    'Non-binary',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select if already set
    if (widget.userProfile.gender != null) {
      _selectedGender = widget.userProfile.gender;
    }
  }

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.gender.title'),
                              style: AppTextStyles.displayText,
                            ),
                          ),
                          const Text(
                            '2/6',
                            style: AppTextStyles.bodyText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                            .tr('onboarding.gender.subtitle'),
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 24),
                      ...genderOptions.map((gender) => _buildOption(gender)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: AppLocalizations.of(context).tr('common.next'),
                  isActive: _selectedGender != null,
                  onPressed: () async {
                    // Map display values to database values
                    String? dbGender;
                    if (_selectedGender == 'Man') {
                      dbGender = 'male';
                    } else if (_selectedGender == 'Woman') {
                      dbGender = 'female';
                    } else if (_selectedGender == 'Non-binary') {
                      dbGender = 'nonbinary';
                    }

                    // Save to user profile
                    widget.userProfile.gender = dbGender;

                    await OnboardingService().saveStep(OnboardingStep.sexualOrientation);

                    // Navigate to sexual orientation screen
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SexualOrientationScreen(
                            userProfile: widget.userProfile,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String text) {
    final isSelected = _selectedGender == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = text;
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
          AppLocalizations.of(context).tr(
              'onboarding.gender.options.${text.toLowerCase().replaceAll(' ', '_')}'),
          style: AppTextStyles.bodyText.copyWith(
            color: isSelected ? AppColors.darkGrey : AppColors.grey,
          ),
        ),
      ),
    );
  }
}
