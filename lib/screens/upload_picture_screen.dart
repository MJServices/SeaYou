import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';

import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import '../services/tutorial_service.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/face_detection_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
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
  final List<XFile> _galleryPhotos = [];
  final _faceDetector = FaceDetectionService();

  Future<void> _pickImageFromGallery() async {
    try {
      if (_selectedImage == null) {
        final t = TutorialService();
        final seen = await t.hasSeenPhotoTooltip();
        if (!seen) {
          await _showPhotoBubble();
          await t.setSeenPhotoTooltip();
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        if (_selectedImage == null) {
          // Check for face in the primary photo
          setState(() => _isLoading = true);
          final result = await _faceDetector.verifyFace(File(image.path));
          setState(() => _isLoading = false);

          if (result != FaceVerificationResult.success) {
            if (mounted) {
              _showFaceVerificationErrorDialog(result);
            }
            return;
          }

          setState(() {
            _selectedImage = image;
          });
          // Show the explanatory bubble as soon as they pick the first photo
          _showPhotoBubble();
        } else if (_galleryPhotos.length < 5) {
          setState(() {
            _galleryPhotos.add(image);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).tr('notification.error')}: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      if (_selectedImage == null) {
        final t = TutorialService();
        final seen = await t.hasSeenPhotoTooltip();
        if (!seen) {
          await _showPhotoBubble();
          await t.setSeenPhotoTooltip();
        }
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        if (_selectedImage == null) {
          // Check for face in the primary photo
          setState(() => _isLoading = true);
          final result = await _faceDetector.verifyFace(File(photo.path));
          setState(() => _isLoading = false);

          if (result != FaceVerificationResult.success) {
            if (mounted) {
              _showFaceVerificationErrorDialog(result);
            }
            return;
          }

          setState(() {
            _selectedImage = photo;
          });
          _showPhotoBubble();
        } else if (_galleryPhotos.length < 5) {
          setState(() {
            _galleryPhotos.add(photo);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).tr('notification.error')}: $e')),
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
        final tr = AppLocalizations.of(context);
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(tr.tr('tooltip.photo.title'), style: AppTextStyles.displayText),
              content: Text(tr.tr('tooltip.photo.message'), style: AppTextStyles.bodyText),
              actions: [
                TextButton(
                  onPressed: () async {
                    await t.setSeenPhotoTooltip();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(tr.tr('tooltip.photo.ok'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
          
          debugPrint('📸 Uploading main photo for user: ${user.id}');
          
          // Use DatabaseService to upload first face photo
          final res = await DatabaseService().uploadFirstFacePhotoAndInsert(
            userId: user.id,
            imageFile: file,
          );
          
          if (res == null) throw Exception('Failed to upload main photo');
          widget.userProfile.avatarUrl = res['url'];

          // Upload gallery photos if any
          for (var i = 0; i < _galleryPhotos.length; i++) {
            debugPrint('📸 Uploading gallery photo ${i + 1}');
            await DatabaseService().uploadGalleryPhoto(
              user.id,
              File(_galleryPhotos[i].path),
            );
          }
          
          debugPrint('✅ All photos uploaded successfully');

          // Upload secret audio if it's a local file
          if (widget.userProfile.secretAudioUrl != null && 
              !widget.userProfile.secretAudioUrl!.startsWith('http')) {
            debugPrint('🎤 Uploading secret audio clip...');
            final audioFile = File(widget.userProfile.secretAudioUrl!);
            if (await audioFile.exists()) {
              final audioUrl = await DatabaseService().uploadAudioClip(
                userId: user.id,
                audioFile: audioFile,
              );
              if (audioUrl != null) {
                widget.userProfile.secretAudioUrl = audioUrl;
                debugPrint('✅ Audio uploaded: $audioUrl');
              }
            } else {
              debugPrint('⚠️ Audio file does not exist at path: ${widget.userProfile.secretAudioUrl}');
            }
          }
        } else {
          debugPrint('❌ No user logged in');
          throw Exception('No user logged in');
        }
      }

      if (mounted) {
        debugPrint('✅ Saving full profile to database...');
        final userId = AuthService().currentUser?.id;
        if (userId != null) {
          final int currentYear = DateTime.now().year;
          final int age = widget.userProfile.age ?? 0;
          final int birthYear = currentYear - age;
          widget.userProfile.birthYear = birthYear;

          await DatabaseService().createProfile(
            userId: userId,
            email: widget.userProfile.email ?? '',
            fullName: widget.userProfile.fullName ?? '',
            age: age,
            birthYear: birthYear,
            city: widget.userProfile.city ?? '',
            about: widget.userProfile.about ?? '',
            sexualOrientation: widget.userProfile.sexualOrientation ?? [],
            showOrientation: widget.userProfile.showOrientation,
            expectation: widget.userProfile.expectation ?? '',
            interestedIn: widget.userProfile.interestedIn ?? '',
            interests: widget.userProfile.interests ?? [],
            avatarUrl: widget.userProfile.avatarUrl,
            language: widget.userProfile.language,
            secretDesire: widget.userProfile.secretDesire,
            secretQuote: widget.userProfile.secretQuote,
            secretAudioUrl: widget.userProfile.secretAudioUrl,
            gender: widget.userProfile.gender,
            department: widget.userProfile.department,
          );
          
          if (widget.userProfile.secretDesire != null && widget.userProfile.secretDesire!.trim().isNotEmpty) {
            try {
              await DatabaseService().createFantasy(userId, widget.userProfile.secretDesire!.trim());
            } catch (e) {
              debugPrint('⚠️ Error creating fantasy during onboarding: $e');
            }
          }
        }

        debugPrint('✅ Navigating to HomeScreen');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _proceedToNextScreen: $e');
      if (mounted) {
        NotificationService().show(
          context: context,
          title: AppLocalizations.of(context).tr('notification.error'),
          message: AppLocalizations.of(context).tr('notification.upload_failed'),
          gradientColors: [Colors.red, Colors.redAccent],
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

  Future<void> _showPhotoBubble() async {
    final tr = AppLocalizations.of(context);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.tr('tooltip.photo.title'), style: AppTextStyles.displayText),
        content: Text(
          tr.tr('tooltip.photo.message'),
          style: AppTextStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr.tr('tooltip.photo.ok'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  void _showFaceVerificationErrorDialog(FaceVerificationResult result) {
    if (result == FaceVerificationResult.success || result == FaceVerificationResult.error) {
      if (result == FaceVerificationResult.error) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).tr('notification.error'))),
          );
      }
      return;
    }

    String titleKey;
    String messageKey;

    switch (result) {
      case FaceVerificationResult.noFace:
        titleKey = 'secret_souls.main_photo_warning.no_face_title';
        messageKey = 'secret_souls.main_photo_warning.no_face_message';
        break;
      case FaceVerificationResult.tooDistant:
        titleKey = 'secret_souls.main_photo_warning.too_distant_title';
        messageKey = 'secret_souls.main_photo_warning.too_distant_message';
        break;
      case FaceVerificationResult.notForwardFacing:
        titleKey = 'secret_souls.main_photo_warning.not_forward_title';
        messageKey = 'secret_souls.main_photo_warning.not_forward_message';
        break;
      case FaceVerificationResult.multipleFaces:
        titleKey = 'secret_souls.main_photo_warning.multiple_faces_title';
        messageKey = 'secret_souls.main_photo_warning.multiple_faces_message';
        break;
      case FaceVerificationResult.invalidOrientation:
        titleKey = 'secret_souls.main_photo_warning.invalid_orientation_title';
        messageKey = 'secret_souls.main_photo_warning.invalid_orientation_message';
        break;
      default:
        titleKey = 'secret_souls.main_photo_warning.no_face_title';
        messageKey = 'secret_souls.main_photo_warning.no_face_message';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).tr(titleKey), style: AppTextStyles.displayText),
        content: Text(
          AppLocalizations.of(context).tr(messageKey),
          style: AppTextStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).tr('common.ok'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNoFaceDialog() {
    _showFaceVerificationErrorDialog(FaceVerificationResult.noFace);
  }

  @override
  void dispose() {
    _faceDetector.dispose();
    super.dispose();
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(context).tr('onboarding.upload_picture.title'),
                            style: AppTextStyles.displayText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '6/6',
                          style: AppTextStyles.bodyText,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      width: 200, // Slightly smaller to leave room for gallery
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.lightPurple.withValues(alpha: 0.5), // Softened
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
                                  fontSize: 60,
                                  color: AppColors.purple,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).tr('onboarding.upload_picture.gallery_label'),
                            style: AppTextStyles.bodyText,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _galleryPhotos.length + (_galleryPhotos.length < 5 ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _galleryPhotos.length) {
                                  return GestureDetector(
                                    onTap: _pickImageFromGallery,
                                    child: Container(
                                      width: 60,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGrey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add, color: AppColors.grey),
                                    ),
                                  );
                                }
                                return Stack(
                                  children: [
                                    Container(
                                      width: 60,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(File(_galleryPhotos[index].path)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _galleryPhotos.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomButton(
                          text: AppLocalizations.of(context).tr('onboarding.upload_picture.upload_from_gallery'),
                          onPressed: _pickImageFromGallery,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: AppLocalizations.of(context).tr('onboarding.upload_picture.take_photo'),
                          onPressed: _takePhoto,
                        ),
                        const SizedBox(height: 16),
                        // Show Continue button if all requirements are met
                        if (_selectedImage != null)
                          Builder(
                            builder: (context) {
                              // Verify all requirements
                              final hasQuote = widget.userProfile.secretQuote != null && 
                                             widget.userProfile.secretQuote!.isNotEmpty;
                              final hasFantasy = widget.userProfile.secretDesire != null && 
                                             widget.userProfile.secretDesire!.isNotEmpty;
                              final hasAudio = widget.userProfile.secretAudioUrl != null && 
                                             widget.userProfile.secretAudioUrl!.isNotEmpty;
                              
                              // If onboarding, require all 4.
                              final requirementsMet = !widget.isOnboarding || (hasQuote && hasFantasy && hasAudio);
                              final canProceed = requirementsMet; 

                              return Column(
                                children: [
                                  if (!canProceed && widget.isOnboarding)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        AppLocalizations.of(context).tr(
                                          'onboarding.upload_picture.requirements_missing',
                                          params: {
                                            'quote': !hasQuote ? AppLocalizations.of(context).tr('onboarding.upload_picture.requirements_quote') : '',
                                            'fantasy': !hasFantasy ? AppLocalizations.of(context).tr('onboarding.upload_picture.requirements_fantasy') : '',
                                            'audio': !hasAudio ? AppLocalizations.of(context).tr('onboarding.upload_picture.requirements_audio') : '',
                                          },
                                        ),
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  CustomButton(
                                    text: widget.isOnboarding ? AppLocalizations.of(context).tr('common.continue') : AppLocalizations.of(context).tr('common.confirm'),
                                    isActive: canProceed,
                                    onPressed: canProceed ? _proceedToNextScreen : () {
                  showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).tr('secret_souls.main_photo_warning.title')),
            content: Text(AppLocalizations.of(context).tr('secret_souls.main_photo_warning.message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).tr('secret_souls.main_photo_warning.cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedToNextScreen();
                },
                child: Text(AppLocalizations.of(context).tr('secret_souls.main_photo_warning.set_main')),
              ),
            ],
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
