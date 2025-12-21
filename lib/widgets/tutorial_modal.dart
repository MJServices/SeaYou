import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';

/// Tutorial Modal - Understanding SeaYou
/// Shows after registration and accessible from Settings
class TutorialModal extends StatelessWidget {
  const TutorialModal({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 12, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0AC5C5), Color(0xFF08A0A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr.tr('tutorial.welcome.title'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Text(
                      tr.tr('tutorial.welcome.subtitle'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0AC5C5),
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Line 1
                    Text(
                      tr.tr('tutorial.welcome.line1'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2D2D2D),
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Line 2
                    Text(
                      tr.tr('tutorial.welcome.line2'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2D2D2D),
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Line 3
                    Text(
                      tr.tr('tutorial.welcome.line3'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2D2D2D),
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Line 4
                    Text(
                      tr.tr('tutorial.welcome.line4'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2D2D2D),
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // CTA
                    Center(
                      child: Text(
                        tr.tr('tutorial.welcome.cta'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0AC5C5),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0AC5C5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    tr.tr('common.ok'),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the tutorial modal
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TutorialModal(),
    );
  }
}
