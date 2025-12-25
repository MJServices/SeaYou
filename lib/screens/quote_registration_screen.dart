import 'package:flutter/material.dart';
import '../utils/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/custom_button.dart';
import '../models/user_profile.dart';
import 'upload_picture_screen.dart';
import '../widgets/coachmark_bubble.dart';
import '../services/tutorial_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class QuoteRegistrationScreen extends StatefulWidget {
  final UserProfile userProfile;
  const QuoteRegistrationScreen({super.key, required this.userProfile});

  @override
  State<QuoteRegistrationScreen> createState() => _QuoteRegistrationScreenState();
}

class _QuoteRegistrationScreenState extends State<QuoteRegistrationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _showTip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await TutorialService().hasSeenQuoteTip();
      if (!seen && mounted) setState(() => _showTip = true);
      final user = AuthService().currentUser;
      if (user != null) {
        final prefs = await DatabaseService().getUserPreferences(user.id);
        final existing = prefs?['secret_quote'] as String?;
        if (existing != null && existing.isNotEmpty && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UploadPictureScreen(userProfile: widget.userProfile),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _controller.text.trim().isNotEmpty;
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(children: [
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
                    const Text('Secret Quote', style: AppTextStyles.displayText),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('1/2', style: AppTextStyles.bodyText),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write a short secret quote',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(8))),
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
                  onPressed: canProceed
                        ? () {
                          final user = AuthService().currentUser;
                          final quote = _controller.text.trim();
                          
                          if (user != null) {
                            DatabaseService().upsertUserPreferences(
                              userId: user.id,
                              secretQuote: quote,
                            );
                          }
                          
                          // Update profile object for next steps
                          widget.userProfile.secretDesire = quote;
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UploadPictureScreen(userProfile: widget.userProfile),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
          ),
          if (_showTip)
            Positioned(
              left: 0,
              right: 0,
              top: 8,
              child: CoachmarkBubble(
                title: 'Secret Quote',
                message: 'Write a short quote only you know.',
                ctaText: 'Got it',
                onCta: () async {
                  setState(() => _showTip = false);
                  await TutorialService().setSeenQuoteTip();
                },
                onClose: () async {
                  setState(() => _showTip = false);
                  await TutorialService().setSeenQuoteTip();
                },
              ),
            ),
        ]),
      ),
    );
  }
}
