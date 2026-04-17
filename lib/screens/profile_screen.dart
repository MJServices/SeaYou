import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/bottom_nav_bar.dart';
import 'profile/edit_bio_screen.dart';
import 'profile/edit_fantasy_screen.dart';
import 'profile/edit_quote_screen.dart';
import 'profile/edit_voice_message_screen.dart';
import 'profile/help_center_screen.dart';
import 'profile/change_password_screen.dart';
import 'profile/terms_of_service_screen.dart';
import 'profile/privacy_policy_screen.dart';
import 'premium_screen.dart';
import 'sexual_orientation_screen.dart';
import 'interests_screen.dart';
import '../widgets/sign_out_modal.dart';
import '../widgets/delete_account_modal.dart';

import '../models/user_profile.dart';
import '../i18n/app_localizations.dart';
import 'manage_gallery_photos_screen.dart';
import '../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'upload_picture_screen.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/tutorial_modal.dart';
import 'purchase_scrolls_screen.dart';
import '../services/entitlements_service.dart';

/// Profile Screen - Main profile tab
/// Shows user profile information, settings, and account actions
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _avatarUrl;
  String? _gender;
  bool _isLoading = true;
  String _userName = 'User';
  List<String> _sexualOrientations = [];
  List<String> _interests = [];
  bool _isPremium = false;
  int _availableBottles = 0;
  StreamSubscription<Map<String, dynamic>?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _subscribeProfile();
  }


  void _subscribeProfile() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 🔄 Force a profile fetch to trigger the daily scroll refresh 
    // so the count is corrected immediately on this screen.
    _databaseService.getProfile(userId, useCache: false);

    _profileSub?.cancel();
    _profileSub = _databaseService.profileStream(userId).listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'];
          _userName = profile['full_name'] ?? 'User';
          _gender = profile['gender'];
          _isPremium = profile['is_premium'] as bool? ?? false;

          if (profile['sexual_orientation'] != null) {
            _sexualOrientations =
                List<String>.from(profile['sexual_orientation']);
          }

          if (profile['interests'] != null) {
            _interests = List<String>.from(profile['interests']);
          }

          _availableBottles = ((profile['scrolls_count'] as int? ?? 0) +
              (profile['daily_free_scrolls'] as int? ?? 0))
              .clamp(0, double.maxFinite.toInt());

          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Scrollable content
            Positioned.fill(
              bottom: 90, // Space for navigation bar
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60), // Status bar space

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).tr('profile.title'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF151515),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Search functionality (placeholder)
                            },
                            child: SvgPicture.asset(
                              'assets/icons/search.svg',
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF151515),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Profile Photo Section
                    Stack(
                      children: [
                        // Decorative ellipse background
                        // Profile avatar
                        Center(
                          child: ProfileAvatar(
                            imageUrl: _avatarUrl,
                            radius: 60,
                            isLoading: _isLoading,
                          ),
                        ),
                        // Edit Photo button
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () async {
                                final profile = UserProfile(
                                  fullName: _userName,
                                  avatarUrl: _avatarUrl,
                                  email: _supabase.auth.currentUser?.email,
                                );
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UploadPictureScreen(
                                      userProfile: profile,
                                      isOnboarding:
                                          false, // Profile update mode
                                    ),
                                  ),
                                );
                                // _loadProfile() is redundant because of the stream subscription
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCFCFC),
                                  border: Border.all(
                                    color: const Color(0xFFE3E3E3),
                                    width: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)
                                      .tr('profile.edit_photo'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF363636),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Upgrade to Pro Section
                    if (!_isPremium &&
                        !(_gender?.toLowerCase() == 'woman' ||
                            _gender?.toLowerCase() == 'female' ||
                            _gender?.toLowerCase() == 'femme'))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PremiumScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFC700),
                                  Color(0xFFFAB959),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFEFA000),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Crown icon
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '👑',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)
                                            .tr('profile.upgrade_to_pro'),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF824E00),
                                        ),
                                      ),
                                      Text(
                                        AppLocalizations.of(context)
                                            .tr('profile.upgrade_description'),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF824E00),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // My Scrolls Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseScrollsScreen(),
                            ),
                          );

                          if (result == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)
                                    .tr('purchase_scrolls.success')),
                                backgroundColor: const Color(0xFF4CAF50),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/images/letter.png',
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (c, o, s) => const Icon(
                                        Icons.local_post_office,
                                        color: Color(0xFFD4B483),
                                        size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppLocalizations.of(context).tr('profile.available_scrolls'),
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF151515),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    _availableBottles.toString(),
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4B483),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Color(0xFF737373)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // General Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).tr('profile.general'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF737373),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Manage gallery photos
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('secret_souls.manage_photos'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageGalleryPhotosScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          const SizedBox(height: 16),

                          // Edit bio
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.edit_bio'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EditBioScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Edit my fantasy
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.edit_fantasy'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditFantasyScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Edit my quote
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.edit_quote'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EditQuoteScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Edit my voice message
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.edit_voice_message'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditVoiceMessageScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Change password
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.change_password'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Sexual Orientation
                          _buildSectionWithContent(
                            label: AppLocalizations.of(context)
                                .tr('profile.sexual_orientation_section'),
                            content: _sexualOrientations,
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SexualOrientationScreen(
                                    userProfile: UserProfile(
                                      sexualOrientation: _sexualOrientations,
                                      showOrientation: true,
                                    ),
                                    isEditMode: true,
                                  ),
                                ),
                              );
                              // _loadProfile() is handled by stream
                            },
                          ),

                          const SizedBox(height: 16),

                          // Interest
                          _buildInterestSection(
                            interests: _interests,
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InterestsScreen(
                                    userProfile: UserProfile(
                                      interests: _interests,
                                    ),
                                    isEditMode: true,
                                  ),
                                ),
                              );
                              // _loadProfile() is handled by stream
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Support Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)
                                .tr('profile.support_section'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF737373),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.help_center'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HelpCenterScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)
                                .tr('profile.about_section'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF737373),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('profile.understand_seayou'),
                            onTap: () {
                              TutorialModal.show(context);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('legal.terms_title'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TermsOfServiceScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSectionItem(
                            title: AppLocalizations.of(context)
                                .tr('legal.privacy_policy_title'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Account Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (_isPremium && 
                              !(_gender?.toLowerCase() == 'woman' || 
                                _gender?.toLowerCase() == 'female' ||
                                _gender?.toLowerCase() == 'femme')) ...[
                              const SizedBox(height: 12),
                              _buildSectionItem(
                                title: AppLocalizations.of(context)
                                    .tr('profile.manage_subscription'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PremiumScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          if (!_isPremium)
                            _buildActionButton(
                              title: AppLocalizations.of(context)
                                  .tr('home.debug_activate_premium'),
                              color: const Color(0xFFFF5252),
                              onTap: () async {
                                final userId = _supabase.auth.currentUser?.id;
                                if (userId != null) {
                                  final entitlements = EntitlementsService();
                                  await entitlements.grantEntitlement(userId, 'premium', 'debug_manual_activation');
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('DEBUG: Premium Activated')),
                                    );
                                  }
                                }
                              },
                            ),
                          _buildActionButton(
                            title: AppLocalizations.of(context)
                                .tr('profile.sign_out'),
                            color: const Color(0xFF737373),
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierColor:
                                    Colors.black.withValues(alpha: 0.5),
                                builder: (context) => const SignOutModal(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            title: AppLocalizations.of(context)
                                .tr('profile.delete_account'),
                            color: const Color(0xFFFB3748), // Warning Red
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierColor:
                                    Colors.black.withValues(alpha: 0.5),
                                builder: (context) =>
                                    const DeleteAccountModal(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),

            // Bottom Navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavBar(
                activeScreen: 'profile',
                userProfile: _avatarUrl != null
                    ? {
                        'avatar_url': _avatarUrl,
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF363636),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF737373),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionWithContent({
    required String label,
    required List<String> content,
    required VoidCallback onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 20,
                  color: Color(0xFF151515),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...content.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLocalizations.of(context).tr(
                    'onboarding.sexual_orientation.options.${item.trim().toLowerCase()}'),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF363636),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildInterestSection({
    required List<String> interests,
    required VoidCallback onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).tr('profile.interests_section'),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 20,
                  color: Color(0xFF151515),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: interests.map((interest) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0AC5C5),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                _translateInterest(context, interest),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _translateInterest(BuildContext context, String interest) {
    final slug = interest
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    return AppLocalizations.of(context)
        .tr('onboarding.interests.options.$slug');
  }

  Widget _buildActionButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
