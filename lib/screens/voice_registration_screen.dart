import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/custom_button.dart';
import '../models/user_profile.dart';
import '../services/upload_controller.dart';
import 'upload_picture_screen.dart';
import '../widgets/coachmark_bubble.dart';
import '../services/tutorial_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../i18n/app_localizations.dart';

class VoiceRegistrationScreen extends StatefulWidget {
  final UserProfile userProfile;
  const VoiceRegistrationScreen({super.key, required this.userProfile});

  @override
  State<VoiceRegistrationScreen> createState() =>
      _VoiceRegistrationScreenState();
}

class _VoiceRegistrationScreenState extends State<VoiceRegistrationScreen>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _recording = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  int _duration = 0;
  String? _path;
  Timer? _timer;
  bool _showTip = false;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  StreamSubscription? _playerCompleteSubscription;
  bool _isNavigating = false; // Flag to prevent audio after navigation

  // Constants for duration limits
  static const int _minDuration = 5;
  static const int _maxDuration = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configure audio player for immediate response
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // Set up audio player completion listener ONCE
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint('🎵 [VoiceReg] Player complete event');
      if (mounted) setState(() => _isPlaying = false);
    });

    _audioPlayer.onLog.listen((msg) {
      debugPrint('🎵 [VoiceReg] AudioPlayer Log: $msg');
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('🎵 [VoiceReg] AudioPlayer State Changed: $state');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await TutorialService().hasSeenAudioTip();
      if (!seen && mounted) setState(() => _showTip = true);
    });
    _uploadController = UploadController();
    _uploadController.addListener(() {
      final vals = _uploadController.statuses.values;
      if (vals.isEmpty) return;
      final p =
          vals.map((s) => s.progress).fold(0.0, (a, b) => a + b) / vals.length;
      setState(() => _uploadProgress = p);
    });
  }

  Future<void> _start() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/reg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: path,
      );
      setState(() {
        _recording = true;
        _duration = 0;
        _path = path;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (mounted) {
          final elapsedSeconds = (timer.tick * 100) / 1000.0;
          
          // Always update UI when hitting a full second to ensure 15 is shown
          if (timer.tick % 10 == 0) {
            setState(() => _duration = elapsedSeconds.round());
          }

          if (elapsedSeconds >= _maxDuration) {
            timer.cancel();
            if (_recording) {
              await _stop();
            }
          }
        }
      });
    }
  }

  Future<void> _stop() async {
    // If already stopped or processing, avoid double call
    if (!_recording || _isProcessing) return;

    setState(() => _isProcessing = true);

    final recordedPath = await _recorder.stop();
    _timer?.cancel();
    _timer = null;

    // Snappy stop for better UX
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        _recording = false;
        _isProcessing = false;
        // Update path from recorder if available
        if (recordedPath != null && recordedPath.isNotEmpty) {
          _path = recordedPath;
        }
      });
    }

    // Verify file exists
    if (_path != null && File(_path!).existsSync()) {
      debugPrint('✅ Recording saved: $_path');
      debugPrint('✅ File size: ${File(_path!).lengthSync()} bytes');
    } else {
      debugPrint('❌ Recording file not found: $_path');
    }
  }

  Future<void> _togglePlayback() async {
    if (_path == null || _isNavigating) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      // Final guard before playing
      if (_isNavigating) return;
      await _audioPlayer.setVolume(1.0); // Ensure audible
      await _audioPlayer.play(DeviceFileSource(_path!));
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  Future<void> _stopAudioCompletely() async {
    _isNavigating = true;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
      }
    } catch (e) {
      debugPrint('Error stopping audio completely: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use localized strings
    final tr = AppLocalizations.of(context);
    final canProceed = !_recording &&
        _duration >= _minDuration &&
        _duration <= _maxDuration &&
        _path != null &&
        File(_path!).existsSync();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        // Force stop audio when navigating away via back button
        await _stopAudioCompletely();
      },
      child: Scaffold(
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
                          onPressed: () async {
                            debugPrint('🎵 [VoiceReg] Back pressed.');
                            _isNavigating = true;
                            try {
                              await _audioPlayer.pause();
                              await _audioPlayer.stop();
                              await _audioPlayer.release();
                              debugPrint(
                                  '🎵 [VoiceReg] Audio release finished.');
                            } catch (e) {
                              debugPrint('🎵 [VoiceReg] Release Error: $e');
                            }
                            if (mounted) Navigator.pop(context);
                          },
                          padding: EdgeInsets.zero,
                        ),
                        Text(tr.tr('voice.title'),
                            style: AppTextStyles.displayText),
                        // Info button to re-show tip
                        IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: AppColors.primary),
                          onPressed: () => setState(() => _showTip = true),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.tr('voice.step_label'),
                            style: AppTextStyles.bodyText),
                        const SizedBox(height: 4),
                        Text(
                          'Min: 5 seconds • Max: 15 seconds',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(_recording ? Icons.stop : Icons.mic,
                        size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isProcessing
                        ? tr.tr('voice.processing')
                        : (_path != null
                            ? 'Recording saved: ${_duration.toString().padLeft(2, '0')}:${(_duration % 60).toString().padLeft(2, '0')}'
                            : tr.tr('voice.duration_label',
                                params: {'duration': _duration.toString()})),
                    style: AppTextStyles.bodyText.copyWith(
                      color: (_duration >= _minDuration ||
                              _isProcessing ||
                              _path == null)
                          ? AppColors.grey
                          : Colors.red,
                      fontWeight: (_duration < _minDuration &&
                              _path != null &&
                              !_recording)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (_duration < _minDuration &&
                      !_recording &&
                      _path != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Voice message must be at least 5 seconds long',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                  if (_path != null && !_recording) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomButton(
                          text: _recording
                              ? tr.tr('voice.stop')
                              : tr.tr('voice.record'),
                          isActive: !_isProcessing,
                          onPressed: !_isProcessing
                              ? () async {
                                  if (_recording) {
                                    await _stop();
                                  } else {
                                    await _start();
                                  }
                                }
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: tr.tr('voice.next'),
                          isActive: canProceed,
                          onPressed: canProceed
                              ? () async {
                                  // Ensure audio stops before navigation
                                  debugPrint(
                                      '🎵 [VoiceReg] NEXT CLICKED - Stopping audio');

                                  // 1. BLOCK further playback
                                  _isNavigating = true;

                                  // 2. RELEASE audio resources
                                  try {
                                    debugPrint(
                                        '🎵 [VoiceReg] Next: Executing pause/stop/release...');
                                    await _audioPlayer.pause();
                                    await _audioPlayer.stop();
                                    await _audioPlayer.release();
                                    debugPrint(
                                        '🎵 [VoiceReg] Next: Release finished.');
                                  } catch (e) {
                                    debugPrint('🎵 [VoiceReg] Next: Error: $e');
                                  }

                                  setState(() {
                                    _isPlaying = false;
                                  });

                                  final nav = Navigator.of(context);
                                  final user = AuthService().currentUser;
                                  if (user != null && _path != null) {
                                    final id = DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();
                                    // Show progress (simplistic)
                                    setState(() => _uploadProgress = 0.1);

                                    await _uploadController.enqueue(UploadTask(
                                        id: id,
                                        bucket: 'voice_clips',
                                        userId: user.id,
                                        file: File(_path!),
                                        prefix: 'voice'));
                                    final st = _uploadController.statuses[id];

                                    // Fallback if controller doesn't return URL immediately or fails
                                    String? url = st?.url;
                                    url ??= await DatabaseService()
                                        .uploadVoiceClip(user.id, File(_path!));

                                    if (url != null) {
                                      await DatabaseService()
                                          .upsertUserPreferences(
                                              userId: user.id,
                                              voiceClipUrl: url);

                                      // Update profile object
                                      widget.userProfile.secretAudioUrl = url;

                                      nav.pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => UploadPictureScreen(
                                              userProfile: widget.userProfile),
                                        ),
                                      );
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(AppLocalizations
                                                        .of(context)
                                                    .tr('errors.upload_failed'))));
                                      }
                                    }
                                    setState(() => _uploadProgress = 0.0);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showTip)
              Positioned(
                left: 0,
                right: 0,
                top: 60, // Adjusted top position to sit below app bar
                bottom: 0,
                child: Container(
                  color: Colors.black54, // Dim background
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: CoachmarkBubble(
                        title: tr.tr('voice.secret_title'),
                        message: tr.tr('voice.secret_description'),
                        ctaText: tr.tr('voice.tip_cta'),
                        onCta: () async {
                          setState(() => _showTip = false);
                          await TutorialService().setSeenAudioTip();
                        },
                        onClose: () async {
                          setState(() => _showTip = false);
                          await TutorialService().setSeenAudioTip();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            if (_uploadProgress > 0 && _uploadProgress < 1.0)
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                      value: _uploadProgress, color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }

  @override
  void deactivate() {
    _audioPlayer.pause();
    _audioPlayer.stop();
    _isPlaying = false;
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerCompleteSubscription?.cancel();
    _audioPlayer.pause();
    _audioPlayer.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    _uploadController.dispose();
    super.dispose();
  }
}
