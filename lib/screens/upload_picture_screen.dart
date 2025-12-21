import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'account_setup_done_screen.dart';
import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import '../services/tutorial_service.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadPictureScreen extends StatefulWidget {
  final UserProfile userProfile;
  final bool isOnboarding;
  
  const UploadPictureScreen({
    super.key,
    required this.userProfile,
    this.isOnboarding = true, // Default to onboarding mode
  });

  @override
  State<UploadPictureScreen> createState() => _UploadPictureScreenState();
}

class _UploadPictureScreenState extends State<UploadPictureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final t = TutorialService();
      final seen = await t.hasSeenPhotoTooltip();
      if (!seen && mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          builder: (context) {
            final tr = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(tr.tr('tooltip.photo.title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.tr('tooltip.photo.line1')),
                  const SizedBox(height: 8),
                  Text(tr.tr('tooltip.photo.line2')),
                  const SizedBox(height: 8),
                  Text(tr.tr('tooltip.photo.line3')),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await t.setSeenPhotoTooltip();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(tr.tr('tooltip.photo.ok')),
                ),
              ],
            );
          },
        );
      }
    });
  }

  Future<void> _proceedToNextScreen() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedImage != null) {
        final user = AuthService().currentUser;
        if (user != null) {
          final file = File(_selectedImage!.path);
          
          debugPrint('📸 Uploading photo for user: ${user.id}');
          
          // Just upload to storage - profile creation will handle database insert
          final String ext = file.path.split('.').last;
          final String path = '${user.id}/face_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          await Supabase.instance.client.storage
              .from('face_photos')
              .upload(path, file, fileOptions: const FileOptions(upsert: false));
          
          final publicUrl = Supabase.instance.client.storage
              .from('face_photos')
              .getPublicUrl(path);
          
          widget.userProfile.avatarUrl = publicUrl;
          debugPrint('✅ Photo uploaded successfully: $publicUrl');
        } else {
          debugPrint('❌ No user logged in');
          throw Exception('No user logged in');
        }
      }

      
      // Check if this is onboarding or profile update
      if (widget.isOnboarding) {
        // Onboarding: proceed to AccountSetupDoneScreen
        if (mounted) {
          debugPrint('✅ Navigating to AccountSetupDoneScreen');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccountSetupDoneScreen(
                userProfile: widget.userProfile,
              ),
            ),
          );
        }
      } else {
        // Profile update: save to database and go back
        final user = AuthService().currentUser;
        if (user != null && widget.userProfile.avatarUrl != null) {
          debugPrint('💾 Updating profile picture in database...');
          
          // Upload to database using uploadFirstFacePhotoAndInsert
          final file = File(_selectedImage!.path);
          final res = await DatabaseService().uploadFirstFacePhotoAndInsert(
            userId: user.id,
            imageFile: file,
          );
          
          if (res != null) {
            debugPrint('✅ Profile picture updated successfully');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile picture updated!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Go back to profile screen
              Navigator.pop(context);
            }
          } else {
            throw Exception('Failed to update profile picture in database');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _proceedToNextScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Run face verification in background without blocking navigation
  void _runFaceVerificationInBackground(String photoId, String url) async {
    try {
      debugPrint('🔍 Running face verification in background...');
      final funcs = Supabase.instance.client.functions;
      final resp = await funcs.invoke(
        'face-verify',
        body: {
          'photo_id': photoId,
          'image_url': url,
          'threshold': 75,
        },
      );
      final data = resp.data as Map<String, dynamic>? ?? {};
      final passed = (data['passed'] as bool?) ?? false;
      final score = (data['score'] as num?)?.toInt() ?? 0;
      
      if (passed) {
        debugPrint('✅ Face verification passed (score: $score)');
      } else {
        debugPrint('⚠️ Face verification failed (score: $score < 75)');
      }
    } catch (e) {
      debugPrint('❌ Face verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
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
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Upload a picture',
                            style: AppTextStyles.displayText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '2/3',
                          style: AppTextStyles.bodyText,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.lightPurple,
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedImage!.path)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Center(
                              child: Text(
                                'A',
                                style: AppTextStyles.largeTitle.copyWith(
                                  fontSize: 80,
                                  color: AppColors.purple,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomButton(
                          text: 'Upload from gallery',
                          onPressed: _pickImageFromGallery,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Take photo',
                          onPressed: _takePhoto,
                        ),
                        const SizedBox(height: 16),
                        // Show Continue button if all requirements are met
                        if (_selectedImage != null)
                          Builder(
                            builder: (context) {
                              // Verify all requirements
                              final hasQuote = widget.userProfile.secretDesire != null && 
                                             widget.userProfile.secretDesire!.isNotEmpty;
                              final hasAudio = widget.userProfile.secretAudioUrl != null && 
                                             widget.userProfile.secretAudioUrl!.isNotEmpty;
                              
                              // If onboarding, require all 3. If updating profile, only require image (already checked by _selectedImage != null outer if)
                              final requirementsMet = !widget.isOnboarding || (hasQuote && hasAudio);
                              final canProceed = requirementsMet; // _selectedImage is already not null here

                              return Column(
                                children: [
                                  if (!canProceed && widget.isOnboarding)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        'Required: Photo${!hasQuote ? ", Quote" : ""}${!hasAudio ? ", Audio" : ""}',
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  CustomButton(
                                    text: widget.isOnboarding ? 'Continue' : 'Save',
                                    isActive: canProceed,
                                    onPressed: canProceed ? _proceedToNextScreen : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please complete all requirements: Photo, Quote, and Audio message.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            }
                          ),
                        if (_selectedImage != null)
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
