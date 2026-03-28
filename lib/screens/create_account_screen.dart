import 'package:flutter/material.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'verification_screen.dart';
import 'sign_in_email_password_screen.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../i18n/app_localizations.dart';
import '../services/onboarding_service.dart';
import 'profile/terms_of_service_screen.dart';
import 'profile/privacy_policy_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  final String selectedLanguage;

  const CreateAccountScreen({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _acceptedTerms = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        // Check if profile is complete (avatar_url is set at the very last step)
        final isProfileComplete = profile != null && 
                                 profile['avatar_url'] != null && 
                                 (profile['avatar_url'] as String).isNotEmpty;

        if (isProfileComplete && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else if (mounted) {
          // If profile is incomplete, let SplashScreen handle the redirect or let user stay here if they are starting fresh
          // But usually if they have a session they should be redirected to the right step.
          // For now, if they are on this screen, we'll let them continue if profile is incomplete.
        }
      } catch (e) {
        debugPrint('Error checking profile in CreateAccount: $e');
      }
    }
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).tr('errors.invalid_email'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    // FIX: Generate password HERE so we keep it even if API fails
    final localTempPassword = 'temp-${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Pre-check: Does email exist?
      final exists = await _authService.checkEmailExists(email);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).tr('errors.account_exists')),
              backgroundColor: Colors.orange,
            ),
          );
          // Optional: Navigate to Login automatically?
          // For now, just stop specific loading state
          setState(() => _isLoading = false);
          return;
        }
      }

      // Use standard signUp logic (Password Flow) with our pre-generated password
      await _authService.signUpWithEmail(email, password: localTempPassword);

      // Save onboarding progress
      await OnboardingService().saveStep(OnboardingStep.verification);
      await OnboardingService().savePendingEmail(email);
      await OnboardingService().saveTempPassword(localTempPassword);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              email: email,
              selectedLanguage: widget.selectedLanguage,
              isSignIn: false, // This is signup flow
              tempPassword: localTempPassword,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ERROR HANDLING STRATEGY:
        // If it's a 500 error (Supabase Email Service failure) or "sending confirmation email" error,
        // we assume the account MIGHT have been created or we want to let them Try Recovery.
        // So we proceed to the Verification Screen anyway to let them hit "Resend" or "Help".

        String errorMessage =
            AppLocalizations.of(context).tr('errors.verification_failed');
        bool shouldProceedAnyway = false;

        if (e.toString().contains('500') ||
            e.toString().toLowerCase().contains('sending')) {
          errorMessage =
              'Email service is busy, but we\'re proceeding. Try "Resend" or "Help" on the next screen.';
          shouldProceedAnyway = true;
        } else if (e.toString().contains('User already registered') ||
            e.toString().contains('already registered')) {
          errorMessage =
              AppLocalizations.of(context).tr('errors.account_exists_login');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: shouldProceedAnyway ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        if (e.toString().contains('already registered') || 
            e.toString().contains('User already exists')) {
          debugPrint('AUTH_DEBUG: User already exists. Checking if current tempPassword matches...');
          
          // CRITICAL: Save the password we ARE using for this session backdoor
          await OnboardingService().saveTempPassword(localTempPassword);
          await OnboardingService().savePendingEmail(email);
          await OnboardingService().saveStep(OnboardingStep.verification);

          try {
            // Check if we can log in with the generated password
            await AuthService().signInWithPassword(email, localTempPassword);
            debugPrint('AUTH_DEBUG: Password matches existing account!');
            shouldProceedAnyway = true;
          } catch (signInErr) {
            debugPrint('AUTH_DEBUG: Password mismatch for existing account: $signInErr');
            // User exists but with a different password. 
            // We should still send OTP, but they will likely need to finish the 'Create Password'
            // step which will then call auth.updateUser (which confirmed users can do if they have a session).
            shouldProceedAnyway = true; 
          }

          // Case: User exists but might be unconfirmed. Send OTP anyway.
          try {
            await AuthService().sendCustomOtp(email);
            debugPrint('AUTH_DEBUG: Custom OTP sent to existing user.');
          } catch (otpErr) {
            debugPrint('AUTH_DEBUG: Failed to send OTP to existing user: $otpErr');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shouldProceedAnyway 
                ? 'Account already exists. Sending verification code to continue login.' 
                : 'Error: $e'),
              backgroundColor: shouldProceedAnyway ? Colors.orange : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (shouldProceedAnyway && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                email: email,
                selectedLanguage: widget.selectedLanguage,
                isSignIn: true, // Mark as sign in since they exist
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).tr('auth.create_account'),
                      style: AppTextStyles.displayText,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)
                          .tr('auth.verification_message'),
                      style: AppTextStyles.bodyText,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                      isActive: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (val) {
                              setState(() => _acceptedTerms = val ?? false);
                            },
                            activeColor: const Color(0xFF0AC5C5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context).tr('auth.i_agree_to'),
                                style: AppTextStyles.bodyText.copyWith(fontSize: 12),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                                ),
                                child: Text(
                                  ' ${AppLocalizations.of(context).tr('legal.terms_title')}',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF0AC5C5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                ' ${AppLocalizations.of(context).tr('auth.and')} ',
                                style: AppTextStyles.bodyText.copyWith(fontSize: 12),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).tr('legal.privacy_policy_title'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF0AC5C5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: _isLoading
                                ? AppLocalizations.of(context)
                                    .tr('auth.signing_up')
                                : AppLocalizations.of(context)
                                    .tr('auth.sign_up'),
                            isActive: !_isLoading && _acceptedTerms,
                            onPressed: _handleSignUp,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text:
                                AppLocalizations.of(context).tr('auth.log_in'),
                            isOutline: true,
                            isActive: !_isLoading,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SignInEmailPasswordScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
