import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/animated_waveform.dart';
import 'sexual_orientation_screen.dart';
import '../models/user_profile.dart';

class ProfileInfoScreen extends StatefulWidget {
  final String email;
  final String? selectedLanguage;
  
  const ProfileInfoScreen({
    super.key, 
    required this.email,
    this.selectedLanguage,
  });

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _secretDesireController = TextEditingController();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _secretAudioPath;

  bool get isFormValid =>
      _nameController.text.isNotEmpty &&
      _ageController.text.isNotEmpty &&
      _cityController.text.isNotEmpty &&
      _aboutController.text.isNotEmpty &&
      _secretDesireController.text.isNotEmpty &&
      _secretAudioPath != null;

  @override
  void initState() {
    super.initState();
    // Add listeners to update UI when text changes
    _nameController.addListener(_updateFormState);
    _ageController.addListener(_updateFormState);
    _cityController.addListener(_updateFormState);
    _aboutController.addListener(_updateFormState);
    _secretDesireController.addListener(_updateFormState);
  }

  void _updateFormState() {
    setState(() {
      // Force rebuild when any field changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
          Positioned(
            left: 0,
            top: -303,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 300,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tell us about yourself',
                              style: AppTextStyles.displayText,
                            ),
                            Text(
                              '1/5',
                              style: AppTextStyles.bodyText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Full Name',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Enter your name',
                          controller: _nameController,
                          isActive: _nameController.text.isNotEmpty,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Age',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Enter your age',
                          controller: _ageController,
                          isActive: _ageController.text.isNotEmpty,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'City',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Nairobi',
                          controller: _cityController,
                          isActive: _cityController.text.isNotEmpty,
                          suffixIcon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'About',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Add a short bio description',
                          controller: _aboutController,
                          isActive: _aboutController.text.isNotEmpty,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_aboutController.text.length}/80',
                            style: AppTextStyles.bodyText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Secret Desire Section
                        Text(
                          'Secret Desire',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: 'Add your secret fantasy',
                          controller: _secretDesireController,
                          isActive: _secretDesireController.text.isNotEmpty,
                          maxLines: 3,
                          maxLength: 200,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Note: This will be anonymous to everyone. At least 200 words.',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12,
                                  color: AppColors.darkGrey,
                                ),
                              ),
                            ),
                            Text(
                              '${_secretDesireController.text.length}/200',
                              style: AppTextStyles.bodyText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Secret Audio Section
                        Text(
                          'Add a secret audio',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Recording button
                        GestureDetector(
                          onTap: _toggleRecording,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording 
                                  ? AppColors.primary 
                                  : AppColors.primary.withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: AppColors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        
                        if (_isRecording || _secretAudioPath != null) ...[
                          const SizedBox(height: 16),
                          AnimatedWaveform(
                            isAnimating: _isRecording,
                            color: AppColors.primary,
                            barCount: 30,
                            height: 60,
                            barWidth: 3,
                            spacing: 2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRecording 
                                ? 'Recording: ${_formatRecordingTime()}'
                                : 'Recording saved: ${_formatRecordingTime()}',
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                          if (_secretAudioPath != null && !_isRecording) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _togglePlayback,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
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
                        ],
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: 'Next',
                    isActive: isFormValid,
                    onPressed: () {
                      if (isFormValid) {
                        final userProfile = UserProfile(
                          email: widget.email,
                          fullName: _nameController.text,
                          age: int.tryParse(_ageController.text),
                          city: _cityController.text,
                          about: _aboutController.text,
                          language: widget.selectedLanguage ?? "English (device's language)",
                          secretDesire: _secretDesireController.text,
                          secretAudioUrl: _secretAudioPath, // Will be uploaded later
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SexualOrientationScreen(
                              userProfile: userProfile,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    );
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/secret_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
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
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _secretAudioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_secretAudioPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_secretAudioPath!));
      if (mounted) setState(() => _isPlaying = true);
      
      // Listen for completion
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  String _formatRecordingTime() {
    final minutes = _recordingSeconds ~/ 60;
    final seconds = _recordingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _aboutController.dispose();
    _secretDesireController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }
}
