import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'create_account_screen.dart';
import '../services/localization_service.dart';
import '../i18n/app_localizations.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? selectedLanguage;

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
              _buildLanguageOption(
                  'English (device\'s language)', true, const Locale('en')),
              _buildLanguageOption('French', false, const Locale('fr')),
              _buildLanguageOption('German', false, const Locale('de')),
              _buildLanguageOption('Spanish', false, const Locale('es')),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: 'Continue',
                  isActive: selectedLanguage != null,
                  onPressed: () async {
                    if (selectedLanguage != null) {
                      final ctx = context;
                      // Persist selected locale
                      final map = {
                        'English (device\'s language)': const Locale('en'),
                        'French': const Locale('fr'),
                        'German': const Locale('de'),
                        'Spanish': const Locale('es'),
                      };
                      final l = map[selectedLanguage!] ?? const Locale('en');
                      await LocalizationService.instance.setLocale(l);
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
