import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import 'upload_picture_screen.dart';

class InterestsScreen extends StatefulWidget {
  final UserProfile userProfile;
  final bool isEditMode;

  const InterestsScreen({
    super.key, 
    required this.userProfile,
    this.isEditMode = false,
  });

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final List<String> _selectedInterests = [];
  bool _isSaving = false;

  final Map<String, List<String>> categories = {
    'Lifestyle': [
      'Travel',
      'Spontaneous weekends',
      'Outings with friends',
      'Cozy moments',
      'Creative spirit',
      'Foodie',
    ],
    '🍷 Outings': [
      'Restaurants',
      'Concerts',
      'Festivals',
      'Movies',
      'Chill nights out',
      'Happy hours',
    ],
    '🏃 Activities': [
      'Sports',
      'Fitness',
      'Walking',
      'Yoga/Pilates',
      'Hiking',
      'Dancing',
      'Adventures',
      'Motorcycling',
    ],
    '🎧 Entertainment': [
      'Music',
      'Reading',
      'Podcasts',
      'Exhibitions/Museums',
      'Photography',
    ],
    '🌿 Well-being & values': [
      'Nature',
      'Animals',
      'Well-being',
      'Ecology',
      'Spirituality',
    ],
    '😏 Fun & connection': [
      'Humor is essential',
      'Geek/Pop culture',
      'Board games',
      'Video games',
    ],
    '🎬 My ideal evening': [
      'Netflix & chill',
      'Drinks on a terrace',
      'Fine dinner',
      'Going out unexpected',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.userProfile.interests != null) {
      _selectedInterests.addAll(widget.userProfile.interests!);
      
      // Find interests that aren't in any category
      final allCategoryInterests = categories.values.expand((i) => i).toSet();
      final customInterests = _selectedInterests.where((i) => !allCategoryInterests.contains(i)).toList();
      
      if (customInterests.isNotEmpty) {
        // Prepend "Your Interests" to categories
        final temp = <String, List<String>>{'Your Interests': customInterests};
        temp.addAll(categories);
        categories.clear();
        categories.addAll(temp);
        categories.addAll(temp); // Duplicate to match replacement logic if needed, but categories.clear handles it
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
        child: Stack(
          children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        AppLocalizations.of(context).tr('onboarding.interests.title'),
                        style: AppTextStyles.displayText,
                      ),
                      if (!widget.isEditMode)
                        const SizedBox(width: 48)
                      else
                        const SizedBox(width: 48), // Spacer to balance the back button
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).tr('onboarding.interests.subtitle'),
                        style: AppTextStyles.labelText,
                      ),
                      if (!widget.isEditMode)
                        const Text(
                          '5/6',
                          style: AppTextStyles.bodyText,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: categories.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).tr('onboarding.interests.categories.${entry.key.toLowerCase().replaceAll(' & ', '_').replaceAll(' ', '_')}'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: entry.value.map((interest) {
                              return _buildInterestChip(interest);
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: widget.isEditMode 
                        ? (_isSaving ? AppLocalizations.of(context).tr('common.saving') : AppLocalizations.of(context).tr('common.confirm')) 
                        : AppLocalizations.of(context).tr('common.next'),
                    isActive: _selectedInterests.length >= 2,
                    onPressed: () async {
                      if (_isSaving) return;
                      widget.userProfile.interests = _selectedInterests;
                      
                      if (widget.isEditMode) {
                        setState(() => _isSaving = true);
                        // Update DB
                        try {
                          final user = AuthService().currentUser;
                          if (user != null) {
                            await DatabaseService().updateProfile(user.id, {
                              'interests': _selectedInterests,
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
                            builder: (context) => UploadPictureScreen(
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
        ],
      ),
    )
    );
  }

  Widget _buildInterestChip(String interest) {
    final isSelected = _selectedInterests.contains(interest);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(interest);
          } else {
            // Limit to maximum 10 interests
            if (_selectedInterests.length < 10) {
              _selectedInterests.add(interest);
            } else {
              // Show message that limit is reached
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).tr('onboarding.interests.limit_reached')),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFFFF6B6B),
                ),
              );
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          AppLocalizations.of(context).tr('onboarding.interests.options.${interest.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}'),
          style: AppTextStyles.labelText.copyWith(
            color: isSelected ? AppColors.white : AppColors.darkGrey,
          ),
        ),
      ),
    );
  }
}
