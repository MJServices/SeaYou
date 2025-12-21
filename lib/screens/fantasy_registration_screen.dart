import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import '../models/user_profile.dart';
import 'account_setup_done_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../i18n/app_localizations.dart';

class FantasyRegistrationScreen extends StatefulWidget {
  final UserProfile userProfile;
  const FantasyRegistrationScreen({super.key, required this.userProfile});

  @override
  State<FantasyRegistrationScreen> createState() => _FantasyRegistrationScreenState();
}

class _FantasyRegistrationScreenState extends State<FantasyRegistrationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  Future<void> _next() async {
    setState(() => _saving = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        await DatabaseService().createFantasy(user.id, _controller.text.trim());
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AccountSetupDoneScreen(userProfile: widget.userProfile),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final text = _controller.text.trim();
    final canProceed = text.length >= 10; // basic validation
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          tr.tr('chamber.title'),
                          style: AppTextStyles.displayText,
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '5/6',
                        style: AppTextStyles.bodyText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: tr.tr('chamber.write_placeholder'),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomButton(
                      text: 'Next',
                      isActive: canProceed,
                      onPressed: canProceed && !_saving ? _next : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
