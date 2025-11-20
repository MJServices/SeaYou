import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/warm_gradient_background.dart';
import 'chat_profile_screen.dart';

/// Chat Conversation Screen - Individual chat with full functionality
class ChatConversationScreen extends StatefulWidget {
  final String contactName;
  final String? mood;
  final bool isUnlocked;

  const ChatConversationScreen({
    super.key,
    required this.contactName,
    this.mood,
    this.isUnlocked = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final _record = AudioRecorder();

  bool _isTyping = false;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isPlayingVoice = false;
  String? _playingVoiceId;
  String _currentMood = 'Curious'; // Default mood for user messages

  late final List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    // Initialize with the other person's message first (as per Figma design)
    _messages = [
      {
        'text':
            'Hi. Prior to our previous conversation, I saw the river you mentioned while taking a walk after a pretty chill day. The sight was truly amazing as you described. The sun on the river was beautiful as you described. \n\nI could attach a picture I took of it if you do not mind. Let me know if you\'ll be willing to rate my non-photography skill.',
        'isMe': false,
        'time': '11:02 am',
        'type': 'text',
        'label':
            widget.mood != null ? '${widget.mood} 001' : widget.contactName,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildMessagesList(),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                size: 24, color: Color(0xFF151515)),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _showMoodSelector,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getMoodGradient(_currentMood),
                border: Border.all(color: const Color(0xFF363636), width: 1),
              ),
              child: const Icon(
                Icons.palette,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatProfileScreen(
                      contactName: widget.contactName,
                      mood: widget.mood,
                      isUnlocked: widget.isUnlocked,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isUnlocked ? widget.contactName : 'Anonymous',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF151515),
                          ),
                        ),
                        if (!widget.isUnlocked)
                          const Text(
                            'Online',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF0AC5C5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showConnectionLevel,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getMoodGradient(widget.mood),
                border: Border.all(color: const Color(0xFF363636), width: 1),
              ),
              child: const Center(
                child: Text(
                  '75%',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionLevel() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connection Level',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send messages to unlock connection.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 24),
              const Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: 0.75,
                      strokeWidth: 8,
                      backgroundColor: Color(0xFFE3E3E3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0AC5C5),
                      ),
                    ),
                  ),
                  Text(
                    '75%',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF151515),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildConnectionItem('Message', true),
              _buildConnectionItem('Photo', true),
              _buildConnectionItem('Voice Chat', true),
              _buildConnectionItem('Any random thing', false),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF0AC5C5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionItem(String label, bool isUnlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.check_circle : Icons.lock,
            size: 16,
            color:
                isUnlocked ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: isUnlocked
                  ? const Color(0xFF363636)
                  : const Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.isUnlocked) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE3E3E3),
        ),
        child: const Icon(Icons.person, color: Color(0xFF737373), size: 24),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getMoodGradient(widget.mood),
        ),
      );
    }
  }

  LinearGradient _getMoodGradient(String? mood) {
    switch (mood) {
      case 'Curious':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC700), Color(0xFFD89736)],
        );
      case 'Playful':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)],
        );
      case 'Dreamy':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
      case 'Calm':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9ECFD4), Color(0xFF65ADA9)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
    }
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    bool isMe = message['isMe'];
    // Use message's mood if available, otherwise use current mood for user or widget mood for others
    final messageMood = message['mood'] ?? (isMe ? _currentMood : widget.mood);
    final gradient = _getMoodGradient(messageMood);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Expanded(
                  child: Text(
                    message['label'] ?? (widget.mood ?? widget.contactName),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF363636),
                    ),
                  ),
                ),
              ],
              if (isMe) ...[
                const Expanded(
                  child: Text(
                    'You',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF363636),
                    ),
                  ),
                ),
              ],
              Text(
                message['time'],
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF363636),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildMessageContent(message),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message) {
    if (message['type'] == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: message['imagePath'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(message['imagePath']),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.white),
                  ),
          ),
          if (message['text'] != null &&
              message['text'].isNotEmpty &&
              message['text'] != 'Picture') ...[
            const SizedBox(height: 8),
            Text(
              message['text'],
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF151515),
              ),
            ),
          ],
        ],
      );
    } else if (message['type'] == 'voice') {
      final voiceId = message['voicePath'] ?? message['time'];
      final isPlaying = _isPlayingVoice && _playingVoiceId == voiceId;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isPlaying) {
                  _isPlayingVoice = false;
                  _playingVoiceId = null;
                } else {
                  _isPlayingVoice = true;
                  _playingVoiceId = voiceId;
                  // Auto stop after 3 seconds (simulated)
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _playingVoiceId == voiceId) {
                      setState(() {
                        _isPlayingVoice = false;
                        _playingVoiceId = null;
                      });
                    }
                  });
                }
              });
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: const Color(0xFF151515),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildVoiceWaveform(isPlaying),
          const SizedBox(width: 8),
          Text(
            message['duration'] ?? '0:03',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF151515),
            ),
          ),
        ],
      );
    } else {
      return Text(
        message['text'],
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF151515),
        ),
      );
    }
  }

  Widget _buildVoiceWaveform(bool isAnimating) {
    return SizedBox(
      width: 80,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(12, (index) {
          return _VoiceWaveBar(
            isAnimating: isAnimating,
            delay: index * 50,
            height: [
              3.0,
              8.0,
              12.0,
              16.0,
              12.0,
              8.0,
              16.0,
              12.0,
              8.0,
              12.0,
              8.0,
              3.0
            ][index],
          );
        }),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE3E3E3), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showAttachmentOptions,
            child: const Icon(Icons.camera_alt,
                size: 24, color: Color(0xFF151515)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (value) {
                        setState(() {
                          _isTyping = value.isNotEmpty;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Send a bottle',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF737373),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showVoiceRecorder,
                    child: const Icon(Icons.mic,
                        size: 20, color: Color(0xFF737373)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showImagePicker,
                    child: const Icon(Icons.image,
                        size: 20, color: Color(0xFF737373)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isTyping ? _sendMessage : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isTyping
                    ? const LinearGradient(
                        colors: [Color(0xFF0AC5C5), Color(0xFF08A3A3)],
                      )
                    : LinearGradient(
                        colors: [
                          const Color(0xFF0AC5C5).withValues(alpha: 0.5),
                          const Color(0xFF08A3A3).withValues(alpha: 0.5),
                        ],
                      ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'text': _messageController.text.trim(),
        'isMe': true,
        'time': _getCurrentTime(),
        'type': 'text',
        'label': 'You',
        'mood': _currentMood,
      });
      _messageController.clear();
      _isTyping = false;
    });

    _scrollToBottom();
  }

  void _showMoodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Your Mood',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will change the color of your messages',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Color(0xFF737373),
              ),
            ),
            const SizedBox(height: 24),
            _buildMoodOption('Curious', 'Curious & Adventurous'),
            _buildMoodOption('Playful', 'Playful & Fun'),
            _buildMoodOption('Dreamy', 'Dreamy & Thoughtful'),
            _buildMoodOption('Calm', 'Calm & Peaceful'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodOption(String mood, String description) {
    final isSelected = _currentMood == mood;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMood = mood;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood changed to $mood'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0AC5C5),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _getMoodGradient(mood),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF151515) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mood,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0AC5C5)),
              title: const Text('Take Photo',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF0AC5C5)),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _chooseFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _messages.add({
            'text': 'Picture',
            'isMe': true,
            'time': _getCurrentTime(),
            'type': 'image',
            'label': 'You',
            'imagePath': photo.path,
            'mood': _currentMood,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _chooseFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _messages.add({
            'text': 'Picture',
            'isMe': true,
            'time': _getCurrentTime(),
            'type': 'image',
            'label': 'You',
            'imagePath': image.path,
            'mood': _currentMood,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _showVoiceRecorder() async {
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              if (_isRecording) ...[
                _RecordingAnimation(isRecording: _isRecording),
                const SizedBox(height: 24),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recording...',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
              ] else ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0AC5C5).withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 40,
                    color: Color(0xFF0AC5C5),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Voice Message',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to start recording',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            _stopRecording();
                            _recordingTimer?.cancel();
                            _recordingDuration = 0;
                          }
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF737373),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (_isRecording) {
                            await _stopRecording();
                            _recordingTimer?.cancel();
                            setModalState(() {});
                            if (mounted && context.mounted) {
                              Navigator.pop(context);
                              _sendVoiceMessage();
                            }
                          } else {
                            await _startRecording();
                            _recordingTimer = Timer.periodic(
                              const Duration(seconds: 1),
                              (timer) {
                                setModalState(() {
                                  _recordingDuration++;
                                });
                              },
                            );
                            setModalState(() {});
                          }
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0AC5C5), Color(0xFF08A3A3)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Center(
                            child: Text(
                              _isRecording ? 'Send' : 'Record',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (_isRecording) {
        _stopRecording();
        _recordingTimer?.cancel();
        _recordingDuration = 0;
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _record.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingDuration = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _record.stop();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  void _sendVoiceMessage() {
    final duration = _formatDuration(_recordingDuration);
    setState(() {
      _messages.add({
        'text': 'Voice Message',
        'isMe': true,
        'time': _getCurrentTime(),
        'type': 'voice',
        'label': 'You',
        'voicePath': _recordingPath,
        'duration': duration,
      });
      _recordingPath = null;
      _recordingDuration = 0;
    });
    _scrollToBottom();
  }

  Future<void> _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0AC5C5)),
              title: const Text('Take Photo',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF0AC5C5)),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _chooseFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _record.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }
}

// Animated voice wave bar for waveform visualization
class _VoiceWaveBar extends StatefulWidget {
  final bool isAnimating;
  final int delay;
  final double height;

  const _VoiceWaveBar({
    required this.isAnimating,
    required this.delay,
    required this.height,
  });

  @override
  State<_VoiceWaveBar> createState() => _VoiceWaveBarState();
}

class _VoiceWaveBarState extends State<_VoiceWaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isAnimating) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted && widget.isAnimating) {
          _controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_VoiceWaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
      _controller.value = 0.3;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 3,
          height: widget.height * (widget.isAnimating ? _animation.value : 1.0),
          decoration: BoxDecoration(
            color: const Color(0xFF151515).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      },
    );
  }
}

// Recording animation with pulsing circles
class _RecordingAnimation extends StatefulWidget {
  final bool isRecording;

  const _RecordingAnimation({required this.isRecording});

  @override
  State<_RecordingAnimation> createState() => _RecordingAnimationState();
}

class _RecordingAnimationState extends State<_RecordingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(_RecordingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing circle
            Container(
              width: 140 * _pulseAnimation.value,
              height: 140 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
              ),
            ),
            // Middle pulsing circle
            Container(
              width: 100 * _pulseAnimation.value,
              height: 100 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.2),
              ),
            ),
            // Inner circle with mic icon
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(
                Icons.mic,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
