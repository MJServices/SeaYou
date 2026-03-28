import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'language_selection_screen.dart';
import 'home_screen.dart';
import '../services/audio_service.dart';
import '../i18n/app_localizations.dart';
import '../services/onboarding_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;
  VoidCallback? _muteListener;

  @override
  void initState() {
    super.initState();

    // Check if user is already logged in
    _checkAuthAndNavigate();

    _controller = VideoPlayerController.asset('assets/videos/onboarding.mp4')
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          // Start unmuted by default (GlobalAudioController.muted starts as false)
          _controller.setVolume(1.0);
          _controller.play();
        }
      });

    // Listen for global mute changes and update video volume
    _muteListener = () {
      final isMuted = GlobalAudioController.instance.muted.value;
      _controller.setVolume(isMuted ? 0.0 : 1.0);
    };
    GlobalAudioController.instance.muted.addListener(_muteListener!);
  }

  Future<void> _checkAuthAndNavigate() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (mounted) {
      if (session != null) {
        // Authenticated user
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', session.user.id)
              .maybeSingle();

          if (mounted) {
            await OnboardingService().resumeOnboarding(context, profile);
          }
        } catch (e) {
          debugPrint('Error checking profile: $e');
          if (mounted) {
            final step = await OnboardingService().getStep();
            await OnboardingService().navigateToStep(context, step);
          }
        }
      } else {
        // Not authenticated, check if we were in the middle of signup
        final step = await OnboardingService().getStep();
        if (step != OnboardingStep.languageSelection && mounted) {
          await OnboardingService().navigateToStep(context, step);
        }
      }
    }
  }

  void _handleBackgroundTap() {
    print('🎵 Screen tapped - toggling mute');
    GlobalAudioController.instance.toggleMute();
  }

  @override
  void dispose() {
    if (_muteListener != null) {
      GlobalAudioController.instance.muted.removeListener(_muteListener!);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Prevent white background showing
      body: Stack(
        children: [
          // Fullscreen video background
          Positioned.fill(
            child: _isVideoInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // Tap-to-mute detector (Background area only)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleBackgroundTap,
            ),
          ),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content Layer
          SafeArea(
            bottom: true,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // SeaYou Logo/Title with serif font
                      const Text(
                        'SeaYou',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontFamilyFallback: ['serif'],
                          fontSize: 56,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 16,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        AppLocalizations.of(context).tr('splash.subtitle'),
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).tr('splash.feeling'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // White card with profiles and progress bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Left profile picture (Woman)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: const DecorationImage(
                                  image: AssetImage(
                                      'assets/images/avatar_2.jpeg'),
                                  fit: BoxFit.cover,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Animated bar GIF
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 48,
                                  child: OverflowBox(
                                    maxHeight: 70, // Make animation bigger
                                    child: Image.asset(
                                      'assets/videos/animated_bar.gif',
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: 70,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFFFFB347),
                                                Color(0xFFFF6EC7),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Right profile picture (Man)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: const DecorationImage(
                                  image: AssetImage(
                                      'assets/images/avatar_1.jpeg'),
                                  fit: BoxFit.cover,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sign up button
                      GestureDetector(
                        onTap: () async {
                          // Pause the video before navigating to stop audio
                          _controller.pause();

                          final session =
                              Supabase.instance.client.auth.currentSession;

                          if (session != null) {
                            try {
                              final profile = await Supabase.instance.client
                                  .from('profiles')
                                  .select()
                                  .eq('id', session.user.id)
                                  .maybeSingle();

                              if (mounted) {
                                await OnboardingService()
                                    .resumeOnboarding(context, profile);
                              }
                            } catch (e) {
                              // Default to home if check fails but we have session
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const HomeScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          } else {
                            // Not logged in, check for pending signup
                            final step = await OnboardingService().getStep();
                            if (step != OnboardingStep.languageSelection) {
                              if (mounted) {
                                await OnboardingService()
                                    .navigateToStep(context, step);
                              }
                            } else {
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LanguageSelectionScreen(),
                                  ),
                                ).then((_) {
                                  if (mounted) _controller.play();
                                });
                              }
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(context)
                                .tr('splash.sign_up_free'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
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
        ],
      ),
    );
  }
}
