import 'package:flutter/material.dart';
import '../services/audio_service.dart';

/// Wrapper widget that enables tap-anywhere-to-toggle-mute functionality
/// Wrap any screen with this widget to enable the feature
/// This widget allows tapping on empty space to toggle mute while preserving
/// all normal touch interactions with child widgets
class TapToMuteWrapper extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const TapToMuteWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    
    return Stack(
      children: [
        // Background tap detector (positioned behind everything)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Toggle mute when tapping on empty space
              GlobalAudioController.instance.toggleMute();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        // Actual content (taps on widgets will be handled by the widgets themselves)
        child,
      ],
    );
  }
}
