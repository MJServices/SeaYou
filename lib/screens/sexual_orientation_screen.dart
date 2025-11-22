import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'expectations_screen.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class SexualOrientationScreen extends StatefulWidget {
  final UserProfile userProfile;
  final bool isEditMode;
  
  const SexualOrientationScreen({
    super.key, 
    required this.userProfile,
    this.isEditMode = false,
  });

  @override
  State<SexualOrientationScreen> createState() =>
      _SexualOrientationScreenState();
}

class _SexualOrientationScreenState extends State<SexualOrientationScreen> {
  final List<String> _selectedOrientations = [];
  bool _showOnProfile = false;

  final List<String> orientations = [
    'Heterosexual',
    'Gay',
    'Lesbian',
    'Bisexual',
    'Asexual',
    'Pansexual',
    'Aromantic',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.userProfile.sexualOrientation != null) {
      _selectedOrientations.addAll(widget.userProfile.sexualOrientation!);
    }
    _showOnProfile = widget.userProfile.showOrientation;
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
                              widget.isEditMode ? 'Edit Sexual Orientation' : 'What is your sexual orientation?',
                              style: AppTextStyles.displayText,
                            ),
                          ),
                          if (!widget.isEditMode)
                            const Text(
                              '2/5',
                              style: AppTextStyles.bodyText,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select all the options that describe your identity.',
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 24),
                      ...orientations
                          .map((orientation) => _buildOption(orientation)),
                      const SizedBox(height: 16),
                      const Text(
                        'Sexual orientation not listed here?',
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.grey, width: 0.8),
                        ),
                        child: const Text(
                          'Input sexual orientation',
                          style: AppTextStyles.bodyText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOnProfile = !_showOnProfile;
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _showOnProfile
                                      ? AppColors.primary
                                      : AppColors.grey,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: _showOnProfile
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Show my sexual orientation on profile',
                              style: AppTextStyles.bodyText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: widget.isEditMode ? 'Save' : 'Next',
                  isActive: _selectedOrientations.isNotEmpty,
                  onPressed: () async {
                    widget.userProfile.sexualOrientation = _selectedOrientations;
                    widget.userProfile.showOrientation = _showOnProfile;
                    
                    if (widget.isEditMode) {
                      // Update DB
                      try {
                        final user = AuthService().currentUser;
                        if (user != null) {
                          await DatabaseService().updateProfile(user.id, {
                            'sexual_orientation': _selectedOrientations,
                            'show_orientation': _showOnProfile,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating profile: $e')),
                          );
                        }
                      }
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpectationsScreen(
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
    final isSelected = _selectedOrientations.contains(text);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedOrientations.remove(text);
          } else {
            _selectedOrientations.add(text);
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
