import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../../services/auth_service.dart';

/// Change Password Screen
/// Allows users to update their password
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isButtonEnabled = false;
  bool _isSaving = false;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasSymbol = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _newPasswordController.text;
    final oldPassword = _oldPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _isButtonEnabled =
          _hasMinLength && _hasSymbol && _hasNumber && 
          password.isNotEmpty && oldPassword.isNotEmpty &&
          !_isSaving;
    });
  }

  Future<void> _changePassword() async {
    if (!_isButtonEnabled) return;

    setState(() => _isSaving = true);

    try {
      final currentPassword = _oldPasswordController.text;
      final newPassword = _newPasswordController.text;

      await _authService.changePassword(currentPassword, newPassword);

      if (!mounted) return;

      // Show success message
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1FC16B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎉', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'You have successfully changed your password',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFFEFAEE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to profile
        }
      });
    } catch (e) {
      debugPrint('Error changing password: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        
        String errorMessage = 'Failed to change password';
        if (e.toString().contains('Current password is incorrect')) {
          errorMessage = 'Current password is incorrect';
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
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Change password',
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

                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Create your password',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Your password must be at least 8 characters long and contain one symbol and number',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF464646),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Current Password Input (Added)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Current Password',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF0AC5C5),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _oldPasswordController,
                                obscureText: !_isOldPasswordVisible,
                                onChanged: (_) => _validatePassword(),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2B2B2B),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter current password',
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
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isOldPasswordVisible = !_isOldPasswordVisible;
                                });
                              },
                              child: Icon(
                                _isOldPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF464646),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // New Password Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'New Password',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // New Password Input
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF0AC5C5),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newPasswordController,
                                obscureText: !_isNewPasswordVisible,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2B2B2B),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter new password',
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
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isNewPasswordVisible =
                                      !_isNewPasswordVisible;
                                });
                              },
                              child: Icon(
                                _isNewPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF464646),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Password Requirements
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRequirement(
                            'Minimum of 8 characters',
                            _hasMinLength,
                          ),
                          const SizedBox(height: 8),
                          _buildRequirement(
                            'At least a symbol',
                            _hasSymbol,
                          ),
                          const SizedBox(height: 8),
                          _buildRequirement(
                            'At least a number',
                            _hasNumber,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 400),

                    // Save Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: _isButtonEnabled && !_isSaving
                            ? _changePassword
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
                            _isSaving ? 'Saving...' : 'Save new password',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: isMet ? const Color(0xFF151515) : const Color(0xFF464646),
      ),
    );
  }
}
