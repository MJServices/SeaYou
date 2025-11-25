import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'verification_screen.dart';
import 'sign_in_options_screen.dart';
import '../services/auth_service.dart';

class CreateAccountScreen extends StatefulWidget {
  final String selectedLanguage;
  
  const CreateAccountScreen({super.key, required this.selectedLanguage});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool isFormValid = false;
  bool isLoading = false;
  String? emailError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
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

      // Form is valid if email is filled and has no errors
      isFormValid = email.isNotEmpty && emailError == null;
    });
  }

  Future<void> _handleSignUp() async {
    if (!isFormValid) return;

    setState(() {
      isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      print('Checking if email already exists: $email');

      // Check if email already exists
      final emailExists = await _authService.checkEmailExists(email);
      
      if (emailExists) {
        if (!mounted) return;
        print('❌ Email already exists: $email');
        _showErrorDialog('An account with this email already exists. Please sign in instead.');
        return;
      }

      print('✅ Email is available, sending OTP for sign up to: $email');

      // Send OTP for sign up
      await _authService.signUpWithEmail(email);

      if (!mounted) return;

      print('✅ OTP sent successfully, navigating to verification');

      // Navigate to verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            email: email,
            selectedLanguage: widget.selectedLanguage,
            isSignIn: false, // This is a sign-up flow
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      print('❌ Sign up error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Handle specific error messages
      String errorMessage = 'An error occurred. Please try again.';
      
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('user already registered') || 
          errorString.contains('already exists')) {
        errorMessage = 'An account with this email already exists. Please sign in instead.';
      } else if (errorString.contains('rate limit')) {
        errorMessage = 'Too many attempts. Please try again later.';
      } else if (errorString.contains('invalid email')) {
        errorMessage = 'Please enter a valid email address.';
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
        title: const Text('Sign Up Failed'),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                hintText: 'e.g alexjohn@gmail.com',
                                controller: _emailController,
                                isActive: !isLoading,
                                keyboardType: TextInputType.emailAddress,
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
                              const Spacer(),
                              Text(
                                'By clicking continue, you accept the terms of service and privacy policy',
                                style: AppTextStyles.labelText.copyWith(
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              CustomButton(
                                text: isLoading ? 'Sending Code...' : 'Send verification code',
                                isActive: isFormValid && !isLoading,
                                onPressed: _handleSignUp,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: isLoading ? null : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SignInOptionsScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Already a member? Sign in',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: isLoading ? AppColors.black.withOpacity(0.3) : AppColors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.1),
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
