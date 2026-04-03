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
import '../services/onboarding_service.dart';
import 'home_screen.dart';

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
  // Whether user authorizes their face photo to appear in 'Chamber of Secrets'
  bool _showInSecretSouls = true;

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
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context).tr('notification.error')}: $e')),
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
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context).tr('notification.error')}: $e')),
        );
      }
    }
  }

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Photo tooltip is shown after the user picks their first photo via _showPhotoBubble()
    // Do NOT show it here as well — that causes the dialog to appear twice.
  }
  Future<void> _proceedToNextScreen() async {
    setState(() => _isLoading = true);

    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('No user logged in');
      final userId = user.id;

      // 1. Create the base profile FIRST so Foreign Keys are satisfied!
      debugPrint('✅ Saving full profile to database...');
      final int currentYear = DateTime.now().year;
      final int age = widget.userProfile.age ?? 0;
      final int birthYear = currentYear - age;
      widget.userProfile.birthYear = birthYear;

      final gender = widget.userProfile.gender?.toLowerCase() ?? '';
      final isPremiumWoman = gender == 'woman' || gender == 'female' || gender == 'femme';

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
        avatarUrl: null, // Will be updated correctly when the photo uploads below
        language: widget.userProfile.language,
        secretDesire: widget.userProfile.secretDesire,
        secretQuote: widget.userProfile.secretQuote,
        secretAudioUrl: widget.userProfile.secretAudioUrl,
        gender: widget.userProfile.gender,
        department: widget.userProfile.department,
        tier: isPremiumWoman ? 'premium' : 'free',
        isPremium: isPremiumWoman,
      );

      if (widget.userProfile.secretDesire != null &&
          widget.userProfile.secretDesire!.trim().isNotEmpty) {
        try {
          await DatabaseService().createFantasy(
              userId, widget.userProfile.secretDesire!.trim());
        } catch (e) {
          debugPrint('⚠️ Error creating fantasy during onboarding: $e');
        }
      }

      // 2. Upload photos and assets which link via Foreign Key to the core profile
      if (_selectedImage != null) {
        final file = File(_selectedImage!.path);
        debugPrint('📸 Uploading main photo for user: ${user.id}');

        final res = await DatabaseService().uploadFirstFacePhotoAndInsert(
          userId: user.id,
          imageFile: file,
          showInSecretSouls: _showInSecretSouls,
        );

        if (res == null) throw Exception('Failed to upload main photo');
        widget.userProfile.avatarUrl = res['url'];

        for (var i = 0; i < _galleryPhotos.length; i++) {
          debugPrint('📸 Uploading gallery photo ${i + 1}');
          await DatabaseService().uploadGalleryPhoto(
            user.id,
            File(_galleryPhotos[i].path),
          );
        }

        debugPrint('✅ All photos uploaded successfully');

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
          }
        }
      }

      if (!mounted) return;
      debugPrint('✅ Navigating to HomeScreen');
      
      // Clear onboarding progress as it's completed
      await OnboardingService().clearAll();

      if (mounted) {
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
          message:
              AppLocalizations.of(context).tr('notification.upload_failed'),
          gradientColors: [Colors.red, Colors.redAccent],
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPhotoBubble() async {
    final tr = AppLocalizations.of(context);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.tr('tooltip.photo.title'),
            style: AppTextStyles.displayText),
        content: Text(
          tr.tr('tooltip.photo.message'),
          style: AppTextStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr.tr('tooltip.photo.ok'),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFaceVerificationErrorDialog(FaceVerificationResult result) {
    if (result == FaceVerificationResult.success ||
        result == FaceVerificationResult.error) {
      if (result == FaceVerificationResult.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).tr('notification.error'))),
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
        messageKey =
            'secret_souls.main_photo_warning.invalid_orientation_message';
        break;
      default:
        titleKey = 'secret_souls.main_photo_warning.no_face_title';
        messageKey = 'secret_souls.main_photo_warning.no_face_message';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).tr(titleKey),
            style: AppTextStyles.displayText),
        content: Text(
          AppLocalizations.of(context).tr(messageKey),
          style: AppTextStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).tr('common.ok'),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              child: SingleChildScrollView(
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
                              AppLocalizations.of(context)
                                  .tr('onboarding.upload_picture.title'),
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
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _pickImageFromGallery,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightPurple.withValues(alpha: 0.5),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: _showInSecretSouls,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setState(
                                    () => _showInSecretSouls = val ?? true),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() =>
                                      _showInSecretSouls = !_showInSecretSouls),
                                  child: Text(
                                    AppLocalizations.of(context).tr(
                                        'onboarding.upload_picture.secret_room_consent'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 12,
                                      color: AppColors.darkGrey,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, top: 4, bottom: 8),
                            child: Text(
                              AppLocalizations.of(context).tr(
                                  'onboarding.upload_picture.gallery_secret_room_info'),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11,
                                color: AppColors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).tr(
                                  'onboarding.upload_picture.gallery_label'),
                              style: AppTextStyles.bodyText,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _galleryPhotos.length +
                                    (_galleryPhotos.length < 5 ? 1 : 0),
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
                                        child: const Icon(Icons.add,
                                            color: AppColors.grey),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 60,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: FileImage(File(
                                                _galleryPhotos[index].path)),
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
                                            child: const Icon(Icons.close,
                                                size: 12, color: Colors.white),
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
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CustomButton(
                            text: AppLocalizations.of(context).tr(
                                'onboarding.upload_picture.upload_from_gallery'),
                            onPressed: _pickImageFromGallery,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: AppLocalizations.of(context)
                                .tr('onboarding.upload_picture.take_photo'),
                            onPressed: _takePhoto,
                          ),
                          const SizedBox(height: 16),
                          if (_selectedImage != null)
                            Builder(builder: (context) {
                              final hasQuote =
                                  widget.userProfile.secretQuote != null &&
                                      widget
                                          .userProfile.secretQuote!.isNotEmpty;
                              final hasFantasy =
                                  widget.userProfile.secretDesire != null &&
                                      widget
                                          .userProfile.secretDesire!.isNotEmpty;
                              final hasAudio =
                                  widget.userProfile.secretAudioUrl != null &&
                                      widget.userProfile.secretAudioUrl!
                                          .isNotEmpty;

                              final requirementsMet = !widget.isOnboarding ||
                                  (hasQuote && hasFantasy && hasAudio);
                              final canProceed = requirementsMet;

                              return Column(
                                children: [
                                  if (!canProceed && widget.isOnboarding)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        AppLocalizations.of(context).tr(
                                          'onboarding.upload_picture.requirements_missing',
                                          params: {
                                            'quote': !hasQuote
                                                ? AppLocalizations.of(context)
                                                    .tr('onboarding.upload_picture.requirements_quote')
                                                : '',
                                            'fantasy': !hasFantasy
                                                ? AppLocalizations.of(context)
                                                    .tr('onboarding.upload_picture.requirements_fantasy')
                                                : '',
                                            'audio': !hasAudio
                                                ? AppLocalizations.of(context)
                                                    .tr('onboarding.upload_picture.requirements_audio')
                                                : '',
                                          },
                                        ),
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  CustomButton(
                                    text: widget.isOnboarding
                                        ? AppLocalizations.of(context)
                                            .tr('common.continue')
                                        : AppLocalizations.of(context)
                                            .tr('common.confirm'),
                                    isActive: canProceed,
                                    onPressed: canProceed
                                        ? _proceedToNextScreen
                                        : () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(AppLocalizations.of(
                                                        context)
                                                    .tr('secret_souls.main_photo_warning.title')),
                                                content: Text(AppLocalizations.of(
                                                        context)
                                                    .tr('secret_souls.main_photo_warning.message')),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(AppLocalizations
                                                            .of(context)
                                                        .tr('secret_souls.main_photo_warning.cancel')),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _proceedToNextScreen();
                                                    },
                                                    child: Text(AppLocalizations
                                                            .of(context)
                                                        .tr('secret_souls.main_photo_warning.set_main')),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                  ),
                                ],
                              );
                            }),
                          if (_selectedImage != null)
                            const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
