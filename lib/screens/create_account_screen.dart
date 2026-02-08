import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
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

        if (profile != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
          );
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
        SnackBar(content: Text(AppLocalizations.of(context).tr('errors.invalid_email'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    // FIX: Generate password HERE so we keep it even if API fails
    final localTempPassword = "temp-${DateTime.now().millisecondsSinceEpoch}";

    try {
      // Pre-check: Does email exist?
      final exists = await _authService.checkEmailExists(email);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).tr('errors.account_exists')),
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
        
        String errorMessage = AppLocalizations.of(context).tr('errors.verification_failed');
        bool shouldProceedAnyway = false;

        if (e.toString().contains('500') || e.toString().toLowerCase().contains('sending')) {
             errorMessage = 'Email service is busy, but we\'re proceeding. Try "Resend" or "Help" on the next screen.';
             shouldProceedAnyway = true;
        } else if (e.toString().contains('User already registered') || e.toString().contains('already registered')) {
            errorMessage = AppLocalizations.of(context).tr('errors.account_exists_login');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: shouldProceedAnyway ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        if (shouldProceedAnyway && mounted) {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                email: email,
                selectedLanguage: widget.selectedLanguage,
                isSignIn: false,
                tempPassword: localTempPassword, // PASS THE KEY EVEN ON FAILURE
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  AppLocalizations.of(context).tr('auth.verification_message'),
                  style: AppTextStyles.bodyText,
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: _emailController,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  isActive: !_isLoading, 
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: _isLoading ? AppLocalizations.of(context).tr('auth.signing_up') : AppLocalizations.of(context).tr('auth.sign_up'),
                        isActive: !_isLoading,
                        onPressed: _handleSignUp,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: AppLocalizations.of(context).tr('auth.log_in'),
                        isOutline: true,
                        isActive: !_isLoading,
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInEmailPasswordScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                 Text(
                  AppLocalizations.of(context).tr('auth.terms_message'),
                  style: AppTextStyles.labelText,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 160),
              ],
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
