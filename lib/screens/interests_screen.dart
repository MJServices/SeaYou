import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'upload_picture_screen.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

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

  final Map<String, List<String>> categories = {
    'Movies & Series': [
      'K-dramas',
      'Bollywood',
      'Series',
      'Movies',
      'Anime',
      'Comedy',
      'Documentries',
      'Action Movies',
      'Reality Shows',
      'Sports',
      'Thrillers',
      'Romantic Comedy',
    ],
    'Sports & Games': [
      'Football',
      'Basketball',
      'Olympics',
      'Hockey',
      'Board Games',
      'Badminton',
      'Pole Dance',
      'Tennis',
      'Fitness',
      'Rugby',
    ],
    'Pets': [
      'Cats',
      'Dogs',
      'Fish',
      'Allergic',
      'Turtle',
      'Other',
      'I want one',
    ],
    'Activities': [
      'Shopping',
      'Car race',
      'Karaoke',
      'Pubs',
      'Art Galleries',
      'Stand Ups',
      'Festivals',
      'Parties',
      'Roller Skating',
      'Bowling',
      'Concert',
      'Road trips',
      'Gaming',
      'Blog',
      'Nature',
      'Jet Ski',
      'Snorkeling',
    ],
    'Creative': [
      'Photography',
      'Tattoos',
      'Digital Art',
      'Writing',
      'Vintage Shopping',
      'Design',
      'Music Production',
      'Crafting',
      'Vinyl Record',
    ],
    'Restaurants': [
      'BBQ',
      'Brunch',
      'Ramen',
      'Tea',
      'Vegetarian',
      'Fine Dining',
      'Wine Tasting',
      'Pastries',
      'Pasta',
      'Asian Food',
      'Street Food',
      'Sushi',
      'Cocktails',
      'Bars',
    ],
    'Meditation': [
      'Bible Reading',
      'Therapy',
      'Walking',
      'Tea',
      'Morning Yoga',
      'Journaling',
      'Podcasts',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.userProfile.interests != null) {
      _selectedInterests.addAll(widget.userProfile.interests!);
    }
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
                      const Text(
                        'Interests',
                        style: AppTextStyles.displayText,
                      ),
                      if (!widget.isEditMode)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UploadPictureScreen(
                                  userProfile: widget.userProfile,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Skip',
                            style: AppTextStyles.bodyText,
                          ),
                        )
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
                      const Text(
                        'Select at least two',
                        style: AppTextStyles.labelText,
                      ),
                      if (!widget.isEditMode)
                        const Text(
                          '4/5',
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
                            entry.key,
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
                    text: widget.isEditMode ? 'Save' : 'Next',
                    isActive: _selectedInterests.length >= 2,
                    onPressed: () async {
                      widget.userProfile.interests = _selectedInterests;
                      
                      if (widget.isEditMode) {
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
                              SnackBar(content: Text('Error updating profile: $e')),
                            );
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
            _selectedInterests.add(interest);
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
          interest,
          style: AppTextStyles.labelText.copyWith(
            color: isSelected ? AppColors.white : AppColors.darkGrey,
          ),
        ),
      ),
    );
  }
}
