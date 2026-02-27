import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../i18n/app_localizations.dart';

class SentBottleVideoModal extends StatefulWidget {
  final VoidCallback onComplete;

  const SentBottleVideoModal({
    super.key,
    required this.onComplete,
  });

  @override
  State<SentBottleVideoModal> createState() => _SentBottleVideoModalState();
}

class _SentBottleVideoModalState extends State<SentBottleVideoModal> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    // PLACEHOLDER: Using onboarding.mp4 because sent_bottle.mp4 is incompatible/broken.
    // Replace string below when you have a fixed video file.
    _controller = VideoPlayerController.asset('assets/videos/sent_bottle.mp4')
      ..initialize().then((_) {
        debugPrint('✅ Video initialized successfully');
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
          _controller.addListener(_checkVideoEnd);
        }
      }).catchError((error) {
        debugPrint('❌ Error initializing video: $error');
        // If video fails, close modal automatically
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('${AppLocalizations.of(context).tr("system.animation_error")}: $error')),
           );
           widget.onComplete();
        }
      });
  }

  void _checkVideoEnd() {
    // Only trigger once
    if (!_hasCompleted && _controller.value.position >= _controller.value.duration) {
      debugPrint('🎬 Video finished');
      _hasCompleted = true; // Prevent multiple calls
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onComplete, // Tap to skip/close
      child: Scaffold(
        backgroundColor: Colors.black, // Full screen black background for immersive feel
        body: Center(
          child: _initialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(
                  color: Colors.white,
                ), // Show loader while initializing
        ),
      ),
    );
  }
}
