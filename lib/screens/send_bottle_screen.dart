import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/preview_modal.dart';
import '../widgets/sent_confirmation_modal.dart';
import '../widgets/animated_waveform.dart';
import 'dart:async';

/// Send Bottle Screen - Perfect implementation matching Figma screens 11-26
/// Supports Text, Picture, and Voice Chat bottle creation
class SendBottleScreen extends StatefulWidget {
  const SendBottleScreen({super.key});

  @override
  State<SendBottleScreen> createState() => _SendBottleScreenState();
}

class _SendBottleScreenState extends State<SendBottleScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _selectedType = 'Text';
  String _selectedMood = 'Dreamy';
  bool _canPreview = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _selectedImagePath;
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Dreamy', 'color': const Color(0xFF9B98E6)},
    {'name': 'Curious', 'color': const Color(0xFFD89736)},
    {'name': 'Calm', 'color': const Color(0xFF65ADA9)},
    {'name': 'Playful', 'color': const Color(0xFFFF6D68)},
  ];
  final List<String> _types = ['Text', 'Picture', 'Voice Chat'];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updatePreviewState);
    _captionController.addListener(_updatePreviewState);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _captionController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _updatePreviewState() {
    setState(() {
      if (_selectedType == 'Text') {
        _canPreview = _messageController.text.trim().isNotEmpty;
      } else if (_selectedType == 'Picture') {
        _canPreview = _selectedImagePath != null;
      } else if (_selectedType == 'Voice Chat') {
        _canPreview = _recordingSeconds > 0;
      }
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _startRecording();
      } else {
        _stopRecording();
      }
    });
  }

  void _startRecording() {
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _updatePreviewState();
  }

  String _formatRecordingTime() {
    final hours = _recordingSeconds ~/ 3600;
    final minutes = (_recordingSeconds % 3600) ~/ 60;
    final seconds = _recordingSeconds % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  void _showTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Drag handle
            Container(
              width: 80,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF737373),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ..._types.map((type) {
              final isSelected = type == _selectedType;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    _canPreview = false;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE3E3E3) : Colors.white,
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0AC5C5)
                          : const Color(0xFF737373),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

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
          _selectedImagePath = image.path;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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

            const SizedBox(height: 16),

            // Preview button
            _buildPreviewButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Type dropdown
          GestureDetector(
            onTap: _showTypeSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0AC5C5), width: 0.8),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedType,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF0AC5C5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SvgPicture.asset(
                    'assets/icons/nav_arrow_down.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF0AC5C5),
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF363636),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Show drafts
            },
            child: const Text(
              'Drafts',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0AC5C5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customize your mood:',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: _moods.map((mood) {
              final isSelected = mood['name'] == _selectedMood;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood['name'];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mood['color'],
                      border: isSelected
                          ? Border.all(color: const Color(0xFF363636), width: 2)
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_selectedType == 'Text') {
      return _buildTextInput();
    } else if (_selectedType == 'Picture') {
      return _buildPictureInput();
    } else {
      return _buildVoiceInput();
    }
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
            decoration: const InputDecoration(
              hintText: 'Start typing',
              hintStyle: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF363636),
                height: 1.5,
              ),
              border: InputBorder.none,
              counterText: '',
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
          const Text(
            'Max character length: 400',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
              height: 1.5,
            ),
          ),
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
            _isRecording ? 'Recording...' : 'Start Recording',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF363636),
            ),
          ),
        ],
      ),
    );
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
            'Preview',
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
    String content = '';
    if (_selectedType == 'Text') {
      content = _messageController.text;
    } else if (_selectedType == 'Picture') {
      content = _captionController.text;
    } else if (_selectedType == 'Voice Chat') {
      content = _formatRecordingTime();
    }

    showDialog(
      context: context,
      barrierColor: const Color(0x33000000),
      builder: (context) => PreviewModal(
        content: content,
        mood: _selectedMood,
        type: _selectedType,
        imagePath: _selectedImagePath,
        onSend: () {
          Navigator.pop(context); // Close preview
          _sendBottle();
        },
        onSaveDraft: () {
          Navigator.pop(context); // Close preview
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved as draft'),
              backgroundColor: Color(0xFF0AC5C5),
            ),
          );
        },
      ),
    );
  }

  void _sendBottle() {
    showDialog(
      context: context,
      barrierColor: const Color(0x33000000),
      builder: (context) => SentConfirmationModal(
        onClose: () {
          Navigator.pop(context); // Close modal
          Navigator.pop(context); // Return to home
        },
        onSendNew: () {
          Navigator.pop(context); // Close modal
          setState(() {
            _messageController.clear();
            _captionController.clear();
            _selectedMood = 'Dreamy';
            _selectedType = 'Text';
            _canPreview = false;
            _isRecording = false;
            _recordingSeconds = 0;
            _selectedImagePath = null;
          });
        },
      ),
    );
  }
}
