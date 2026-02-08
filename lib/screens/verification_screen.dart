import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'create_password_screen.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n/app_localizations.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String? selectedLanguage;
  final bool isSignIn; // true for sign-in, false for sign-up
  final bool isRecovery; // true for password recovery OTP
  final bool isEmailChange; 
  final String? tempPassword;

  const VerificationScreen({
    super.key,
    required this.email,
    this.selectedLanguage,
    this.isSignIn = true,
    this.isRecovery = false,
    this.isEmailChange = false,
    this.tempPassword,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Flexible OTP input
  final TextEditingController _otpController = TextEditingController();
  
  int _resendCountdown = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRedirect();
    print('AUTH_DEBUG: VerificationScreen initialized. Email: ${widget.email}, isSignIn: ${widget.isSignIn}, isRecovery: ${widget.isRecovery}');
    _startCountdown();
  }

  Future<void> _checkRedirect() async {
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

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }

    });
  }



  Future<void> _resendOtp() async {
    try {
      print('AUTH_DEBUG: Resend OTP requested.');
      print('AUTH_DEBUG: Resend OTP requested.');
      // ALWAYS use Custom OTP (Resend) as requested by user
      print('AUTH_DEBUG: Resending Custom OTP via Resend for all flows.');
      await AuthService().sendCustomOtp(widget.email);
      
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      print('AUTH_DEBUG: Standard resend failed ($e). Attempting auto-fallback to Recovery Link.');
      
      try {
          // AUTO-FALLBACK: Try sending a Recovery Link instead
          await AuthService().resetPasswordForEmail(widget.email);
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Standard delivery failed. Sent a Recovery Link instead! Check email.'),
                backgroundColor: Colors.orange,
              ),
            );
            _startCountdown(); // Start countdown as if it succeeded
          }
      } catch (fallbackError) {
          if (mounted) {
            String errorMessage = 'Failed to resend code: $e';
            if (e.toString().contains('500')) {
                errorMessage = AppLocalizations.of(context).tr('errors.delivery_failed');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Enter verification code',
                            style: AppTextStyles.displayText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'A verification code has be sent to ${widget.email}',
                            style: AppTextStyles.bodyText,
                          ),
                          const SizedBox(height: 32),
                          CustomTextField(
                            controller: _otpController,
                            hintText: 'Enter Code',
                            keyboardType: TextInputType.text,
                            isActive: !_isLoading,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _resendCountdown > 0
                                    ? 'Resend code in 00:${_resendCountdown.toString().padLeft(2, '0')}'
                                    : 'Didn\'t receive the code?',
                                style: AppTextStyles.bodyText,
                              ),
                              if (_resendCountdown == 0) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _resendOtp,
                                  child: Text(
                                    'Resend',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: _showHelpDialog,
                              child: Text(
                                'Trouble receiving code?',
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          


                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomButton(
                      text: _isLoading ? 'Verifying...' : 'Confirm & Verify',
                      isActive: _isCodeComplete() && !_isLoading,
                      onPressed: () async {
                        print('AUTH_DEBUG: Verify button pressed.');
                        setState(() => _isLoading = true);
                        final code = _otpController.text.trim();
                        print('AUTH_DEBUG: Code collected: $code');
                        
                        try {
                          print('AUTH_DEBUG: Calling verifyCustomOtp...');
                          // Verify the OTP code - this MUST succeed for user to proceed
                          await AuthService().verifyCustomOtp(widget.email, code);
                          print('AUTH_DEBUG: verifyCustomOtp returned success.');                          
                          // SUCCESS NAVIGATION
                          if (context.mounted) {
                            if (widget.isEmailChange) {
                              Navigator.pop(context, true);
                              return;
                            }
                            
                            if (widget.isSignIn) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                                (route) => false,
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreatePasswordScreen(
                                    email: widget.email,
                                    selectedLanguage: widget.selectedLanguage,
                                    isRecovery: widget.isRecovery,
                                    tempPassword: widget.tempPassword, // PASS TEMP PASSWORD
                                  ),
                                ),
                              );
                            }
                          }

                        } catch (e) {
                          if (context.mounted) {
                            String errorMessage = AppLocalizations.of(context).tr('errors.invalid_code');
                            if (e.toString().contains('expired')) {
                              errorMessage = AppLocalizations.of(context).tr('errors.code_expired');
                            } else if (e.toString().contains('invalid')) {
                              errorMessage = AppLocalizations.of(context).tr('errors.invalid_code_check');
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
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
  


  Future<void> _showHelpDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Help?'),
        content: const Text(
          'If you are not receiving the verification code, you can try sending a Password Recovery link instead (which uses a different email system), or try a different email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).tr('dialogs.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to change email
            },
            child: const Text('Change Email'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
               try {
                await AuthService().resetPasswordForEmail(widget.email);
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery link sent! Check your email.')),
                  );
                }
               } catch (e) {
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                 }
               } finally {
                 if (mounted) setState(() => _isLoading = false);
               }
            },
            child: const Text('Send Recovery Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  bool _isCodeComplete() {
    return _otpController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
