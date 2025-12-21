import 'package:flutter/material.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verification_screen.dart';
import '../i18n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    final emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: WarmGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).tr('auth.recover_title'), style: AppTextStyles.displayText),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).tr('auth.recover_description'), style: AppTextStyles.bodyText),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: AppLocalizations.of(context).tr('auth.email'),
                  controller: _emailController,
                  isActive: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                ),
                if (email.isNotEmpty && !emailValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      AppLocalizations.of(context).tr('error.invalid_email'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 24),
                CustomButton(
                  text: isLoading ? AppLocalizations.of(context).tr('auth.continue') : AppLocalizations.of(context).tr('auth.continue'),
                  isActive: emailValid && !isLoading,
                  onPressed: isLoading ? null : () async {
                    final ctx = context;
                    setState(() => isLoading = true);
                    try {
                      // Send OTP for recovery via sign-in OTP (no browser redirect)
                      await Supabase.instance.client.auth.signInWithOtp(
                        email: _emailController.text.trim(),
                        shouldCreateUser: false,
                      );
                      if (!ctx.mounted) return;
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (context) => VerificationScreen(
                            email: _emailController.text.trim(),
                            selectedLanguage: null,
                            isSignIn: true,
                            isRecovery: true,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(ctx).tr('error.generic')}: $e')));
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  },
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom == 0 ? 24 : MediaQuery.of(context).viewInsets.bottom),
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
