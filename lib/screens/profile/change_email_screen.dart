import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../services/auth_service.dart';
import '../verification_screen.dart';

/// Change Email Address Screen
/// Allows users to update their email address
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final TextEditingController _currentEmailController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isButtonEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _newEmailController.addListener(_updateButtonState);
    _loadCurrentEmail();
  }

  Future<void> _loadCurrentEmail() async {
    try {
      final currentEmail = _supabase.auth.currentUser?.email;
      if (currentEmail != null && mounted) {
        setState(() {
          _currentEmailController.text = currentEmail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading current email: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateButtonState() {
    setState(() {
      final newEmail = _newEmailController.text.trim();
      final currentEmail = _currentEmailController.text.trim();
      _isButtonEnabled = newEmail.isNotEmpty &&
          newEmail.contains('@') &&
          newEmail != currentEmail &&
          !_isSaving;
    });
  }

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Verify Password',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your current password to change your email address.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                Navigator.pop(context);
                if (password.isNotEmpty) {
                  _changeEmail(password);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0AC5C5),
              ),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeEmail(String password) async {
    debugPrint('🚀 Starting email change process...');
    setState(() => _isSaving = true);

    try {
      final newEmail = _newEmailController.text.trim();
      debugPrint('📧 New email target: $newEmail');
      
      // Verify current password first
      debugPrint('🔐 Verifying current password...');
      final currentEmail = _currentEmailController.text.trim();
      await _supabase.auth.signInWithPassword(
        email: currentEmail,
        password: password,
      );
      debugPrint('✅ Password verified successfully');

      // Check if new email is already in use
      debugPrint('🔍 Checking if email exists: $newEmail');
      final bool emailExists = await _authService.checkEmailExists(newEmail);
      if (emailExists) {
        debugPrint('❌ Email already in use: $newEmail');
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This email is already associated with another account.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      debugPrint('✅ Email is available');

      // Password verified, now update email
      debugPrint('🔄 Calling updateEmail...');
      await _authService.updateEmail(newEmail);
      debugPrint('✅ updateEmail completed');

      // Wait a moment to avoid race conditions or rate-limiting with the email provider
      debugPrint('⏳ Waiting 2 seconds before ensuring delivery...');
      await Future.delayed(const Duration(seconds: 2));

      // FORCE resend to ensure OTP delivery (crucial for "functionality not working" fix)
      try {
        debugPrint('🔄 Attempting forced resend of verification code...');
        await _authService.resendVerificationCode(newEmail, OtpType.emailChange);
        debugPrint('✅ Forced resend successful');
      } catch (e) {
        debugPrint('⚠️ Resend attempt failed (might have sent already): $e');
      }
      
      if (!mounted) {
        debugPrint('❌ Context unmounted, aborting navigation');
        return;
      }

      setState(() => _isSaving = false);

      // Navigate to verification screen
      debugPrint('➡️ Navigating to VerificationScreen...');
      final bool? verified = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            email: newEmail,
            isEmailChange: true,
          ),
        ),
      );

      debugPrint('⬅️ Returned from VerificationScreen. Verified: $verified');

      if (verified == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email updated successfully!'),
            backgroundColor: Color(0xFF0AC5C5),
          ),
        );
        Navigator.pop(context); // Go back to profile info
      }
    } catch (e) {
      debugPrint('❌ Error changing email: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        
        String errorMessage = 'Failed to change email';
        if (e.toString().contains('Invalid login credentials')) {
          errorMessage = 'Incorrect password. Please try again.';
        } else if (e.toString().contains('already registered')) {
          errorMessage = 'This email is already in use.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFEFAEE),
        ),
        child: Stack(
          children: [
            // Decorative ellipse background
            Positioned(
              left: 0,
              top: -303,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0AC5C5).withValues(alpha: 0.2),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 300, sigmaY: 300),
                  child: Container(),
                ),
              ),
            ),

            // Content
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
                          'Edit Email Address',
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

                  const SizedBox(height: 16),

                  // Form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Email Address
                        const Text(
                          'Current Email Address',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF0AC5C5),
                              width: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _currentEmailController,
                            enabled: false,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2B2B2B),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'alexjohn@gmail.com',
                              hintStyle: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF464646),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // New Email Address
                        const Text(
                          'Enter New Email Address',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF464646),
                              width: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _newEmailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2B2B2B),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'e.g alexjohn@gmail.com',
                              hintStyle: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF464646),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Verify Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: _isButtonEnabled && !_isSaving
                          ? _showPasswordDialog
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isButtonEnabled
                              ? const Color(0xFF0AC5C5)
                              : const Color(0xFFE3E3E3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isSaving ? 'Updating...' : 'Verify',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _isButtonEnabled
                                ? const Color(0xFFFEFAEE)
                                : const Color(0xFF464646),
                          ),
                        ),
                      ),
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
