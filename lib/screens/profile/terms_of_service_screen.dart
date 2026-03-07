import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../i18n/app_localizations.dart';

/// Terms of Service Screen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFEFAEE),
        ),
        child: Stack(
          children: [
            // Content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF151515),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          AppLocalizations.of(context).tr('legal.terms_title'),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF151515),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppLocalizations.of(context).tr('legal.terms_content'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
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
