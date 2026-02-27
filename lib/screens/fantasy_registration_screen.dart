import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import '../models/user_profile.dart';


class FantasyRegistrationScreen extends StatefulWidget {
  final UserProfile userProfile;
  const FantasyRegistrationScreen({super.key, required this.userProfile});

  @override
  State<FantasyRegistrationScreen> createState() => _FantasyRegistrationScreenState();
}

class _FantasyRegistrationScreenState extends State<FantasyRegistrationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkRedirect();
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

  Future<void> _next() async {
    setState(() => _saving = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        await DatabaseService().createFantasy(user.id, _controller.text.trim());
      }
      if (!mounted) return;

      debugPrint('✅ Saving full profile to database...');
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        final int currentYear = DateTime.now().year;
        final int age = widget.userProfile.age ?? 0;
        final int birthYear = currentYear - age;
        widget.userProfile.birthYear = birthYear;

        await DatabaseService().createProfile(
          userId: userId,
          email: widget.userProfile.email ?? '',
          fullName: widget.userProfile.fullName ?? '',
          age: age,
          birthYear: birthYear,
          city: widget.userProfile.city ?? '',
          about: widget.userProfile.about ?? '',
          sexualOrientation: widget.userProfile.sexualOrientation ?? [],
          showOrientation: widget.userProfile.showOrientation,
          expectation: widget.userProfile.expectation ?? '',
          interestedIn: widget.userProfile.interestedIn ?? '',
          interests: widget.userProfile.interests ?? [],
          avatarUrl: widget.userProfile.avatarUrl,
          language: widget.userProfile.language,
          secretDesire: widget.userProfile.secretDesire,
          secretQuote: widget.userProfile.secretQuote,
          secretAudioUrl: widget.userProfile.secretAudioUrl,
          gender: widget.userProfile.gender,
          department: widget.userProfile.department,
        );
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
