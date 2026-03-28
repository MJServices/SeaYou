import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'create_account_screen.dart';
import '../services/localization_service.dart';
import '../i18n/app_localizations.dart';
import '../services/onboarding_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Small delay to ensure navigator is ready if needed,
    // though initState is usually fine for pushReplacement
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Error checking profile in LanguageSelection: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  AppLocalizations.of(context).tr('common.select_language'),
                  style: AppTextStyles.displayText,
                ),
              ),
              const SizedBox(height: 32),
              _buildLanguageOption('English', true, const Locale('en')),
              _buildLanguageOption('French', false, const Locale('fr')),
              _buildLanguageOption('German', false, const Locale('de')),
              _buildLanguageOption('Spanish', false, const Locale('es')),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: AppLocalizations.of(context).tr('common.continue'),
                  isActive: selectedLanguage != null,
                  onPressed: () async {
                    if (selectedLanguage != null) {
                      final ctx = context;
                      // Persist selected locale
                      final map = {
                        'English': const Locale('en'),
                        'French': const Locale('fr'),
                        'German': const Locale('de'),
                        'Spanish': const Locale('es'),
                      };
                      final l = map[selectedLanguage!] ?? const Locale('en');
                      await LocalizationService.instance.setLocale(l);
                      await OnboardingService().saveStep(OnboardingStep.createAccount);
                      if (!ctx.mounted) return;
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (context) => CreateAccountScreen(
                            selectedLanguage: selectedLanguage!,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isDefault, Locale locale) {
    final isSelected = selectedLanguage == language;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLanguage = language;
          LocalizationService.instance.setLocale(locale);
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              language,
              style: AppTextStyles.labelText.copyWith(
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
