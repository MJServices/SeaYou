import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../services/database_service.dart';
import '../../widgets/voice_player.dart';

/// Edit Bio Screen - Allows user to edit their bio/email
class EditBioScreen extends StatefulWidget {
  const EditBioScreen({super.key});

  @override
  State<EditBioScreen> createState() => _EditBioScreenState();
}

class _EditBioScreenState extends State<EditBioScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;
  String? _voiceClipUrl;

  bool get isFormValid =>
      _bioController.text.trim().isNotEmpty && !_isSaving;

  @override
  void initState() {
    super.initState();
    _loadCurrentBio();
  }

  Future<void> _loadCurrentBio() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _databaseService.getProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _bioController.text = profile['about'] ?? '';
          _emailController.text = profile['email'] ?? '';
          _isLoading = false;
        });

        // Fetch voice clip separately
        final prefs = await _databaseService.getUserPreferences(userId);
        if (prefs != null && mounted) {
          setState(() {
            _voiceClipUrl = prefs['voice_clip_url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading bio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load bio';
        });
      }
    }
  }

  Future<void> _saveBio() async {
    if (!isFormValid) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      final bio = _bioController.text.trim();
      
      // Validate bio length
      if (bio.length > 500) {
        throw Exception('Bio must be 500 characters or less');
      }

      await _databaseService.updateBio(userId, bio);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bio updated successfully!'),
          backgroundColor: Color(0xFF0AC5C5),
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving bio: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Decorative ellipse
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0AC5C5).withValues(alpha: 0.2),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF151515),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Edit bio',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF151515),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF363636),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.bodyText.copyWith(
                              color: _emailController.text.isNotEmpty
                                  ? AppColors.darkGrey
                                  : AppColors.grey,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your email address',
                              hintStyle: AppTextStyles.bodyText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _emailController.text.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.grey,
                                  width: 0.8,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _emailController.text.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.grey,
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 0.8,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Bio',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF363636),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bioController,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.bodyText.copyWith(
                              color: _bioController.text.isNotEmpty
                                  ? AppColors.darkGrey
                                  : AppColors.grey,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Describe yourself',
                              hintStyle: AppTextStyles.bodyText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _bioController.text.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.grey,
                                  width: 0.8,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _bioController.text.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.grey,
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 0.8,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Voice Intro Section
                          if (_voiceClipUrl != null) ...[
                            const Text(
                              'Voice Intro',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF363636),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: VoicePlayer(
                                audioUrl: _voiceClipUrl,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ] else 
                            const SizedBox(height: 32),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomButton(
                      text: _isSaving ? 'Saving...' : 'Save',
                      isActive: isFormValid,
                      onPressed: isFormValid ? _saveBio : null,
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

