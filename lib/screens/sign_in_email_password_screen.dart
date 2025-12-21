import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../services/auth_service.dart';
import 'verification_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
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
        emailError = 'Please enter a valid email';
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;

      print('Sign in error: $e');
      print('Error type: ${e.runtimeType}');

      // Handle specific error messages
      String errorMessage = 'An error occurred. Please try again.';

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('user not found') ||
          errorString.contains('no user found')) {
        errorMessage =
            'No account found with this email. Please sign up first.';
      } else if (errorString.contains('rate limit')) {
        errorMessage = 'Too many attempts. Please try again later.';
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
        title: const Text('Sign In Failed'),
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
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      hintText:
                          AppLocalizations.of(context).tr('auth.password'),
                      controller: _passwordController,
                      isActive: !isLoading,
                      obscureText: _obscureText,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
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
