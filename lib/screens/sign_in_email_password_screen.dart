import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../services/auth_service.dart';
import 'verification_screen.dart';
import 'forgot_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/onboarding_service.dart';
import '../i18n/app_localizations.dart';

class SignInEmailPasswordScreen extends StatefulWidget {
  const SignInEmailPasswordScreen({super.key});

  @override
  State<SignInEmailPasswordScreen> createState() =>
      _SignInEmailPasswordScreenState();
}

class _SignInEmailPasswordScreenState extends State<SignInEmailPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isFormValid = false;
  bool isLoading = false;
  String? emailError;
  bool usePassword = true;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      // Email validation
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        emailError = null;
      } else if (!email.contains('@')) {
        emailError = 'Email must contain @';
      } else if (!email.contains('.')) {
        emailError = 'Email must contain a domain';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        emailError = AppLocalizations.of(context).tr('errors.invalid_email');
      } else {
        emailError = null;
      }

      // Form is valid if email is filled and has no errors; password required when usePassword
      if (usePassword) {
        isFormValid = email.isNotEmpty &&
            emailError == null &&
            _passwordController.text.isNotEmpty;
      } else {
        isFormValid = email.isNotEmpty && emailError == null;
      }
    });
  }

  Future<void> _handleSignIn() async {
    if (!isFormValid) return;

    setState(() {
      isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      if (usePassword) {
        await _authService.signInWithPassword(email, _passwordController.text);
      } else {
        await _authService.signInWithEmailOtp(email);
      }

      if (!mounted) return;

      if (!usePassword) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              email: email,
              selectedLanguage: null,
              isSignIn: true,
            ),
          ),
        );
      } else {
        // After password sign in, check if profile is complete
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = await DatabaseService().getProfile(user.id);
          if (!mounted) return;

          await OnboardingService().resumeOnboarding(context, profile);
        }
      }
    } catch (e) {
      if (!mounted) return;

      print('Sign in error: $e');
      print('Error type: ${e.runtimeType}');

      // Handle specific error messages
      String errorMessage = AppLocalizations.of(context).tr('errors.generic');

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('user not found') ||
          errorString.contains('no user found')) {
        errorMessage = AppLocalizations.of(context).tr('errors.no_account');
      } else if (errorString.contains('invalid login credentials') ||
                 errorString.contains('invalid_credentials') ||
                 errorString.contains('400')) {
        // Map the common authentication failure to a friendly message
        final localizedMsg = AppLocalizations.of(context).tr('messages.sign_in_failed_message');
        errorMessage = (localizedMsg != 'messages.sign_in_failed_message') 
                       ? localizedMsg 
                       : 'Invalid login credentials. Please check your email and password.';
      } else if (errorString.contains('rate limit')) {
        errorMessage =
            AppLocalizations.of(context).tr('errors.too_many_attempts');
      } else {
        // Show the actual error for debugging
        errorMessage = 'Error: $e';
      }

      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context).tr('messages.sign_in_failed_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Back button
                    GestureDetector(
                      onTap: isLoading ? null : () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: isLoading
                            ? AppColors.black.withValues(alpha: 0.3)
                            : AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(AppLocalizations.of(context).tr('auth.sign_in_title'),
                        style: AppTextStyles.displayText),
                    const SizedBox(height: 16),
                    // Only password login for returning users
                    const SizedBox(height: 16),
                    Text(
                        AppLocalizations.of(context)
                            .tr('auth.sign_in_password_description'),
                        style: AppTextStyles.bodyText),
                    const SizedBox(height: 32),
                    CustomTextField(
                      hintText: AppLocalizations.of(context).tr('auth.email'),
                      controller: _emailController,
                      isActive: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      hintText:
                          AppLocalizations.of(context).tr('auth.password'),
                      controller: _passwordController,
                      isActive: !isLoading,
                      obscureText: _obscureText,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSignIn(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        child: Text(AppLocalizations.of(context)
                            .tr('auth.forgot_password')),
                      ),
                    ),
                    if (emailError != null && _emailController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          emailError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: isLoading
                          ? AppLocalizations.of(context).tr('auth.continue')
                          : AppLocalizations.of(context).tr('auth.continue'),
                      isActive: isFormValid && !isLoading,
                      onPressed: _handleSignIn,
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom == 0
                            ? 32
                            : MediaQuery.of(context).viewInsets.bottom),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
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
