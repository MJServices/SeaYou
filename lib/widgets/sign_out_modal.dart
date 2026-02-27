import 'package:flutter/material.dart';
import 'custom_button.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';
import '../screens/splash_screen.dart';
import '../i18n/app_localizations.dart';

/// Sign Out Modal - Confirmation dialog for signing out
class SignOutModal extends StatelessWidget {
  const SignOutModal({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Log out icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0AC5C5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.exit_to_app,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Title and description
            Column(
              children: [
                Text(
                  l10n.tr('dialogs.logout_title'),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tr('dialogs.logout_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF151515),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        foregroundColor: const Color(0xFF737373),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        l10n.tr('dialogs.close'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF737373),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: l10n.tr('dialogs.confirm'),
                      isActive: true,
                      onPressed: () async {
                        // Clear all tutorial flags so they show again for new accounts
                        await TutorialService().clearAllTutorials();
                        
                        // Sign out logic
                        await AuthService().signOut();
                        
                        if (context.mounted) {
                          // Navigate to splash screen and remove all previous routes
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

