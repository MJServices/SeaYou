import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../i18n/app_localizations.dart';

/// Change Password Screen
/// Allows users to update their password
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

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
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _isButtonEnabled = _hasMinLength &&
          _hasSymbol &&
          _hasNumber &&
          password.isNotEmpty &&
          !_isSaving;
    });
  }

  Future<void> _changePassword() async {
    if (!_isButtonEnabled) return;

    setState(() => _isSaving = true);

    try {
      final newPassword = _newPasswordController.text;

      await _authService.changePassword(newPassword);

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)
                        .tr('profile.password_changed_success'),
                    style: const TextStyle(
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

        String errorMessage =
            AppLocalizations.of(context).tr('errors.change_password_failed');

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
                          Text(
                            AppLocalizations.of(context)
                                .tr('profile.change_password'),
                            style: const TextStyle(
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.of(context)
                            .tr('profile.create_password'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.of(context)
                            .tr('profile.password_requirements'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF464646),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),



                    // New Password Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.of(context).tr('profile.new_password'),
                        style: const TextStyle(
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
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: AppLocalizations.of(context)
                                      .tr('profile.new_password_hint'),
                                  hintStyle: const TextStyle(
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
                            AppLocalizations.of(context)
                                .tr('profile.req_min_length'),
                            _hasMinLength,
                          ),
                          const SizedBox(height: 8),
                          _buildRequirement(
                            AppLocalizations.of(context)
                                .tr('profile.req_symbol'),
                            _hasSymbol,
                          ),
                          const SizedBox(height: 8),
                          _buildRequirement(
                            AppLocalizations.of(context)
                                .tr('profile.req_number'),
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
                            _isSaving
                                ? AppLocalizations.of(context)
                                    .tr('common.saving')
                                : AppLocalizations.of(context)
                                    .tr('profile.save_new_password'),
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
