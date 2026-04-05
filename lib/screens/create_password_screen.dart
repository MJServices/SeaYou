import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../i18n/app_localizations.dart';
import '../services/onboarding_service.dart';

class CreatePasswordScreen extends StatefulWidget {
  final String email;
  final String? selectedLanguage;
  final bool isRecovery;

  const CreatePasswordScreen({
    super.key,
    required this.email,
    this.selectedLanguage,
    this.isRecovery = false,
    this.tempPassword,
  });

  final String? tempPassword;

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool hasMinLength = false;
  bool hasSymbol = false;
  bool hasNumber = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }


  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      hasMinLength = password.length >= 8;
      hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  bool get isPasswordValid => hasMinLength && hasSymbol && hasNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                            .tr('auth.create_password_title'),
                        style: AppTextStyles.displayText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                            .tr('auth.password_requirement_subtitle'),
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        hintText: AppLocalizations.of(context)
                            .tr('auth.enter_password_placeholder'),
                        controller: _passwordController,
                        isActive: _passwordController.text.isNotEmpty,
                        obscureText: _obscureText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRequirement(
                          context,
                          AppLocalizations.of(context)
                              .tr('auth.min_characters'),
                          hasMinLength),
                      const SizedBox(height: 8),
                      _buildRequirement(
                          context,
                          AppLocalizations.of(context)
                              .tr('auth.at_least_symbol'),
                          hasSymbol),
                      const SizedBox(height: 8),
                      _buildRequirement(
                          context,
                          AppLocalizations.of(context)
                              .tr('auth.at_least_number'),
                          hasNumber),
                      const SizedBox(height: 300),
                      CustomButton(
                        text: AppLocalizations.of(context)
                            .tr('auth.create_password_button'),
                        isActive: isPasswordValid,
                        onPressed: () async {
                          try {
                            debugPrint('AUTH_DEBUG: Create Password button pressed.');
                            
                            User? currentUser = AuthService().currentUser;
                            debugPrint('AUTH_DEBUG: Initial currentUser: ${currentUser?.id}');
                            
                            // FAIL-SAFE: Retry and Silent Re-Login
                            int retryCount = 0;
                            while (currentUser == null && retryCount < 3) {
                              debugPrint('AUTH_DEBUG: Session missing. Attempting recovery (Attempt #${retryCount + 1})...');
                              
                              // 1. Try Refresh
                              try {
                                final refreshRes = await Supabase.instance.client.auth.refreshSession();
                                currentUser = refreshRes.user;
                                if (currentUser != null) debugPrint('AUTH_DEBUG: refreshSession SUCCESS.');
                              } catch (e) {
                                debugPrint('AUTH_DEBUG: refreshSession error: $e');
                              }

                              // 2. Try Disk Session
                              if (currentUser == null) {
                                final session = Supabase.instance.client.auth.currentSession;
                                currentUser = session?.user;
                                if (currentUser != null) debugPrint('AUTH_DEBUG: disk session check SUCCESS.');
                              }

                              // 3. SILENT RE-LOGIN (The "Backdoor")
                              if (currentUser == null) {
                                debugPrint('AUTH_DEBUG: Attempting silent re-login with tempPassword...');
                                final tempStored = await OnboardingService().getTempPassword();
                                if (tempStored != null) {
                                  try {
                                    final authRes = await AuthService().signInWithPassword(widget.email, tempStored);
                                    currentUser = authRes.user;
                                    debugPrint('AUTH_DEBUG: SILENT RE-LOGIN SUCCESS! (via tempPassword)');
                                  } catch (e) {
                                    debugPrint('AUTH_DEBUG: Silent re-login failed: $e');
                                  }
                                } else {
                                  debugPrint('AUTH_DEBUG: No tempPassword found in storage.');
                                }
                              }
                              
                              if (currentUser == null) {
                                await Future.delayed(const Duration(seconds: 1));
                              }
                              retryCount++;
                            }

                            if (currentUser == null) {
                              debugPrint('AUTH_DEBUG: CRITICAL: All session recovery attempts failed.');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unable to verify your session for ${widget.email}. Please go back and re-verify your email.'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 8),
                                  ),
                                );
                              }
                              return;
                            }

                            debugPrint('AUTH_DEBUG: Updating password for: ${currentUser.email}');
                            await AuthService().updatePassword(_passwordController.text);
                            
                            if (!mounted) return;
                            debugPrint('AUTH_DEBUG: Password updated successfully.');

                            if (mounted) {
                              // Standardize Flow: Recovery users bypass assessment (GOTO Home), New users GOTO Profile Assessment
                              final OnboardingStep? nextForced = widget.isRecovery ? OnboardingStep.completed : OnboardingStep.profileInfo;
                              
                              if (widget.isRecovery) {
                                await OnboardingService().clearAll(); // Clear any pending signup state
                              } else {
                                await OnboardingService().saveStep(OnboardingStep.profileInfo);
                              }

                              final profile = await DatabaseService().getProfile(currentUser.id);

                              await OnboardingService().resumeOnboarding(
                                context, 
                                profile,
                                currentStep: OnboardingStep.createPassword,
                                forcedStep: nextForced,
                                user: currentUser,
                              );
                            }
                          } catch (e) {
                            debugPrint('AUTH_DEBUG: Password update failed: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to set password: $e\n(Account: ${widget.email})'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(BuildContext context, String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          color: isMet ? AppColors.primary : AppColors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.bodyText.copyWith(
            color: isMet ? AppColors.black : AppColors.grey,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
