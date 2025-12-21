import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'verification_screen.dart';
import 'sign_in_email_password_screen.dart';
import '../services/auth_service.dart';

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

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // FIX: Generate password HERE so we keep it even if API fails
    final localTempPassword = "temp-${DateTime.now().millisecondsSinceEpoch}";

    try {
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
        
        String errorMessage = 'Failed to send verification code. Please try again.';
        bool shouldProceedAnyway = false;

        if (e.toString().contains('500') || e.toString().toLowerCase().contains('sending')) {
             errorMessage = 'Email service is busy, but we\'re proceeding. Try "Resend" or "Help" on the next screen.';
             shouldProceedAnyway = true;
        } else if (e.toString().contains('User already registered') || e.toString().contains('already registered')) {
            errorMessage = 'An account with this email already exists. Please log in.';
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
                const Text(
                  'Create an account',
                  style: AppTextStyles.displayText,
                ),
                const SizedBox(height: 16),
                const Text(
                  'A verification code will be sent right away to validate your email address',
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
                        text: _isLoading ? 'Signing up...' : 'Sign up for free',
                        isActive: !_isLoading,
                        onPressed: _handleSignUp,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'Log in',
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
                 const Text(
                  'By clicking continue, you accept the terms of service and privacy policy',
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
