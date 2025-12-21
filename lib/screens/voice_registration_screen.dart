import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
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
import '../i18n/app_localizations.dart';

class VoiceRegistrationScreen extends StatefulWidget {
  final UserProfile userProfile;
  const VoiceRegistrationScreen({super.key, required this.userProfile});

  @override
  State<VoiceRegistrationScreen> createState() => _VoiceRegistrationScreenState();
}

class _VoiceRegistrationScreenState extends State<VoiceRegistrationScreen> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _isProcessing = false;
  int _duration = 0;
  String? _path;
  Timer? _timer;
  bool _showTip = false;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;

  // Constants for duration limits
  static const int _minDuration = 5;
  static const int _maxDuration = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await TutorialService().hasSeenAudioTip();
      if (!seen && mounted) setState(() => _showTip = true);
      final user = AuthService().currentUser;
      if (user != null) {
        final prefs = await DatabaseService().getUserPreferences(user.id);
        final existing = prefs?['voice_clip_url'] as String?;
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
    _uploadController = UploadController();
    _uploadController.addListener(() {
      final vals = _uploadController.statuses.values;
      if (vals.isEmpty) return;
      final p = vals.map((s) => s.progress).fold(0.0, (a, b) => a + b) / vals.length;
      setState(() => _uploadProgress = p);
    });
  }

  Future<void> _start() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/reg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      setState(() {
        _recording = true;
        _duration = 0;
        _path = path;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (mounted) {
          setState(() => _duration++);
          if (_duration >= _maxDuration) {
             await _stop();
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
    
    // Wait a moment for file to be fully written
    await Future.delayed(const Duration(milliseconds: 500));
    
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

  @override
  Widget build(BuildContext context) {
    // Use localized strings
    final tr = AppLocalizations.of(context);
    final canProceed = !_recording && _duration >= _minDuration && _duration <= _maxDuration && _path != null && File(_path!).existsSync();
    
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
                    Text(tr.tr('voice.title'), style: AppTextStyles.displayText),
                    // Info button to re-show tip
                    IconButton(
                       icon: const Icon(Icons.info_outline, color: AppColors.primary),
                       onPressed: () => setState(() => _showTip = true),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr.tr('voice.step_label'), style: AppTextStyles.bodyText),
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
                child: Icon(_recording ? Icons.stop : Icons.mic, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                _isProcessing 
                  ? tr.tr('voice.processing')
                  : tr.tr('voice.duration_label', args: {'duration': _duration.toString()}), 
                style: AppTextStyles.bodyText,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    CustomButton(
                      text: _recording ? tr.tr('voice.stop') : tr.tr('voice.record'),
                      isActive: !_isProcessing,
                      onPressed: !_isProcessing ? () async {
                        if (_recording) {
                          await _stop();
                        } else {
                          await _start();
                        }
                      } : null,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: tr.tr('voice.next'),
                      isActive: canProceed,
                      onPressed: canProceed
                          ? () async {
                            final nav = Navigator.of(context);
                            final user = AuthService().currentUser;
                            if (user != null && _path != null) {
                              final id = DateTime.now().millisecondsSinceEpoch.toString();
                              // Show progress (simplistic)
                              setState(() => _uploadProgress = 0.1);

                              await _uploadController.enqueue(UploadTask(id: id, bucket: 'voice_clips', userId: user.id, file: File(_path!), prefix: 'voice'));
                              final st = _uploadController.statuses[id];
                              
                              // Fallback if controller doesn't return URL immediately or fails
                              String? url = st?.url;
                              if (url == null) {
                                  url = await DatabaseService().uploadVoiceClip(user.id, File(_path!));
                              }
                              
                              if (url != null) {
                                await DatabaseService().upsertUserPreferences(userId: user.id, voiceClipUrl: url);
                                
                                // Update profile object
                                widget.userProfile.secretAudioUrl = url;
                                
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (_) => UploadPictureScreen(userProfile: widget.userProfile),
                                  ),
                                );
                              } else {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Please try again.')));
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
               Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(value: _uploadProgress, color: AppColors.primary)),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _uploadController.dispose();
    super.dispose();
  }
}

