import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/warm_gradient_background.dart';
import 'chat_profile_screen.dart';
import '../../widgets/feeling_progress.dart';
import '../../services/feeling_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/upload_service.dart';
import '../../services/upload_controller.dart';
import '../../services/auth_service.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/feeling_milestone.dart';
import '../../widgets/milestone_unlock_modal.dart';
import '../naughty_questions_screen.dart';

/// Chat Conversation Screen - Individual chat with full functionality
class ChatConversationScreen extends StatefulWidget {
  final String contactName;
  final String? mood;
  final bool isUnlocked;
  final String? conversationId;

  const ChatConversationScreen({
    super.key,
    required this.contactName,
    this.mood,
    this.isUnlocked = false,
    this.conversationId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final _record = AudioRecorder();
  final DatabaseService _db = DatabaseService();

  bool _isTyping = false;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isPlayingVoice = false;
  String? _playingVoiceId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _feelingPercent = 0;
  String? _threadTitle;
  late final FeelingController _feelingController;
  bool _surpriseRequired = false;
  bool _surpriseShown = false;
  final TextEditingController _q1Controller = TextEditingController();
  final TextEditingController _q2Controller = TextEditingController();
  final TextEditingController _q3Controller = TextEditingController();
  
  // Milestone tracking
  final Set<int> _shownMilestones = {}; // Track which milestones have been shown
  int _previousFeelingPercent = 0;

  List<ChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  String _currentMood = 'Curious';
  
  // Store conversation data for feeling bar
  Conversation? _conversation;

  @override
  void initState() {
    super.initState();
    _feelingController = FeelingController();
    _feelingController.setInitial(
        percent: _feelingPercent, title: _threadTitle);
    _feelingController.addListener(() {
      final s = _feelingController.value;
      setState(() {
        _feelingPercent = s.percent;
        _threadTitle = s.title;
      });
      _checkMilestones();
    });
    Future.microtask(_checkMilestones);
    
    if (widget.conversationId != null) {
      _feelingController.subscribe(widget.conversationId!);
      _loadInitialMessages();
      _loadConversation(); // Load conversation data for feeling bar
      _msgSub = _db.subscribeMessages(widget.conversationId!).listen((row) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final msg = ChatMessage.fromJson(row, currentUserId: currentUserId);
        
        debugPrint('📨 Message received via subscription: ${msg.createdAt} - ${msg.senderId}');
        
        setState(() {
          // Check if message already exists to avoid duplicates
          final exists = _messages.any((m) => m.id == msg.id);
          if (!exists) {
            debugPrint('  ➕ Adding message to list (total will be ${_messages.length + 1})');
            // Add message
            _messages.add(msg);
            // CRITICAL: Sort by createdAt to maintain chronological order
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            debugPrint('  ✅ Messages sorted by timestamp');
          } else {
            debugPrint('  ⚠️ Message already exists, skipping');
          }
        });
        _scrollToBottom();
      });
      
      // Subscribe to conversation changes to update feeling bar
      _db.subscribeConversation(widget.conversationId!).listen((row) {
        if (mounted) {
          setState(() {
            _conversation = Conversation.fromJson(row);
            _feelingPercent = _conversation!.feelingPercent;
            _threadTitle = _conversation!.title;
          });
          _checkMilestones();
        }
      });
    }
    _uploadController = UploadController();
    _uploadController.addListener(() {
      final vals = _uploadController.statuses.values;
      if (vals.isEmpty) return;
      final p =
          vals.map((s) => s.progress).fold(0.0, (a, b) => a + b) / vals.length;
      setState(() => _uploadProgress = p);
    });
  }

  Future<void> _loadConversation() async {
    if (widget.conversationId == null) return;
    final conversation = await _db.getConversation(widget.conversationId!);
    if (conversation != null && mounted) {
      setState(() {
        _conversation = conversation;
        _feelingPercent = conversation.feelingPercent;
        _threadTitle = conversation.title;
        _previousFeelingPercent = conversation.feelingPercent; // Set initial previous
      });
      
      // Load unlocked milestones from database
      try {
        final response = await Supabase.instance.client
            .from('conversations')
            .select('unlocked_milestones, user_a_id, user1_naughty_answer, user2_naughty_answer')
            .eq('id', widget.conversationId!)
            .single();
        
        final unlockedList = response['unlocked_milestones'] as List?;
        if (unlockedList != null) {
          _shownMilestones.addAll(unlockedList.cast<int>());
          debugPrint('📚 Loaded shown milestones: $_shownMilestones');
        }
        
        // Check if user needs to answer naughty question
        if (_feelingPercent >= 75 && _shownMilestones.contains(75)) {
          final currentUserId = AuthService().currentUser?.id;
          final isUserA = response['user_a_id'] == currentUserId;
          final userAnswer = isUserA 
              ? response['user1_naughty_answer'] 
              : response['user2_naughty_answer'];
          
          if (userAnswer == null) {
            // User hasn't answered yet, show naughty questions screen
            debugPrint('⚠️ User at 75%+ but hasn\'t answered naughty question');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showNaughtyQuestionsScreen();
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading unlocked milestones: $e');
      }
      
      _feelingController.setInitial(
        percent: conversation.feelingPercent,
        title: conversation.title,
      );
    }
  }

  void _showNaughtyQuestionsScreen() {
    debugPrint('🎁 Showing Naughty Questions screen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NaughtyQuestionsScreen(
          conversationId: widget.conversationId!,
          onComplete: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Answer submitted! Waiting for your match...'),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadInitialMessages() async {
    if (widget.conversationId == null) return;
    debugPrint('🔄 Loading initial messages for conversation: ${widget.conversationId}');
    final msgs = await _db.getMessages(widget.conversationId!);
    debugPrint('📥 Loaded ${msgs.length} messages');
    for (var i = 0; i < msgs.length && i < 5; i++) {
      final preview = msgs[i].text != null && msgs[i].text!.length > 20 
          ? msgs[i].text!.substring(0, 20)
          : (msgs[i].text ?? 'no text');
      debugPrint('  Message $i: ${msgs[i].createdAt} - ${msgs[i].senderId} - $preview');
    }
    setState(() {
      _messages = msgs;
    });
    _scrollToBottom();
  }

  String _formatTime(dynamic createdAt) {
    try {
      final dt = DateTime.parse(createdAt as String);
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'pm' : 'am';
      return '$h:$m $ampm';
    } catch (_) {
      return _getCurrentTime();
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    size: 24, color: Color(0xFF151515)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showMoodSelector,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getMoodGradient(_currentMood),
                    border:
                        Border.all(color: const Color(0xFF363636), width: 1),
                  ),
                  child:
                      const Icon(Icons.palette, size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (widget.conversationId != null && _conversation != null) {
                      final currentUserId = AuthService().currentUser?.id;
                      final partnerId = _conversation!.userAId == currentUserId
                          ? _conversation!.userBId
                          : _conversation!.userAId;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatProfileScreen(
                            conversationId: widget.conversationId!,
                            partnerId: partnerId,
                            feelingPercent: _feelingPercent,
                            contactName: widget.contactName,
                            mood: widget.mood,
                          ),
                        ),
                      );
                    }
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
                              widget.isUnlocked
                                  ? (_threadTitle ?? widget.contactName)
                                  : 'Anonymous',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
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
                      IconButton(
                        onPressed: _promptRenameThread,
                        icon: const Icon(Icons.edit,
                            size: 20, color: Color(0xFF363636)),
                      ),
                      if (_feelingPercent >= 100)
                        IconButton(
                          onPressed: _showPhotoReveal,
                          icon: const Icon(Icons.photo_camera_back,
                              size: 20, color: Color(0xFF151515)),
                        ),
                      IconButton(
                        onPressed: _showConnectionLevel,
                        icon: const Icon(Icons.insights,
                            size: 20, color: Color(0xFF363636)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FeelingProgress(
            percent: _feelingPercent,
            title: _threadTitle,
            compact: true,
          ),
        ],
      ),
    );
  }

  void _showConnectionLevel() {
    // Get unlocked milestones
    final unlockedMilestones = _shownMilestones.toList()..sort();
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Feeling Level',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send messages to unlock milestones.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _feelingPercent / 100,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFE3E3E3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0AC5C5),
                      ),
                    ),
                  ),
                  Text(
                    '$_feelingPercent%',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF151515),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Dynamic milestone list
              _buildConnectionItem('Bio Reveal (25%)', unlockedMilestones.contains(25)),
              _buildConnectionItem('Secret Audio (50%)', unlockedMilestones.contains(50)),
              _buildConnectionItem('Naughty Question (75%)', unlockedMilestones.contains(75)),
              _buildConnectionItem('Photo Reveal (100%)', _feelingPercent >= 100),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
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

  Future<void> _promptRenameThread() async {
    final controller =
        TextEditingController(text: _threadTitle ?? widget.contactName);
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rename thread',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter a name',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty && widget.conversationId != null) {
    try {
      // Update database
      await Supabase.instance.client
          .from('conversations')
          .update({'title': result})
          .eq('id', widget.conversationId!);
      
      // Update local state
      setState(() {
        _threadTitle = result;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated')),
        );
      }
    } catch (e) {
      debugPrint('Error updating username: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating username: $e')),
        );
      }
    }
  }
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isMe = message.isMe;
    // Use message's mood if available, otherwise use current mood for user or widget mood for others
    final messageMood = message.mood ?? (isMe ? _currentMood : widget.mood);
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
                    widget.mood ?? widget.contactName,
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
                _formatTime(message.createdAt.toIso8601String()),
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

  Widget _buildMessageContent(ChatMessage message) {
    if (message.type == 'image') {
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
            child: message.mediaUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.mediaUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.white),
                  ),
          ),
          if (message.text != null &&
              message.text!.isNotEmpty &&
              message.text != 'Picture') ...[
            const SizedBox(height: 8),
            Text(
              message.text!,
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
    } else if (message.type == 'voice') {
      final voiceId = message.id;
      final isPlaying = _isPlayingVoice && _playingVoiceId == voiceId;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              debugPrint('🎵 Voice message tapped: $voiceId');
              debugPrint('🎵 Media URL: ${message.mediaUrl}');
              debugPrint('🎵 Currently playing: $_playingVoiceId, isPlaying: $_isPlayingVoice');
              
              try {
                if (isPlaying) {
                  // Stop playback
                  debugPrint('⏸️ Stopping playback');
                  await _audioPlayer.stop();
                  setState(() {
                    _isPlayingVoice = false;
                    _playingVoiceId = null;
                  });
                } else {
                  // Start playback
                  if (message.mediaUrl == null) {
                    debugPrint('❌ No media URL for voice message');
                    return;
                  }
                  
                  debugPrint('▶️ Starting playback from: ${message.mediaUrl}');
                  
                  // Stop any currently playing audio
                  await _audioPlayer.stop();
                  
                  setState(() {
                    _isPlayingVoice = true;
                    _playingVoiceId = voiceId;
                  });
                  
                  // Play the audio
                  await _audioPlayer.play(UrlSource(message.mediaUrl!));
                  debugPrint('✅ Audio playback started');
                  
                  // Listen for completion
                  _audioPlayer.onPlayerComplete.listen((event) {
                    debugPrint('🏁 Audio playback completed');
                    if (mounted && _playingVoiceId == voiceId) {
                      setState(() {
                        _isPlayingVoice = false;
                        _playingVoiceId = null;
                      });
                    }
                  });
                }
              } catch (e) {
                debugPrint('❌ Error playing voice message: $e');
                if (mounted) {
                  setState(() {
                    _isPlayingVoice = false;
                    _playingVoiceId = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error playing voice message: $e')),
                  );
                }
              }
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
            '${message.duration ?? 3}s',
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
        message.text ?? '',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_uploadProgress > 0 && _uploadProgress < 1.0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(value: _uploadProgress),
            ),
          if (_surpriseRequired)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLocalizations.of(context).tr('surprise.banner_required'),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFFB3748),
                ),
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: (!_surpriseRequired && _feelingPercent >= 75)
                    ? _showAttachmentOptions
                    : null,
                child: Icon(
                  Icons.camera_alt,
                  size: 24,
                  color: (!_surpriseRequired && _feelingPercent >= 75)
                      ? const Color(0xFF151515)
                      : const Color(0xFFE3E3E3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_feelingPercent >= 25)
                        GestureDetector(
                          onTap: _surpriseRequired ? null : _insertQuote,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.format_quote,
                                size: 20, color: Color(0xFF737373)),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_surpriseRequired,
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
                        onTap: (!_surpriseRequired && _feelingPercent >= 50)
                            ? _showVoiceRecorder
                            : null,
                        child: Icon(
                          Icons.mic,
                          size: 20,
                          color: (!_surpriseRequired && _feelingPercent >= 50)
                              ? const Color(0xFF737373)
                              : const Color(0xFFE3E3E3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: (!_surpriseRequired && _feelingPercent >= 75)
                            ? _showImagePicker
                            : null,
                        child: Icon(
                          Icons.image,
                          size: 20,
                          color: (!_surpriseRequired && _feelingPercent >= 75)
                              ? const Color(0xFF737373)
                              : const Color(0xFFE3E3E3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_feelingPercent >= 75)
                        GestureDetector(
                          onTap: _surpriseRequired
                              ? _showSurpriseUnlockModal
                              : _showSurprise,
                          child: const Icon(Icons.help_outline,
                              size: 20, color: Color(0xFF737373)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: (_isTyping && !_surpriseRequired) ? _sendMessage : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: (_isTyping && !_surpriseRequired)
                        ? const LinearGradient(
                            colors: [Color(0xFF0AC5C5), Color(0xFF08A3A3)])
                        : LinearGradient(colors: [
                            const Color(0xFF0AC5C5).withValues(alpha: 0.5),
                            const Color(0xFF08A3A3).withValues(alpha: 0.5)
                          ]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _insertQuote() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId ?? '',
      senderId: userId,
      type: 'quote',
      text: '“A shared moment matters more.”',
      createdAt: DateTime.now(),
      isMe: true,
      mood: _currentMood,
    );

    setState(() {
      _messages.add(msg);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _scrollToBottom();

    if (widget.conversationId != null) {
      _db.sendMessage(
        conversationId: widget.conversationId!,
        senderId: userId,
        type: 'text', // Treat as text for DB compatibility if needed, or 'quote'
        text: '“A shared moment matters more.”',
        mood: _currentMood,
      );
    }
  }

  void _showSurprise() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Surprise question',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'What is a small joy you had today?',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkMilestones() {
    print('🎯🎯🎯 _checkMilestones CALLED - current=$_feelingPercent, previous=$_previousFeelingPercent');
    debugPrint('🎯 Checking milestones: current=$_feelingPercent, previous=$_previousFeelingPercent');
    debugPrint('🎯 Shown milestones: $_shownMilestones');
    
    // Check if we've crossed any milestone thresholds
    final milestones = [25, 50, 75, 100];
    
    for (final threshold in milestones) {
      // Show milestone if:
      // 1. We're at or above the threshold
      // 2. We haven't shown it yet
      // 3. Either we just crossed it (previous < threshold) OR this is first check (previous == current)
      final justCrossed = _feelingPercent >= threshold && _previousFeelingPercent < threshold;
      final firstCheck = _feelingPercent >= threshold && _previousFeelingPercent == _feelingPercent;
      
      if ((justCrossed || firstCheck) && !_shownMilestones.contains(threshold)) {
        
        debugPrint('✅ Milestone $threshold% reached! Showing modal...');
        _shownMilestones.add(threshold);
        
        // Save to database
        _saveMilestoneToDatabase(threshold);
        
        final milestone = FeelingMilestone.fromPercentage(threshold);
        
        if (milestone != null) {
          // Small delay to let the feeling bar animate
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('📱 Showing milestone modal for ${milestone.title}');
              _showMilestoneModal(milestone);
            }
          });
        }
        
        // Only show one milestone at a time
        break;
      }
    }
    
    _previousFeelingPercent = _feelingPercent;
  }

  Future<void> _saveMilestoneToDatabase(int threshold) async {
    if (widget.conversationId == null) return;
    
    try {
      debugPrint('💾 Saving milestone $threshold% to database');
      await Supabase.instance.client
          .from('conversations')
          .update({
            'unlocked_milestones': _shownMilestones.toList(),
          })
          .eq('id', widget.conversationId!);
      debugPrint('✅ Milestone saved');
    } catch (e) {
      debugPrint('❌ Error saving milestone: $e');
    }
  }

  Future<void> _showMilestoneModal(FeelingMilestone milestone) async {
    debugPrint('🎉 _showMilestoneModal called for: ${milestone.title}');
    
    // Get partner's data for the milestone
    String? partnerBio;
    String? partnerSecretAudioUrl;
    
    if (_conversation != null) {
      try {
        final currentUserId = AuthService().currentUser?.id;
        final partnerId = _conversation!.userAId == currentUserId
            ? _conversation!.userBId
            : _conversation!.userAId;
        
        debugPrint('📥 Fetching partner data for: $partnerId');
        
        final response = await Supabase.instance.client
            .from('profiles')
            .select('about, secret_audio_url')
            .eq('id', partnerId)
            .single();
        
        partnerBio = response['about'] as String?;
        partnerSecretAudioUrl = response['secret_audio_url'] as String?;
        
        debugPrint('✅ Partner data fetched - bio: ${partnerBio != null}, audio: ${partnerSecretAudioUrl != null}');
      } catch (e) {
        debugPrint('❌ Error fetching partner data: $e');
      }
    } else {
      debugPrint('⚠️ No conversation data available');
    }
    
    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, skipping modal');
      return;
    }
    
    debugPrint('🎭 Showing dialog for ${milestone.title}');
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MilestoneUnlockModal(
        milestone: milestone,
        partnerBio: partnerBio,
        partnerSecretAudioUrl: partnerSecretAudioUrl,
        onContinue: () {
          debugPrint('👆 Continue button pressed for ${milestone.title}');
          Navigator.of(context).pop();
          
          // If 75% milestone, navigate to naughty questions screen
          if (milestone == FeelingMilestone.gift) {
            debugPrint('🎁 75% milestone - navigating to Naughty Questions');
            
            if (widget.conversationId == null) {
              debugPrint('❌ No conversation ID available!');
              return;
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NaughtyQuestionsScreen(
                  conversationId: widget.conversationId!,
                  onComplete: () {
                    debugPrint('✅ Naughty question answered');
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Answer submitted! Waiting for your match...'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            );
          }
        },
      ),
    );
    
    debugPrint('🎭 Dialog closed');
  }

  void _showSurpriseUnlockModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final canContinue = _q1Controller.text.trim().isNotEmpty ||
                  _q2Controller.text.trim().isNotEmpty ||
                  _q3Controller.text.trim().isNotEmpty;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).tr('surprise.modal_title'),
                    style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF151515)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).tr('surprise.modal_subtitle'),
                    style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF737373)),
                  ),
                  const SizedBox(height: 16),
                  Text('1. ${AppLocalizations.of(context).tr('surprise.q1')}',
                      style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: Color(0xFF151515))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _q1Controller,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)
                            .tr('surprise.input_placeholder')),
                  ),
                  const SizedBox(height: 12),
                  Text('2. ${AppLocalizations.of(context).tr('surprise.q2')}',
                      style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: Color(0xFF151515))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _q2Controller,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)
                            .tr('surprise.input_placeholder')),
                  ),
                  const SizedBox(height: 12),
                  Text('3. ${AppLocalizations.of(context).tr('surprise.q3')}',
                      style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: Color(0xFF151515))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _q3Controller,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: AppLocalizations.of(context)
                            .tr('surprise.input_placeholder')),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: canContinue
                            ? () async {
                                // Save intimate questions to database
                                final userId = Supabase.instance.client.auth.currentUser?.id;
                                if (userId != null && widget.conversationId != null) {
                                  try {
                                    await _db.saveIntimateQuestions(
                                      conversationId: widget.conversationId!,
                                      userId: userId,
                                      question1: _q1Controller.text.trim().isNotEmpty 
                                          ? _q1Controller.text.trim() 
                                          : null,
                                      question2: _q2Controller.text.trim().isNotEmpty 
                                          ? _q2Controller.text.trim() 
                                          : null,
                                      question3: _q3Controller.text.trim().isNotEmpty 
                                          ? _q3Controller.text.trim() 
                                          : null,
                                    );
                                    debugPrint('✅ Intimate questions saved');
                                  } catch (e) {
                                    debugPrint('❌ Error saving intimate questions: $e');
                                  }
                                }
                                
                                setState(() {
                                  _surpriseRequired = false;
                                });
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(
                          AppLocalizations.of(context).tr('surprise.continue'),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: canContinue
                                ? const Color(0xFF0AC5C5)
                                : const Color(0xFF737373),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPhotoReveal() async {
    // Fetch partner's photo
    String? partnerPhotoUrl;
    try {
      if (_conversation != null) {
        final currentUserId = AuthService().currentUser?.id;
        final partnerId = _conversation!.userAId == currentUserId
            ? _conversation!.userBId
            : _conversation!.userAId;
        
        final profileData = await _db.getProfile(partnerId);
        partnerPhotoUrl = profileData?['avatar_url'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching partner photo: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Photo Reveal',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 16),
                // Photo container
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE3E3E3),
                    image: partnerPhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(partnerPhotoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: partnerPhotoUrl == null
                      ? const Icon(Icons.person,
                          size: 120, color: Color(0xFF737373))
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You both reached 100% feeling level!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons in Column instead of Row
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        if (uid != null) {
                          await DatabaseService().upsertUserPreferences(
                            userId: uid,
                            consentPhotoReveal: true,
                          );
                        }
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Reveal consent saved')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0AC5C5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Accept Reveal',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final nav = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Reveal request sent')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF0AC5C5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Request Reveal',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0AC5C5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF737373),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();
    setState(() {
      _isTyping = false;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.conversationId != null && userId != null) {
      try {
        // Query last message directly from messages table
        final lastMessages = await Supabase.instance.client
            .from('messages')
            .select('sender_id')
            .eq('conversation_id', widget.conversationId!)
            .order('created_at', ascending: false)
            .limit(1);
        
        final lastSenderId = lastMessages.isNotEmpty 
            ? lastMessages[0]['sender_id'] as String?
            : null;
        final isExchange = lastSenderId != null && lastSenderId != userId;
        
        debugPrint('📨 Last sender from messages table: $lastSenderId');
        debugPrint('📨 Current user: $userId');
        debugPrint('📨 Is exchange: $isExchange');
        
        // Add optimistic UI message immediately
        final optimisticMessage = ChatMessage(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.conversationId!,
          senderId: userId,
          text: text,
          type: 'text',
          createdAt: DateTime.now(),
          isMe: true,
          mood: _currentMood,
        );
        
        setState(() {
          _messages.add(optimisticMessage);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
        
        // Send message to database
        await _db.sendMessage(
          conversationId: widget.conversationId!,
          senderId: userId,
          type: 'text',
          text: text,
          mood: _currentMood,
        );
        
        // Increment feeling ONLY if this was an exchange
        if (isExchange) {
          debugPrint('✅ Exchange detected! Incrementing feeling by 5%');
          await _feelingController.increment(widget.conversationId!, amount: 5);
        } else {
          debugPrint('🚫 Consecutive message - no increment');
        }
      } catch (e) {
        debugPrint('❌ Error in _sendMessage: $e');
      }
    }
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMoodOption('Curious', 'Curious & Adventurous'),
                    _buildMoodOption('Playful', 'Playful & Fun'),
                    _buildMoodOption('Dreamy', 'Dreamy & Thoughtful'),
                    _buildMoodOption('Calm', 'Calm & Peaceful'),
                  ],
                ),
              ),
            ),
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
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && widget.conversationId != null) {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Enqueue upload
          await _uploadController.enqueue(UploadTask(
              id: id,
              bucket: 'content_images',
              userId: user.id,
              file: File(photo.path),
              prefix: 'content'));
          // Wait for upload to complete
          while (_uploadController.statuses[id]?.completed != true) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          final st = _uploadController.statuses[id];
          final mediaUrl = st?.url;
          
          if (mediaUrl != null) {
            // Send message to database
            await _db.sendMessage(
              conversationId: widget.conversationId!,
              senderId: user.id,
              type: 'image',
              mediaUrl: mediaUrl,
              mood: _currentMood,
            );
            
            // Insert image metadata
            await _db.insertImageMetadata(
              ownerId: user.id,
              bucket: 'content_images',
              path: UploadService.buildPath(
                  userId: user.id,
                  prefix: 'content',
                  ext: photo.path.split('.').last),
              url: mediaUrl,
              entityType: 'message_attachment',
              visibility: 'public',
            );
            
            // Add to local messages
            setState(() {
              _messages.add(ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                conversationId: widget.conversationId!,
                senderId: user.id,
                type: 'image',
                text: 'Picture',
                mediaUrl: mediaUrl,
                createdAt: DateTime.now(),
                isMe: true,
                mood: _currentMood,
              ));
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _scrollToBottom();
          } else {
            throw Exception('Upload failed - no URL returned');
          }
        }
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
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && widget.conversationId != null) {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Enqueue upload
          await _uploadController.enqueue(UploadTask(
              id: id,
              bucket: 'content_images',
              userId: user.id,
              file: File(image.path),
              prefix: 'content'));
          // Wait for upload to complete
          while (_uploadController.statuses[id]?.completed != true) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          final st = _uploadController.statuses[id];
          final mediaUrl = st?.url;
          
          if (mediaUrl != null) {
            // Send message to database
            await _db.sendMessage(
              conversationId: widget.conversationId!,
              senderId: user.id,
              type: 'image',
              mediaUrl: mediaUrl,
              mood: _currentMood,
            );
            
            // Insert image metadata
            await _db.insertImageMetadata(
              ownerId: user.id,
              bucket: 'content_images',
              path: UploadService.buildPath(
                  userId: user.id,
                  prefix: 'content',
                  ext: image.path.split('.').last),
              url: mediaUrl,
              entityType: 'message_attachment',
              visibility: 'public',
            );
            
            // Add to local messages
            setState(() {
              _messages.add(ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                conversationId: widget.conversationId!,
                senderId: user.id,
                type: 'image',
                text: 'Picture',
                mediaUrl: mediaUrl,
                createdAt: DateTime.now(),
                isMe: true,
                mood: _currentMood,
              ));
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _scrollToBottom();
          } else {
            throw Exception('Upload failed - no URL returned');
          }
        }
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

  void _sendVoiceMessage() async {
    if (_recordingPath == null) return;
    
    final duration = _recordingDuration;
    final path = _recordingPath!;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) return;

    // Optimistic UI update
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = ChatMessage(
        id: tempId,
        conversationId: widget.conversationId ?? '',
        senderId: userId,
        type: 'voice',
        voicePath: path,
        duration: duration,
        createdAt: DateTime.now(),
        isMe: true,
        mood: _currentMood,
    );
    
    setState(() {
      _messages.add(tempMsg);
      // Sort to maintain chronological order
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _scrollToBottom();
    
    // Upload and send
    if (widget.conversationId != null) {
        final file = File(path);
        final url = await _db.uploadVoiceClip(userId, file);
        if (url != null) {
            await _db.sendMessage(
                conversationId: widget.conversationId!,
                senderId: userId,
                type: 'voice',
                mediaUrl: url,
                duration: duration,
                mood: _currentMood,
            );
            // Check if this is an exchange before incrementing feeling
            _incrementFeelingIfExchange(userId, 'voice', duration: duration);
        }
    }
    
    setState(() {
      _recordingPath = null;
      _recordingDuration = 0;
    });
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
    _msgSub?.cancel();
    _feelingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _record.dispose();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  /// Only increment feeling if this is a message exchange (last message was from other user)
  Future<void> _incrementFeelingIfExchange(
    String currentUserId, 
    String messageType, 
    {String? text, int? duration}
  ) async {
    if (widget.conversationId == null) return;
    
    try {
      // Check if there are any messages in this conversation
      if (_messages.length <= 1) {
        // First message in conversation - don't increment yet
        debugPrint('🚫 First message - no increment');
        return;
      }
      
      // Find the last message before current one (skip the optimistic message we just added)
      final previousMessages = _messages.where((msg) => msg.id != _messages.last.id).toList();
      if (previousMessages.isEmpty) {
        debugPrint('🚫 No previous messages - no increment');
        return;
      }
      
      final lastMessage = previousMessages.last;
      
      // Check if last message was from the OTHER user
      if (lastMessage.senderId != currentUserId) {
        // This is an exchange! Increment feeling by 5%
        const int exchangePoints = 5;
        debugPrint('✅ Exchange detected! Incrementing feeling by $exchangePoints%');
        await _feelingController.increment(widget.conversationId!, amount: exchangePoints);
      } else {
        // User sent consecutive messages - don't increment
        debugPrint('🚫 Consecutive message from same user - no increment');
      }
    } catch (e) {
      debugPrint('❌ Error checking message exchange: $e');
    }
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
