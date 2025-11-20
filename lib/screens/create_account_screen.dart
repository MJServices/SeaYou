import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'verification_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {
        isEmailValid = _emailController.text.contains('@') &&
            _emailController.text.contains('.');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
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
                            isActive: isEmailValid,
                            keyboardType: TextInputType.emailAddress,
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
                            text: 'Send verification code',
                            isActive: isEmailValid,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VerificationScreen(
                                    email: _emailController.text,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                // Navigate to sign in
                              },
                              child: const Text(
                                'Already a member? Sign in',
                                style: AppTextStyles.bodyText,
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
