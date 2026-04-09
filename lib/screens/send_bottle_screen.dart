import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'purchase_scrolls_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';

import '../services/database_service.dart';
import '../services/bottle_matching_service.dart';
import '../services/entitlements_service.dart';
import '../services/upload_controller.dart';
import '../services/upload_service.dart';
import '../widgets/preview_modal.dart';
import '../widgets/sent_bottle_video_modal.dart'; // Import video modal
import '../widgets/targeting_options_modal.dart'; // Import targeting modal
import '../widgets/animated_waveform.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../i18n/app_localizations.dart';

/// Send Bottle Screen - Perfect implementation matching Figma screens 11-26
/// Supports Text, Picture, and Voice Chat bottle creation
class SendBottleScreen extends StatefulWidget {
  final String? replyToBottleId;
  final String? replyToUserId;

  const SendBottleScreen({
    super.key,
    this.replyToBottleId,
    this.replyToUserId,
  });

  @override
  State<SendBottleScreen> createState() => _SendBottleScreenState();
}

class _SendBottleScreenState extends State<SendBottleScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  // Type is always 'text' - removed type selector
  String _selectedMood = 'Romantique';
  bool _canPreview = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  final DatabaseService _databaseService = DatabaseService();
  final BottleMatchingService _matchingService = BottleMatchingService();
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  final AudioRecorder _voiceRecorder = AudioRecorder();
  String? _voicePath;
  bool _isSending = false;

  // Targeting State
  RangeValues _ageRange = const RangeValues(18, 99);
  List<String> _targetGenders = [];
  List<String> _targetDepartments = [];
  int _remainingScrolls = 0;
  bool _isPremiumOrWoman = false;
  bool _statusLoaded = false;
  
  // Voice Recording Constants
  static const int _minDuration = 5;
  static const int _maxDuration = 15;

  final List<Map<String, dynamic>> _moods = [
    {
      'name': 'Curieux',
      'color': const Color(0xFFD89736),
      'icon': 'curious.jpeg'
    },
    {
      'name': 'Taquin',
      'color': const Color(0xFFFF6D68),
      'icon': 'playful.jpeg'
    },
    {
      'name': 'Romantique',
      'color': const Color(0xFF9B98E6),
      'icon': 'dream.jpeg'
    },
    {'name': 'Joyeux', 'color': const Color(0xFF65ADA9), 'icon': 'calm.jpeg'},
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updatePreviewState);
    _captionController.addListener(_updatePreviewState);
    _loadScrollCount();
    _checkPremiumStatus();
    _uploadController = UploadController();
    _uploadController.addListener(() {
      final vals = _uploadController.statuses.values;
      if (vals.isEmpty) return;
      final p =
          vals.map((s) => s.progress).fold(0.0, (a, b) => a + b) / vals.length;
      setState(() => _uploadProgress = p);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _captionController.dispose();
    _recordingTimer?.cancel();
    _voiceRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadScrollCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final count = await _databaseService.getAvailableScrollsCount(userId);
      if (mounted) {
        setState(() => _remainingScrolls = count);
      }
    }
  }

  Future<void> _checkPremiumStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final isPW = await EntitlementsService().isPremiumOrWoman(userId);
      if (mounted) {
        setState(() {
          _isPremiumOrWoman = isPW;
          _statusLoaded = true;
        });
      }
    }
  }

  void _updatePreviewState() {
    setState(() {
      // Text-only mode - check if message has content
      _canPreview = _messageController.text.trim().isNotEmpty;
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _startVoiceRecording();
      } else {
        _stopVoiceRecording();
      }
    });
  }

  Future<void> _startVoiceRecording() async {
    debugPrint('🎙️ Starting voice recording...');
    _recordingSeconds = 0;

    final hasPerm = await _voiceRecorder.hasPermission();
    debugPrint('🎙️ Microphone permission: $hasPerm');

    if (hasPerm) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/bottle_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        debugPrint('🎙️ Recording path: $path');

        // Check if recorder is available
        final isAvailable =
            await _voiceRecorder.isEncoderSupported(AudioEncoder.aacLc);
        debugPrint('🎙️ AAC encoder supported: $isAvailable');

        await _voiceRecorder.start(
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

        _voicePath = path;
        debugPrint('🎙️ Recording started successfully');

        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (mounted) {
            final double elapsed = (timer.tick * 100) / 1000.0;

            // Always update UI when hitting a full second to ensure 15 is shown
            if (timer.tick % 10 == 0) {
              setState(() {
                _recordingSeconds = elapsed.round();
              });
            }

            if (elapsed >= _maxDuration) {
              timer.cancel();
              if (_isRecording) {
                await _stopVoiceRecording();
              }
            }
          }
        });
      } catch (e, stackTrace) {
        debugPrint('❌ Error starting recording: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    } else {
      debugPrint('❌ No microphone permission');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)
                .tr('errors.microphone_permission')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    debugPrint('🎙️ Stopping voice recording...');

    try {
      final path = await _voiceRecorder.stop();
      // Snappy wait for file to be fully written
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('🎙️ Recording stopped. Path: $path');

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        debugPrint('🎙️ File exists: $exists, size: $size bytes');

        if (size == 0) {
          debugPrint('⚠️ WARNING: Recorded file is empty!');
        }
      } else {
        debugPrint('⚠️ WARNING: No path returned from recorder');
      }
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
    }

    _recordingTimer?.cancel();
    _updatePreviewState();
  }

  String _formatRecordingTime() {
    final hours = _recordingSeconds ~/ 3600;
    final minutes = (_recordingSeconds % 3600) ~/ 60;
    final seconds = _recordingSeconds % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  // Type selector removed - text-only mode

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _updatePreviewState();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Color> _getGradientForMood(String mood) {
    switch (mood) {
      case 'Romantique':
        return const [
          Color(0xFFC7CEEA),
          Color(0xFF9B98E6),
        ];
      case 'Curieux':
        return const [
          Color(0xFFFFC700),
          Color(0xFFD89736),
        ];
      case 'Joyeux':
        return const [
          Color(0xFF9ECFD4),
          Color(0xFF65ADA9),
        ];
      case 'Taquin':
        return const [
          Color(0xFFFF9F9B),
          Color(0xFFFF6D68),
        ];
      default:
        // Default warm gradient
        return const [
          Color(0xFFD4C5D8),
          Color(0xFFFAF1D0),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _getGradientForMood(_selectedMood),
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            Column(
              children: [
                const SizedBox(height: 18),

                // Header with type selector and actions
                _buildHeader(),

                const SizedBox(height: 24),

                // Mood selector
                _buildMoodSelector(),

                const Spacer(),

                // Content area based on type
                _buildContentArea(),

                if (widget.replyToBottleId == null) ...[
                  const SizedBox(height: 16),
                  // Targeting Options Button
                  _buildTargetingButton(),
                ],

                const SizedBox(height: 16),

                // Preview button
                _buildPreviewButton(),

                const SizedBox(height: 32),
              ],
            ),
            if (_uploadProgress > 0 && _uploadProgress < 1.0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(value: _uploadProgress),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).tr('dialogs.cancel'),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF363636),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    final selectedMoodInfo =
        _moods.firstWhere((m) => m['name'] == _selectedMood);
    final selectedColor = selectedMoodInfo['color'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).tr('send_bottle.choose_mood'),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF151515),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _moods.map((mood) {
              final isSelected = mood['name'] == _selectedMood;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood['name'];
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mood['color'],
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: Container(
                        color: mood['color'],
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/icons/${mood['icon']}',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedMood,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selectedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    // Always show text input - removed type selector
    return _buildTextInput();
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _messageController,
            maxLines: null,
            maxLength: 400,
            decoration: InputDecoration(
              hintText:
                  AppLocalizations.of(context).tr('send_bottle.start_typing'),
              hintStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF363636),
                height: 1.5,
              ),
              border: InputBorder.none,
              suffixIcon: (!_statusLoaded || _isPremiumOrWoman) ? null : GestureDetector(
                onTap: () async {
                  final purchased = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PurchaseScrollsScreen(),
                    ),
                  );
                  if (purchased == true) {
                    _loadScrollCount();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '($_remainingScrolls)',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/images/letter.png',
                        width: 24,
                        height: 24,
                      ),
                    ],
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF151515),
              height: 1.5,
            ),
          ),
          Container(height: 1, color: const Color(0xFF0AC5C5)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPictureInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Image preview or placeholder
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 231,
              decoration: BoxDecoration(
                color:
                    _selectedImageFile != null ? null : const Color(0xFFE3E3E3),
                borderRadius: BorderRadius.circular(16),
                image: _selectedImageFile != null
                    ? DecorationImage(
                        image: FileImage(_selectedImageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImageFile == null
                  ? const Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Color(0xFF737373),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // Caption input
          TextField(
            controller: _captionController,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'Add caption',
              hintStyle: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF363636),
              ),
              border: InputBorder.none,
              counterText: '',
            ),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF151515),
            ),
          ),
          Container(height: 1, color: const Color(0xFF0AC5C5)),
          const SizedBox(height: 8),
          const Text(
            'Max character length: 40',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Recording time display
          if (_recordingSeconds > 0)
            Text(
              _formatRecordingTime(),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151515),
              ),
            ),
          if (_recordingSeconds > 0) const SizedBox(height: 24),

          // Record button
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE3E3E3), width: 1.6),
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.black : Colors.red,
                    borderRadius: _isRecording
                        ? BorderRadius.circular(4)
                        : BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Animated waveform when recording
          if (_isRecording) ...[
            const SizedBox(height: 24),
            AnimatedWaveform(
              isAnimating: _isRecording,
              color: const Color(0xFF0AC5C5),
              barCount: 30,
              height: 60,
              barWidth: 3,
              spacing: 2,
            ),
            const SizedBox(height: 16),
          ],

          Text(
            _isRecording ? AppLocalizations.of(context).tr('recording.label', params: {'time': _recordingSeconds.toString()}) : 'Start Recording',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF363636),
            ),
          ),
          if (!_isRecording && _recordingSeconds > 0 && _recordingSeconds < _minDuration) ...[
            const SizedBox(height: 8),
            const Text(
              'Voice message must be at least 5 seconds',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetingButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => TargetingOptionsModal(
              currentAgeRange: _ageRange,
              currentGenders: _targetGenders,
              currentDepartments: _targetDepartments,
              onApply: (ageRange, genders, departments) {
                setState(() {
                  _ageRange = ageRange;
                  _targetGenders = genders;
                  _targetDepartments = departments;
                });
              },
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)
                        .tr('send_bottle.targeting_criteria'),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTargetingSummary(),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Color(0xFF363636),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.filter_list_rounded,
                  size: 24, color: Color(0xFF151515)),
            ],
          ),
        ),
      ),
    );
  }

  String _getTargetingSummary() {
    List<String> parts = [];

    // Age Range
    final ageStr =
        '${_ageRange.start.round()}-${_ageRange.end.round()} ${AppLocalizations.of(context).tr('common.years_short')}';
    parts.add(ageStr);

    // Genders
    if (_targetGenders.isEmpty) {
      parts.add(
          AppLocalizations.of(context).tr('send_bottle.targeting_summary_all'));
    } else {
      parts.add(_targetGenders
          .map((g) => AppLocalizations.of(context)
              .tr('targeting.gender_${g.toLowerCase().replaceAll('-', '')}'))
          .join(', '));
    }

    // Departments
    if (_targetDepartments.isEmpty) {
      parts.add(AppLocalizations.of(context)
          .tr('send_bottle.targeting_summary_france'));
    } else {
      parts.add(AppLocalizations.of(context).tr(
          'send_bottle.targeting_summary_depts',
          params: {'count': _targetDepartments.length.toString()}));
    }

    return parts.join(' • ');
  }

  Widget _buildPreviewButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _canPreview ? _showPreview : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canPreview ? const Color(0xFF0AC5C5) : const Color(0xFFE3E3E3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            AppLocalizations.of(context).tr('common.preview'),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _canPreview ? Colors.white : const Color(0xFF737373),
            ),
          ),
        ),
      ),
    );
  }

  void _showPreview() {
    // Text-only mode
    String content = _messageController.text;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while sending
      barrierColor: const Color(0x33000000),
      // No StatefulBuilder needed, PreviewModal handles state now
      builder: (context) => PreviewModal(
        content: content,
        mood: _selectedMood,
        type: 'Text', // Always text type
        imagePath: null,
        audioPath: null,
        // _isSending is controlled internally by PreviewModal for UI,
        // but we pass _sendBottle which does the work.
        isLoading: false, // Initial state
        onSend: _sendBottle, // Pass the function directly
      ),
    );
  }

  Future<void> _sendBottle() async {
    if (_isSending) return; // Prevent double-send

    setState(() {
      _isSending = true;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final isPremiumOrWoman =
          await EntitlementsService().isPremiumOrWoman(currentUser.id);

      // Check limits
      bool canSend = false;
      if (isPremiumOrWoman) {
        canSend = true; // Unlimited bottles for Premium/Women!
      } else {
        canSend = await _databaseService.hasAvailableScrolls(currentUser.id);
      }

      if (!canSend) {
        setState(() => _isSending = false);
        if (!mounted) return;
        _showOutOfScrollsDialog(context);
        return;
      }

      // Text-only mode - always 'text' type
      String contentType = 'text';

      String? uploadedPhotoUrl;
      String? uploadedAudioUrl;
      if (contentType == 'photo' && _selectedImageFile != null) {
        final userId = currentUser.id;
        final taskId = DateTime.now().millisecondsSinceEpoch.toString();
        final uploadStatus = await _uploadController.enqueue(UploadTask(
            id: taskId,
            bucket: 'content_images',
            userId: userId,
            file: _selectedImageFile!,
            prefix: 'content'));

        if (!uploadStatus.completed || uploadStatus.url == null) {
          throw Exception('Image upload failed');
        }

        uploadedPhotoUrl = uploadStatus.url;
        await _databaseService.insertImageMetadata(
          ownerId: userId,
          bucket: 'content_images',
          path: UploadService.buildPath(
              userId: userId,
              prefix: 'content',
              ext: _selectedImageFile!.path.split('.').last),
          url: uploadedPhotoUrl!,
          entityType: 'bottle_photo',
          visibility: 'public',
        );
      }

      if (contentType == 'voice' && _voicePath != null) {
        final userId = currentUser.id;
        final taskId = DateTime.now().millisecondsSinceEpoch.toString();
        final uploadStatus = await _uploadController.enqueue(UploadTask(
            id: taskId,
            bucket: 'voice_clips',
            userId: userId,
            file: File(_voicePath!),
            prefix: 'voice'));

        if (!uploadStatus.completed || uploadStatus.url == null) {
          throw Exception('Audio upload failed');
        }

        uploadedAudioUrl = uploadStatus.url;
      }

      // 1. Deduct scroll (Verify and consume) - ONLY if not an unlimited premium/woman
      if (!_isPremiumOrWoman) {
        final deducted = await _databaseService.deductScroll(currentUser.id);
        if (!deducted) {
          setState(() => _isSending = false);
          if (!mounted) return;
          // Show out of scrolls again if it somehow changed
          _showOutOfScrollsDialog(context);
          return;
        }
        // Update local UI count
        setState(() {
          if (_remainingScrolls > 0) _remainingScrolls--;
        });
      }

      // 2. Create sent bottle in database
      final bottleId = await _databaseService.createSentBottle(
        senderId: currentUser.id,
        contentType: contentType,
        message: contentType == 'text'
            ? _messageController.text
            : contentType == 'photo'
                ? _captionController
                    .text // Save caption in message field for photos
                : null,
        mood: _selectedMood,
        audioUrl: contentType == 'voice' ? uploadedAudioUrl : null,
        photoUrl: uploadedPhotoUrl,
        targetMinAge: _ageRange.start.round(),
        targetMaxAge: _ageRange.end.round(),
        targetGender: _targetGenders,
        targetDepartments: _targetDepartments,
      );

      if (bottleId == null) {
        throw Exception('Failed to create bottle');
      }

      // Increment counter (without deduction now, since it's done)
      await _databaseService.incrementDailyBottles(currentUser.id);

      // Check if this is a reply to a bottle
      final isReply =
          widget.replyToBottleId != null && widget.replyToUserId != null;

      String? recipientId;
      String? conversationId; // Only assigned in isReply block

      if (isReply) {
        // This is a reply - send directly to the original sender
        recipientId = widget.replyToUserId!;

        // Create or get existing conversation (will throw on error)
        conversationId = await _databaseService.createConversation(
          userAId: currentUser.id,
          userBId: recipientId,
        );

        debugPrint('✅ Reply conversation created/found: $conversationId');

        // 1. Fetch original bottle content to insert as first message
        if (widget.replyToBottleId != null) {
          final originalBottle =
              await _databaseService.getReceivedBottle(widget.replyToBottleId!);

          if (originalBottle != null) {
            // Check if conversation is empty (newly created)
            final existingMessages =
                await _databaseService.getMessages(conversationId);

            if (existingMessages.isEmpty) {
              // Insert original bottle as first message (text-only)
              await _databaseService.sendMessage(
                conversationId: conversationId,
                senderId: originalBottle.senderId ?? widget.replyToUserId!,
                type: 'text',
                text: originalBottle.message,
                mood: originalBottle.mood,
                feelingDelta: 5,
              );
            }
          }
        }

        // 2. Send the reply content (current message)
        await _databaseService.sendMessage(
          conversationId: conversationId,
          senderId: currentUser.id, // Me
          type: contentType,
          text: contentType == 'text' ? _messageController.text : null,
          mediaUrl:
              contentType == 'photo' ? uploadedPhotoUrl : uploadedAudioUrl,
          feelingDelta: 5,
        );

        debugPrint('✅ Reply sent to conversation: $conversationId');

        // 3. Mark the original received bottle as replied
        if (widget.replyToBottleId != null) {
          await _databaseService.markBottleAsReplied(widget.replyToBottleId!);
          debugPrint('✅ Marked bottle as replied: ${widget.replyToBottleId}');

          // 4. Mark the original SENT bottle as replied (for the sender's UI)
          try {
            final receivedBottle = await _databaseService
                .getReceivedBottle(widget.replyToBottleId!);
            if (receivedBottle != null && receivedBottle.senderId != null) {
              // Fetch the sent_bottle_id from the received bottle
              final sentBottleData = await Supabase.instance.client
                  .from('received_bottles')
                  .select('sent_bottle_id')
                  .eq('id', widget.replyToBottleId!)
                  .maybeSingle();

              if (sentBottleData != null &&
                  sentBottleData['sent_bottle_id'] != null) {
                await _databaseService.markSentBottleAsReplied(
                    sentBottleData['sent_bottle_id'] as String);
                debugPrint(
                    '✅ Marked sent bottle as replied: ${sentBottleData['sent_bottle_id']}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Could not mark sent bottle as replied: $e');
            // Non-critical, continue with flow
          }
        }

        // 5. Navigate to Chat Screen
        if (mounted) {
          debugPrint('🔍 Navigating to conversation: $conversationId');

          // Clear intermediate screens (BottleDetail, etc.) and go to Home
          Navigator.popUntil(context, (route) => route.isFirst);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatConversationScreen(
                contactName: recipientId != null ? 'Someone' : AppLocalizations.of(context).tr('send_bottle.sea_soul_name'),
                conversationId: conversationId!,
                isUnlocked: false,
                partnerId: recipientId,
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).tr('send_bottle.reply_sent_success')),
              backgroundColor: const Color(0xFF0AC5C5),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return; // Exit here - don't do matching logic
      }

      // 2. Match bottle to a recipient
      recipientId = await _matchingService.matchBottle(
        bottleId: bottleId,
        senderId: currentUser.id,
      );

      if (recipientId == null) {
        // No match found - bottle is now in 'pending' status
        if (mounted) {
          setState(() {
            _isSending = false;
          });

          // Close preview modal if open
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          // Show Pending Dialog
          await _showPendingDialog(context);

          // Return home as it's a successful 'pending' send
          if (mounted) {
            Navigator.pop(context);
          }
        }
        return;
      }

      // 3. Create received bottle for recipient
      final receivedBottleId = await _databaseService.createReceivedBottle(
        bottleId: bottleId,
        receiverId: recipientId,
        senderId: currentUser.id,
        contentType: contentType,
        message: contentType == 'text' ? _messageController.text : null,
        caption: contentType == 'photo' ? _captionController.text : null,
        mood: _selectedMood,
        audioUrl: contentType == 'voice' ? uploadedAudioUrl : null,
        photoUrl: uploadedPhotoUrl,
      );

      if (receivedBottleId == null) {
        throw Exception('Failed to create received bottle for recipient');
      }

      // 4. Schedule delivery (floating in sea effect) - only for non-replies
      if (!isReply) {
        await _matchingService.scheduleBottleDelivery(
          bottleId: bottleId,
          senderId: currentUser.id,
          recipientId: recipientId,
          isImmediate: isPremiumOrWoman, // ⚡ Instant delivery for Premium!
        );
      }

      // 5. Increment counters
      await _databaseService.incrementBottleCounters(
        senderId: currentUser.id,
        receiverId: recipientId,
      );

      // 6. Update last active
      await _databaseService.updateLastActive(currentUser.id);

      // Success!
      if (mounted) {
        setState(() {
          _isSending = false;
        });

        // Clear all input fields
        _messageController.clear();
        _captionController.clear();
        _selectedImageFile = null;
        _voicePath = null;
        _selectedMood = 'Dreamy';
        // Type is always 'Text' now - removed _selectedType
        _canPreview = false;

        if (isReply) {
          // Close preview modal
          Navigator.pop(context);
          // Navigate back and show success message
          Navigator.pop(context); // Close send bottle screen
          Navigator.pop(context); // Close bottle detail screen
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).tr('send_bottle.reply_sent_success')),
              backgroundColor: const Color(0xFF0AC5C5),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Close preview modal first
          Navigator.pop(context);

          // Play Sent Bottle Video Animation
          await Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => SentBottleVideoModal(
                onComplete: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Close video modal
                  }
                },
              ),
            ),
          );

          // Return to home after animation
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      // Error handling
      if (mounted) {
        setState(() {
          _isSending = false;
        });

        // Close preview modal if open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).tr('errors.send_bottle_failed')}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showPendingDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).tr('send_bottle.pending_title'),
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).tr('send_bottle.pending_message'),
            style: const TextStyle(
              fontFamily: 'Montserrat',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).tr('common.continue'),
                style: const TextStyle(
                  color: Color(0xFF0AC5C5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOutOfScrollsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).tr('send_bottle.out_of_scrolls_title'),
              style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723))),
          content: Text(
              AppLocalizations.of(context).tr('send_bottle.out_of_scrolls_message'),
              style: const TextStyle(
                  fontFamily: 'Montserrat', color: Color(0xFF5D4037))),
          actions: [
            TextButton(
                child: Text(AppLocalizations.of(context).tr('dialogs.cancel')),
                onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE4C687)),
              child: Text(AppLocalizations.of(context).tr('send_bottle.get_scrolls_button'),
                  style: const TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PurchaseScrollsScreen()),
                );

                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .tr('purchase_scrolls.success')),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
