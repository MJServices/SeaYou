import 'package:flutter/material.dart';
import '../services/audio_service.dart';

/// Warm gradient background widget for all screens
/// Creates a welcoming, sensual atmosphere with peach to purple gradient
class WarmGradientBackground extends StatelessWidget {
  final Widget child;
  final bool useImageBackground;

  const WarmGradientBackground({
    super.key,
    required this.child,
    this.useImageBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (useImageBackground) {
      // Use the warm background image if available
      return Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/warm-gradiant.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      );
    }

    // Soft ellipse gradient with purple tones
    // Color: Light lavender fading to cream/beige background
    return GestureDetector(
      // Global tap-to-mute functionality
      onTap: () {
        // Import is implicit - GlobalAudioController is from audio_service
        try {
          GlobalAudioController.instance.toggleMute();
        } catch (e) {
          // Fail silently if audio service not available
          debugPrint('Audio toggle failed: $e');
        }
      },
      child: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.8), // Positioned near top center
            radius: 1.2,
            colors: [
              Color(0xFFE8D0F5), // Light lavender center
              Color(0x80D4B5E8), // 50% opacity purple
              Color(0x40C8A8E8), // 25% opacity purple
              Color(0x20B899E0), // 12% opacity purple
              Color(0xFFFFF8F0), // Cream/beige background
            ],
            stops: [0.0, 0.15, 0.35, 0.55, 0.8],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Alternative warm gradient with more orange tones
class WarmGradientOrange extends StatelessWidget {
  final Widget child;

  const WarmGradientOrange({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFAA88), // Warm coral
            Color(0xFFFFBB99), // Peach
            Color(0xFFFFCCAA), // Light orange
            Color(0xFFFFDDBB), // Cream
            Color(0xFFFFEEDD), // Very light cream
            Color(0xFFFFDDEE), // Light pink
            Color(0xFFEECCFF), // Lavender
          ],
          stops: [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Subtle warm gradient for cards and containers
class WarmCardGradient extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const WarmCardGradient({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            const Color(0xFFFFF5F0).withValues(alpha: 0.95),
            const Color(0xFFFFF0F5).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE0E0).withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}
