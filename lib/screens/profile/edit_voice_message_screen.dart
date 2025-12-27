import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/app_colors.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../widgets/custom_button.dart';
import '../../services/database_service.dart';
import '../../widgets/animated_waveform.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Edit Voice Message Screen - Allows user to edit their secret audio (5-15 seconds)
class EditVoiceMessageScreen extends StatefulWidget {
  const EditVoiceMessageScreen({super.key});

  @override
  State<EditVoiceMessageScreen> createState() => _EditVoiceMessageScreenState();
}

class _EditVoiceMessageScreenState extends State<EditVoiceMessageScreen> {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _recording = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSaving = false;
  int _duration = 0;
  String? _path;
  String? _currentAudioUrl;
  Timer? _timer;
  String? _errorMessage;

  // Constants for duration limits
  static const int _minDuration = 5;
  static const int _maxDuration = 15;

  @override
  void initState() {
    super.initState();
    _loadCurrentVoiceMessage();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _loadCurrentVoiceMessage() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _databaseService.getProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _currentAudioUrl = profile['secret_audio_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading voice message: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load voice message';
        });
      }
    }
  }

  Future<void> _start() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/secret_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        _errorMessage = null;
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
    if (!_recording || _isProcessing) return;

    setState(() => _isProcessing = true);
    
    final recordedPath = await _recorder.stop();
    _timer?.cancel();
    _timer = null;
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _recording = false;
        _isProcessing = false;
        if (recordedPath != null && recordedPath.isNotEmpty) {
          _path = recordedPath;
        }
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_path == null) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_path!));
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  Future<void> _saveVoiceMessage() async {
    if (_path == null || _duration < _minDuration) {
      setState(() => _errorMessage = 'Recording must be at least $_minDuration seconds');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Upload to storage
      final file = File(_path!);
      final ext = _path!.split('.').last;
      final fileName = 'secret_audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$userId/$fileName';

      await _supabase.storage
          .from('voice_clips')
          .upload(path, file, fileOptions: const FileOptions(upsert: false));

      final url = _supabase.storage.from('voice_clips').getPublicUrl(path);

      // Update profile
      await _databaseService.updateSecretAudio(userId, url);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice message updated successfully!'),
          backgroundColor: Color(0xFF0AC5C5),
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving voice message: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  String _formatDuration() {
    return '${_duration}s / ${_maxDuration}s';
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Decorative ellipse
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 24,
                            height: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit my voice message',
                            style: AppTextStyles.displayText.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 32),

                                // Title
                                const Text(
                                  'Add a secret audio',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF171717),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Duration constraint
                                Text(
                                  'Min: $_minDuration seconds • Max: $_maxDuration seconds',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                                const SizedBox(height: 48),

                                // Record button
                                GestureDetector(
                                  onTap: _recording ? _stop : _start,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _recording ? Icons.stop : Icons.mic,
                                      color: AppColors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),

                                if (_recording || _path != null) ...[
                                  const SizedBox(height: 24),
                                  
                                  // Waveform animation
                                  if (_recording)
                                    AnimatedWaveform(
                                      isAnimating: _recording,
                                      color: AppColors.primary,
                                      barCount: 30,
                                      height: 60,
                                      barWidth: 3,
                                      spacing: 2,
                                    ),

                                  const SizedBox(height: 16),

                                  // Duration display
                                  Text(
                                    _recording
                                        ? 'Recording: ${_formatDuration()}'
                                        : 'Recorded: ${_duration}s',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: _duration >= _minDuration
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  if (_duration < _minDuration && !_recording) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Must be at least $_minDuration seconds',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],

                                  // Playback button
                                  if (_path != null && !_recording) ...[
                                    const SizedBox(height: 24),
                                    GestureDetector(
                                      onTap: _togglePlayback,
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE0B3FF),
                                        ),
                                        child: Icon(
                                          _isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 48),

                                // Save button
                                CustomButton(
                                  text: 'Save',
                                  onPressed: _saveVoiceMessage,
                                  isActive: _path != null && _duration >= _minDuration && !_recording && !_isSaving,
                                ),
                              ],
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
