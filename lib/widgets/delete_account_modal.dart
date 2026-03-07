import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import '../screens/splash_screen.dart';

class DeleteAccountModal extends StatefulWidget {
  const DeleteAccountModal({super.key});

  @override
  State<DeleteAccountModal> createState() => _DeleteAccountModalState();
}

class _DeleteAccountModalState extends State<DeleteAccountModal> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 50,
              color: Color(0xFFFB3748),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).tr('dialogs.delete_account_title'),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)
                  .tr('dialogs.delete_account_description'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Color(0xFF363636),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFFFB3748))
            else
              Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (mounted) setState(() => _isLoading = true);
                      try {
                        await DatabaseService().deleteAccount();
                        // Also sign out locally just in case
                        await AuthService().signOut();

                        if (mounted) {
                          Navigator.pop(context); // Close dialog
                          // Navigate to splash screen and remove all previous routes
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        debugPrint('Error deleting account: $e');
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(AppLocalizations.of(context)
                                    .tr('errors.generic'))),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB3748),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)
                            .tr('dialogs.confirm_delete'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context).tr('dialogs.cancel'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF737373),
                          fontSize: 16,
                        ),
                      ),
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
