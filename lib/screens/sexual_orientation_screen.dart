import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'expectations_screen.dart';

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
  bool _isSaving = false;

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
      
      // Add any custom orientations from profile that aren't in the default list
      for (final orientation in _selectedOrientations) {
        if (!orientations.contains(orientation)) {
          orientations.add(orientation);
        }
      }
    }
  }

  Future<void> _checkRedirect() async {
    if (widget.isEditMode) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await DatabaseService().getProfile(user.id);
      if (profile != null && profile['full_name'] != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
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
                              widget.isEditMode 
                                  ? AppLocalizations.of(context).tr('onboarding.sexual_orientation.title_edit') 
                                  : AppLocalizations.of(context).tr('onboarding.sexual_orientation.title'),
                              style: AppTextStyles.displayText,
                            ),
                          ),
                          if (!widget.isEditMode)
                            const Text(
                              '3/6',
                              style: AppTextStyles.bodyText,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).tr('onboarding.sexual_orientation.subtitle'),
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 24),
                      ...orientations
                          .map((orientation) => _buildOption(orientation)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: widget.isEditMode 
                      ? (_isSaving ? AppLocalizations.of(context).tr('common.saving') : AppLocalizations.of(context).tr('common.confirm')) 
                      : AppLocalizations.of(context).tr('common.next'),
                  isActive: _selectedOrientations.isNotEmpty,
                  onPressed: () async {
                    if (_isSaving) return;
                    widget.userProfile.sexualOrientation = _selectedOrientations;
                    widget.userProfile.showOrientation = true;
                    
                    if (widget.isEditMode) {
                      setState(() => _isSaving = true);
                      // Update DB
                      try {
                        final user = AuthService().currentUser;
                        if (user != null) {
                          await DatabaseService().updateProfile(user.id, {
                            'sexual_orientation': _selectedOrientations,
                            'show_orientation': true,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${AppLocalizations.of(context).tr('notification.error')}: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSaving = false);
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
          orientations.contains(text) 
              ? AppLocalizations.of(context).tr('onboarding.sexual_orientation.options.${text.toLowerCase()}') 
              : text,
          style: AppTextStyles.bodyText.copyWith(
            color: isSelected ? AppColors.darkGrey : AppColors.grey,
          ),
        ),
      ),
    );
  }
}
