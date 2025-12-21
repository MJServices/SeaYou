import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class GlobalAudioController {
  GlobalAudioController._();
  static final GlobalAudioController instance = GlobalAudioController._();

  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  final AudioPlayer _ambientPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _ambientInitialized = false;
  final double _ambientVolume = 0.7; // 30% reduction

  Future<void> init() async {
    // Preload: check assets exist; avoid crashing if missing
    try {
      await rootBundle.load('assets/sfx/ambient_waves.mp3');
      _ambientInitialized = true;
    } catch (_) {
      _ambientInitialized = false;
    }
  }

  Future<void> playAmbient() async {
    if (!_ambientInitialized || muted.value) return;
    try {
      await _ambientPlayer.stop();
      await _ambientPlayer.setVolume(_ambientVolume);
      await _ambientPlayer.play(AssetSource('sfx/ambient_waves.mp3'));
    } catch (_) {}
  }

  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
    } catch (_) {}
  }

  Future<void> playCompletionSfx() async {
    if (muted.value) return;
    try {
      // Optional ducking: reduce ambient during SFX
      final prevVol = _ambientVolume;
      await _ambientPlayer.setVolume(prevVol * 0.7);
      await _sfxPlayer.play(AssetSource('sfx/progress_complete.wav'), volume: 1.0);
      // Restore ambient after short delay
      unawaited(Future.delayed(const Duration(milliseconds: 800), () async {
        try {
          await _ambientPlayer.setVolume(prevVol);
        } catch (_) {}
      }));
    } catch (_) {}
  }

  void toggleMute() {
    final next = !muted.value;
    muted.value = next;
    _applyMuteState();
  }

  Future<void> _applyMuteState() async {
    try {
      final vol = muted.value ? 0.0 : _ambientVolume;
      await _ambientPlayer.setVolume(vol);
      await _sfxPlayer.setVolume(muted.value ? 0.0 : 1.0);
    } catch (_) {}
  }

  void dispose() {
    _ambientPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
