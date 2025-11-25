import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../services/auth_service.dart';
import 'verification_screen.dart';

class SignInEmailPasswordScreen extends StatefulWidget {
  const SignInEmailPasswordScreen({super.key});

  @override
  State<SignInEmailPasswordScreen> createState() => _SignInEmailPasswordScreenState();
}

class _SignInEmailPasswordScreenState extends State<SignInEmailPasswordScreen> {
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

  Future<void> _handleSignIn() async {
    if (!isFormValid) return;

    setState(() {
      isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      print('Checking if email exists and sending OTP to: $email');

      // Check if email exists and send OTP
      await _authService.signInWithEmailOtp(email);

      if (!mounted) return;

      print('OTP sent successfully, navigating to verification');

      // Navigate to verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            email: email,
            selectedLanguage: null, // No language selection for sign-in
            isSignIn: true, // This is a sign-in flow
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      print('Sign in error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Handle specific error messages
      String errorMessage = 'An error occurred. Please try again.';
      
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('user not found') || 
          errorString.contains('no user found')) {
        errorMessage = 'No account found with this email. Please sign up first.';
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
              Padding(
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
                        color: isLoading ? AppColors.black.withOpacity(0.3) : AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Sign In',
                      style: AppTextStyles.displayText,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email to receive a verification code',
                      style: AppTextStyles.bodyText,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      hintText: 'Email',
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
                    CustomButton(
                      text: isLoading ? 'Sending Code...' : 'Continue',
                      isActive: isFormValid && !isLoading,
                      onPressed: _handleSignIn,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
