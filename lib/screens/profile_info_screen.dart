import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/animated_waveform.dart';
import '../i18n/app_localizations.dart';
import 'gender_identity_screen.dart';
import '../models/user_profile.dart';
import '../utils/french_departments.dart';

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
  final TextEditingController _secretQuoteController = TextEditingController();
  final TextEditingController _secretDesireController = TextEditingController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _secretAudioPath;
  static const int _minDuration = 5;
  static const int _maxDuration = 15;
  String? _selectedDepartment;

  bool get isFormValid =>
      _nameController.text.isNotEmpty &&
      _ageController.text.isNotEmpty &&
      _cityController.text.isNotEmpty &&
      _selectedDepartment != null &&
      _aboutController.text.isNotEmpty &&
      _secretQuoteController.text.isNotEmpty &&
      _secretDesireController.text.isNotEmpty &&
      _secretAudioPath != null &&
      _recordingSeconds >= _minDuration;

  @override
  void initState() {
    super.initState();
    // Add listeners to update UI when text changes
    // Add listeners to update UI when text changes
    _nameController.addListener(_updateFormState);
    _ageController.addListener(_updateFormState);
    _cityController.addListener(_updateFormState);
    _aboutController.addListener(_updateFormState);
    _secretQuoteController.addListener(_updateFormState);
    _secretDesireController.addListener(_updateFormState);

    // V7: Ensure player responds immediately
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
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
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.profile_info.title'),
                              style: AppTextStyles.displayText,
                            ),
                            const Text(
                              '1/6',
                              style: AppTextStyles.bodyText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(context)
                              .tr('onboarding.profile_info.full_name'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: AppLocalizations.of(context)
                              .tr('onboarding.profile_info.full_name_hint'),
                          controller: _nameController,
                          isActive: _nameController.text.isNotEmpty,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)
                              .tr('onboarding.profile_info.age'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: AppLocalizations.of(context)
                              .tr('onboarding.profile_info.age_hint'),
                          controller: _ageController,
                          isActive: _ageController.text.isNotEmpty,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                        .tr('onboarding.profile_info.city'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.darkGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    hintText: AppLocalizations.of(context).tr(
                                        'onboarding.profile_info.city_hint'),
                                    controller: _cityController,
                                    isActive: _cityController.text.isNotEmpty,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).tr(
                                        'onboarding.profile_info.department'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.darkGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _selectedDepartment != null
                                            ? AppColors.primary
                                            : AppColors.grey,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedDepartment,
                                        hint: Text(
                                          AppLocalizations.of(context).tr(
                                              'onboarding.profile_info.department_hint'),
                                          style:
                                              AppTextStyles.bodyText.copyWith(
                                            color: AppColors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: AppColors.grey,
                                          size: 20,
                                        ),
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 12,
                                          color: _selectedDepartment != null
                                              ? AppColors.darkGrey
                                              : AppColors.grey,
                                        ),
                                        items: frenchDepartments
                                            .map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          setState(() {
                                            _selectedDepartment = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.profile_info.bio'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final tr = AppLocalizations.of(context);
                                _showBubble(
                                  tr.tr('tooltip.bio.title'),
                                  tr.tr('tooltip.bio.message'),
                                  tr.tr('tooltip.bio.ok'),
                                );
                              },
                              child: const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: AppLocalizations.of(context)
                              .tr('onboarding.profile_info.bio_hint'),
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

                        // Secret Quote Section
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.profile_info.secret_quote'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final tr = AppLocalizations.of(context);
                                _showBubble(
                                  tr.tr('tooltip.quote.title'),
                                  tr.tr('tooltip.quote.message'),
                                  tr.tr('tooltip.quote.ok'),
                                );
                              },
                              child: const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: AppLocalizations.of(context)
                              .tr('onboarding.profile_info.secret_quote_hint'),
                          controller: _secretQuoteController,
                          isActive: _secretQuoteController.text.isNotEmpty,
                          maxLines: 2,
                          maxLength: 200,
                        ),
                        const SizedBox(height: 24),

                        // Secret Fantasy Section
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.profile_info.secret_fantasy'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final tr = AppLocalizations.of(context);
                                _showBubble(
                                  tr.tr('tooltip.fantasy.title'),
                                  tr.tr('tooltip.fantasy.message'),
                                  tr.tr('tooltip.fantasy.ok'),
                                );
                              },
                              child: const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          hintText: AppLocalizations.of(context).tr(
                              'onboarding.profile_info.secret_fantasy_hint'),
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
                                AppLocalizations.of(context).tr(
                                    'onboarding.profile_info.secret_fantasy_note'),
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
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .tr('onboarding.profile_info.secret_audio'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final tr = AppLocalizations.of(context);
                                _showBubble(
                                  tr.tr('tooltip.audio.title'),
                                  tr.tr('tooltip.audio.message'),
                                  tr.tr('tooltip.audio.ok'),
                                );
                              },
                              child: const Icon(Icons.info_outline,
                                  size: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).tr(
                              'onboarding.profile_info.secret_audio_duration'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),

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
                          Text(
                            _isRecording
                                ? AppLocalizations.of(context).tr(
                                    'onboarding.profile_info.recording',
                                    params: {'time': _formatRecordingTime()})
                                : AppLocalizations.of(context).tr(
                                    'onboarding.profile_info.recording_saved',
                                    params: {'time': _formatRecordingTime()}),
                            style: AppTextStyles.bodyText.copyWith(
                              color: (_recordingSeconds >= _minDuration)
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_recordingSeconds < _minDuration &&
                              !_isRecording &&
                              _secretAudioPath != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context).tr(
                                  'onboarding.profile_info.voice_too_short'),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                          if (_secretAudioPath != null && !_isRecording) ...[
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
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: AppLocalizations.of(context).tr('common.next'),
                    isActive: isFormValid,
                    onPressed: () async {
                      if (isFormValid) {
                        // V7: Ensure audio stops before navigation
                        debugPrint(
                            '🎵 [ProfileInfo] NEXT CLICKED - Stopping audio');

                        try {
                          await _audioPlayer.stop();
                          await _audioPlayer.release();
                          debugPrint(
                              '🎵 [ProfileInfo] Audio released finished.');
                        } catch (e) {
                          debugPrint('🎵 [ProfileInfo] Release Error: $e');
                        }

                        final userProfile = UserProfile(
                          email: widget.email,
                          fullName: _nameController.text,
                          age: int.tryParse(_ageController.text),
                          city: _cityController.text,
                          department: _selectedDepartment,
                          about: _aboutController.text,
                          language: widget.selectedLanguage ??
                              "English (device's language)",
                          secretDesire: _secretDesireController.text,
                          secretQuote: _secretQuoteController.text,
                          secretAudioUrl: _secretAudioPath,
                        );
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GenderIdentityScreen(
                                userProfile: userProfile,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
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
          SnackBar(
            content: Text(AppLocalizations.of(context)
                .tr('onboarding.profile_info.mic_permission_required')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/secret_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
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
      await _audioPlayer.setVolume(1.0); // Ensure audible
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
    _secretQuoteController.dispose();
    _secretDesireController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _showBubble(String title, String message, String okText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: AppTextStyles.displayText.copyWith(fontSize: 18)),
        content: Text(message,
            style: AppTextStyles.bodyText.copyWith(color: AppColors.darkGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(okText,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
