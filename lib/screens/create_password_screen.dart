import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'profile_info_screen.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

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
    _checkRedirect();
    _passwordController.addListener(_validatePassword);
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create your password',
                      style: AppTextStyles.displayText,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your password must be at least 8 characters long and contain one symbol and number',
                      style: AppTextStyles.bodyText,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      hintText: 'Enter password',
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
                    _buildRequirement('Minimum of 8 characters', hasMinLength),
                    const SizedBox(height: 8),
                    _buildRequirement('At least a symbol', hasSymbol),
                    const SizedBox(height: 8),
                    _buildRequirement('At least a number', hasNumber),
                    const SizedBox(height: 300),
                    CustomButton(
                      text: 'Create Password',
                      isActive: isPasswordValid,
                      onPressed: () async {
                        try {
                          // Check if we need to re-authenticate with temp password
                          if (AuthService().currentUser == null && widget.tempPassword != null) {
                            print('AUTH_DEBUG: Session missing, re-authenticating with temp password...');
                            await AuthService().signInWithPassword(widget.email, widget.tempPassword!);
                          }

                          await AuthService().updatePassword(_passwordController.text);
                          if (context.mounted) {
                            if (widget.isRecovery) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                                (route) => false,
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileInfoScreen(
                                    email: widget.email,
                                    selectedLanguage: widget.selectedLanguage,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
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

  Widget _buildRequirement(String text, bool isMet) {
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
