import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../widgets/custom_button.dart';
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
import '../premium_screen.dart';
import '../naughty_questions_screen.dart';
import '../../services/notification_service.dart';

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
  bool _isSaving = false; // Track if message is being sent
  bool _isPhotoRevealed = false;
  bool _hasAutoShownNaughty = false;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isPlayingVoice = false;
  String? _playingVoiceId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _feelingPercent = 0;
  String? _threadTitle;
  String? _partnerAvatarUrl;
  late final FeelingController _feelingController;
  // Milestone tracking
  final Set<int> _shownMilestones = {}; // Track which milestones have been shown
  int _previousFeelingPercent = 0;

  List<ChatMessage> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  String _currentMood = 'Curious';
  
  // Store conversation data for feeling bar
  Conversation? _conversation;
  bool _isPremium = false; // Track if user has premium subscription

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
      
      // Get current user ID for message alignment
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        _db.markMessagesAsRead(widget.conversationId!, currentUserId);
      }
      
      // Subscribe to new messages in realtime
      _db.subscribeMessages(widget.conversationId!).listen((messageData) {
        if (mounted) {
          debugPrint('📨 Received new message via realtime: ${messageData['text']}');
          debugPrint('   Message ID: ${messageData['id']}');
          debugPrint('   Created at: ${messageData['created_at']}');
          
          final newMessage = ChatMessage.fromJson(messageData, currentUserId: currentUserId);
          
          setState(() {
            // Check if message already exists by ID
            final existingIndex = _messages.indexWhere((m) => m.id == newMessage.id);
            
            if (existingIndex == -1) {
              // Message doesn't exist, add it
              _messages.add(newMessage);
              
              // Sort by timestamp to maintain chronological order
              _messages.sort((a, b) => a.createdAt.millisecondsSinceEpoch
                  .compareTo(b.createdAt.millisecondsSinceEpoch));
              
              debugPrint('✅ Added new message. Total messages: ${_messages.length}');
            } else {
              debugPrint('⚠️ Message already exists at index $existingIndex, skipping');
            }
          });
          _scrollToBottom();
          
          // Refresh conversation state (feeling percent) whenever a message arrives
          // This serves as a robust fallback if 'conversations' realtime updates are flaky
          _loadConversation();
        }
      });
      
      // Subscribe to conversation changes to update feeling bar
      _db.subscribeConversation(widget.conversationId!).listen((row) {
        if (mounted) {
          debugPrint('📊 Received conversation update via realtime: feeling=${row['feeling_percent']}');
          // Also check/mark read status if new messages came
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            _db.markMessagesAsRead(widget.conversationId!, currentUserId);
          }
          
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
    
    // Load premium status
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        final tier = await _db.getUserTier(userId);
        if (mounted) {
          setState(() {
            _isPremium = (tier == 'bond' || tier == 'ritual');
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading premium status: $e');
    }
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

      // Load photo reveal state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final revealedKey = 'is_photo_revealed_${widget.conversationId}';
      if (mounted) {
        setState(() {
          _isPhotoRevealed = prefs.getBool(revealedKey) ?? false;
        });
      }
      
      // Load partner avatar URL for photo reveal
      try {
        final currentUserId = AuthService().currentUser?.id;
        final partnerId = conversation.userAId == currentUserId
            ? conversation.userBId
            : conversation.userAId;
        
        final profileData = await _db.getProfile(partnerId);
        if (mounted) {
          setState(() {
            _partnerAvatarUrl = profileData?['avatar_url'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error pre-fetching partner avatar: $e');
      }

      // Load user-specific seen milestones from database
      try {
        final currentUserId = AuthService().currentUser?.id;
        final response = await Supabase.instance.client
            .from('conversations')
            .select('user_a_id, user_b_id, user_a_seen_milestones, user_b_seen_milestones, user1_naughty_answer, user2_naughty_answer')
            .eq('id', widget.conversationId!)
            .single();
        
        // Determine which user's milestones to load
        final isUserA = response['user_a_id'] == currentUserId;
        final userMilestones = isUserA 
            ? response['user_a_seen_milestones'] 
            : response['user_b_seen_milestones'];
        
        if (userMilestones != null) {
          _shownMilestones.addAll((userMilestones as List).cast<int>());
          debugPrint('📚 Loaded user-specific seen milestones: $_shownMilestones');
        }
        
        // Check if user needs to answer naughty question
        if (_feelingPercent >= 75 && _shownMilestones.contains(75)) {
          final currentUserId = AuthService().currentUser?.id;
          final isUserA = response['user_a_id'] == currentUserId;
          final userAnswer = isUserA 
              ? response['user1_naughty_answer'] 
              : response['user2_naughty_answer'];
          
          if (userAnswer == null) {
            // User hasn't answered yet
            debugPrint('⚠️ User at 75%+ but hasn\'t answered naughty question');
            
            // Check gender and premium status
            try {
              if (currentUserId != null) {
                final userProfile = await Supabase.instance.client
                    .from('profiles')
                    .select('gender, is_premium') // Assuming 'gender' column exists
                    .eq('id', currentUserId)
                    .single();
                
                final gender = userProfile['gender'] as String?;
                final isPremium = userProfile['is_premium'] as bool? ?? false;
                
                debugPrint('👤 User Gender: $gender, Premium: $isPremium');

                // Logic: Men (Free) -> content locked. Women or Premium Men -> Unlocked.
                // Assuming gender values are 'Man'/'Male' vs 'Woman'/'Female'
                final isMale = gender == 'Man' || gender == 'Male';
                
                // Check SharedPreferences to see if we already auto-shown this session/device
                final prefs = await SharedPreferences.getInstance();
                final hasSeenKey = 'has_seen_naughty_popup_${widget.conversationId}';
                final hasSeen = prefs.getBool(hasSeenKey) ?? false;

                if (isMale && !isPremium) {
                   // MALE + FREE = LOCKED
                   // Show Premium Screen instead of Question Screen
                   Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !hasSeen) {
                        prefs.setBool(hasSeenKey, true);
                       debugPrint('🔒 Premium Gate: Redirecting male user to Premium Screen');
                       Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const PremiumScreen()),
                       );
                    }
                   });
                } else {
                  // FEMALE or PREMIUM MALE = UNLOCKED
                   Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !hasSeen) {
                      prefs.setBool(hasSeenKey, true);
                      _showNaughtyQuestionsScreen();
                    }
                  });
                }
              }
            } catch (e) {
              debugPrint('Error checking gender/premium for gate: $e');
              // Fallback to showing it if check fails (safest UX) or block? 
              // Safest is to block if error implies security, but for UX let's show default or retry.
              // Let's stick to existing behavior (show) if error, to avoid softlock.
               Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _showNaughtyQuestionsScreen();
                }
              });
            }
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
              const SnackBar(
                content: Text('Answer submitted!'),
                backgroundColor: Colors.green,
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
  
  // Debug: Print raw timestamps before sorting
  debugPrint('🔍 Raw timestamps BEFORE sorting:');
  for (var i = 0; i < msgs.length && i < 5; i++) {
    debugPrint('  [$i] ${msgs[i].createdAt} | UTC: ${msgs[i].createdAt.toUtc()} | Millis: ${msgs[i].createdAt.millisecondsSinceEpoch} | Text: ${msgs[i].text?.substring(0, (msgs[i].text?.length ?? 0) > 10 ? 10 : (msgs[i].text?.length ?? 0))}');
  }
  
  // CRITICAL: Sort by millisecondsSinceEpoch for timezone-independent comparison
  // This is the STANDARD way to compare timestamps across timezones
  msgs.sort((a, b) {
    return a.createdAt.millisecondsSinceEpoch.compareTo(b.createdAt.millisecondsSinceEpoch);
  });
  
  debugPrint('✅ Messages sorted by millisecondsSinceEpoch (timezone-independent)');
  debugPrint('📝 Last 3 messages AFTER sorting:');
  if (msgs.length >= 3) {
    final last3 = msgs.sublist(msgs.length - 3);
    for (var msg in last3) {
      debugPrint('  ${msg.createdAt} | Millis: ${msg.createdAt.millisecondsSinceEpoch} | ${msg.text?.substring(0, (msg.text?.length ?? 0) > 15 ? 15 : (msg.text?.length ?? 0))}');
    }
  }
  
  setState(() {
    _messages = msgs;
  });
  _scrollToBottom();
}

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
  }

  String _formatTime(dynamic createdAt) {
  try {
    final dt = DateTime.parse(createdAt as String);
    // Convert UTC to local time
    final localTime = dt.toLocal();
    final h = localTime.hour.toString().padLeft(2, '0');
    final m = localTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              // Mood Picker Icon
              GestureDetector(
                onTap: _showMoodSelector,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFBF0), // White/cream background
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/moodpciker.jpeg',
                      width: 22,
                      height: 22,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Profile Icon / Photo Reveal
              GestureDetector(
                onTap: () {
                  if (widget.conversationId == null || _conversation == null) return;
                  
                  if (_feelingPercent >= 100 && !_isPhotoRevealed) {
                    _showPhotoReveal();
                  } else {
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
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFBF0),
                    border: Border.all(
                      color: (_feelingPercent >= 100 && !_isPhotoRevealed)
                          ? const Color(0xFF0AC5C5) // Highlight if ready to reveal
                          : const Color(0xFFE8E8E8),
                      width: (_feelingPercent >= 100 && !_isPhotoRevealed) ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: _isPhotoRevealed
                        ? ClipOval(
                            child: (_partnerAvatarUrl != null)
                                ? Image.network(
                                    _partnerAvatarUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    },
                                    errorBuilder: (context, error, stackTrace) => 
                                        const Icon(Icons.person, color: Color(0xFF0AC5C5)),
                                  )
                                : const Icon(Icons.person, color: Color(0xFF0AC5C5)),
                          )
                        : (_feelingPercent >= 100)
                            ? const Icon(Icons.card_giftcard, size: 22, color: Color(0xFF0AC5C5))
                            : Image.asset(
                                'assets/icons/profile.jpeg',
                                width: 22,
                                height: 22,
                                fit: BoxFit.cover,
                              ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showRenameDialog,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_conversation?.title != null && _conversation!.title!.isNotEmpty)
                                  ? _conversation!.title!
                                  : (widget.isUnlocked 
                                      ? widget.contactName 
                                      : (_conversation?.getPartnerMask(AuthService().currentUser?.id ?? '') ?? widget.contactName)),
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
                    ),
                    IconButton(
                      onPressed: _showConnectionLevel,
                      icon: const Icon(Icons.insights,
                          size: 20, color: Color(0xFF363636)),
                    ),
                  ],
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

  void _showRenameDialog() {
    final TextEditingController renameController = TextEditingController(
      text: (_conversation?.title != null && _conversation!.title!.isNotEmpty)
          ? _conversation!.title!
          : (widget.isUnlocked 
              ? widget.contactName 
              : (_conversation?.getPartnerMask(AuthService().currentUser?.id ?? '') ?? widget.contactName))
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nickname', style: TextStyle(fontFamily: 'Montserrat')),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter a nickname',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).tr('dialogs.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0AC5C5)),
            onPressed: () async {
              final newName = renameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  if (widget.conversationId != null) {
                    await DatabaseService().renameConversation(widget.conversationId!, newName);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nickname updated!')),
                    );
                    // Refresh conversation to show new name in header if possible, 
                    // or just rely on state update.
                    _loadConversation(); 
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
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
      case 'Curieux':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC700), Color(0xFFD89736)],
        );
      case 'Taquin':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)],
        );
      case 'Romantique':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
      case 'Joyeux':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9ECFD4), Color(0xFF65ADA9)],
        );
      case 'naughty_question':
      case 'naughty_answer':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)], // Same as 'Taquin' (Naughty)
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
    // Use message's saved mood if available, otherwise use default 'Curious' for old messages
    // Never use _currentMood as fallback to prevent changing colors of old messages
    final messageMood = message.mood ?? 'Curious';
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
    } else if (message.mood == 'naughty_question') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                'Question Flirt',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.text ?? '',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Color(0xFF151515),
            ),
          ),
        ],
      );
    } else if (message.mood == 'naughty_answer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réponse:',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.text ?? '',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
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
          Row(
            children: [
              GestureDetector(
                onTap: (_isPremium || _feelingPercent >= 75)
                    ? _showAttachmentOptions
                    : null,
                child: Icon(
                  Icons.camera_alt,
                  size: 24,
                  color: (_isPremium || _feelingPercent >= 75)
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
                          onTap: _insertQuote,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.format_quote,
                                size: 20, color: Color(0xFF737373)),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: true,
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
                        onTap: (_isPremium || _feelingPercent >= 75)
                            ? _showVoiceRecorder
                            : null,
                        child: Icon(
                          Icons.mic,
                          size: 20,
                          color: (_isPremium || _feelingPercent >= 75)
                              ? const Color(0xFF737373)
                              : const Color(0xFFE3E3E3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: (_isPremium || _feelingPercent >= 75)
                            ? _showImagePicker
                            : null,
                        child: Icon(
                          Icons.image,
                          size: 20,
                          color: (_isPremium || _feelingPercent >= 75)
                              ? const Color(0xFF737373)
                              : const Color(0xFFE3E3E3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Larger hit area for send button
              InkWell(
                onTap: (_isTyping && !_isSaving) ? _sendMessage : null,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(4), // Increases hit area
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: (_isTyping)
                          ? const LinearGradient(
                              colors: [Color(0xFF0AC5C5), Color(0xFF08A3A3)])
                          : LinearGradient(colors: [
                              const Color(0xFF0AC5C5).withValues(alpha: 0.5),
                              const Color(0xFF08A3A3).withValues(alpha: 0.5)
                            ]),
                      shape: BoxShape.circle,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 24),
                  ),
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
        type: 'quote', // Treat as text for DB compatibility if needed, or 'quote'
        text: '“A shared moment matters more.”',
        mood: _currentMood,
      );
    }
  }


  Future<void> _checkMilestones() async {
    if (widget.conversationId == null) return;
    
    debugPrint('🎯 Checking milestones: current=$_feelingPercent, previous=$_previousFeelingPercent');
    
    // Load seen milestones from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'seen_milestones_${widget.conversationId}';
    final seenList = prefs.getStringList(seenKey) ?? [];
    final seenSet = seenList.map(int.parse).toSet();
    
    // Check if we've crossed any milestone thresholds
    final milestones = [25, 50, 75, 100];
    
    for (final threshold in milestones) {
      if (_feelingPercent >= threshold && !seenSet.contains(threshold)) {
        debugPrint('✅ Milestone $threshold% reached and NOT seen locally! Showing modal...');
        
        // Mark as seen immediately to prevent duplicate shows
        seenSet.add(threshold);
        await prefs.setStringList(seenKey, seenSet.map((e) => e.toString()).toList());
        
        // Also save to database (shared status)
        if (!_shownMilestones.contains(threshold)) {
          _shownMilestones.add(threshold);
          _saveMilestoneToDatabase(threshold);
        }
        
        final milestone = FeelingMilestone.fromPercentage(threshold);
        if (milestone != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
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
    if (widget.conversationId == null || _conversation == null) return;
    
    try {
      debugPrint('💾 Saving milestone $threshold% to database');
      
      // Determine which user field to update
      final currentUserId = AuthService().currentUser?.id;
      final isUserA = _conversation!.userAId == currentUserId;
      final fieldName = isUserA ? 'user_a_seen_milestones' : 'user_b_seen_milestones';
      
      await Supabase.instance.client
          .from('conversations')
          .update({
            fieldName: _shownMilestones.toList(),
          })
          .eq('id', widget.conversationId!);
      debugPrint('✅ Milestone saved to $fieldName');
    } catch (e) {
      debugPrint('❌ Error saving milestone: $e');
    }
  }

  Future<void> _showMilestoneModal(FeelingMilestone milestone) async {
    debugPrint('🎉 _showMilestoneModal called for: ${milestone.title}');
    
    // Show in-app notification for milestone unlock
    if (mounted) {
      NotificationService().show(
        context: context,
        title: '🎁 Milestone Unlocked!',
        message: milestone.title,
        icon: Text(
          milestone.icon,
          style: const TextStyle(fontSize: 32),
        ),
      );
    }
    
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
                      const SnackBar(
                        content: Text('Answer submitted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            );
          }
          // If 100% milestone, auto-trigger photo reveal dialog
          if (milestone == FeelingMilestone.heart) {
            debugPrint('❤️ 100% milestone - auto-triggering Photo Reveal');
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showPhotoReveal();
              }
            });
          }
        },
      ),
    );
    
    debugPrint('🎭 Dialog closed');
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isRevealed = false; // Internal state for this dialog session if needed, or better use a local var
          // Actually, let's use a local variable and update it.
          
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Photo Reveal',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF151515),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Photo container
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE3E3E3),
                            image: (partnerPhotoUrl != null && _isPhotoRevealed)
                                ? DecorationImage(
                                    image: NetworkImage(partnerPhotoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (partnerPhotoUrl == null || !_isPhotoRevealed)
                              ? const Icon(Icons.person,
                                  size: 120, color: Color(0xFF737373))
                              : null,
                        ),
                        if (!_isPhotoRevealed)
                          ClipOval(
                            child: Container(
                              width: 240,
                              height: 240,
                              color: Colors.black.withValues(alpha: 0.7),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.white, size: 48),
                                  SizedBox(height: 8),
                                  Text(
                                    '100% Feeling!',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isPhotoRevealed 
                        ? 'Here is your match! ✨'
                        : 'You both reached 100% feeling level! Ready to reveal the mystery?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isPhotoRevealed)
                      CustomButton(
                        text: 'Reveal Photo',
                        onPressed: () async {
                          setState(() {
                            _isPhotoRevealed = true;
                          });
                          
                          // Persist revealed state locally
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('is_photo_revealed_${widget.conversationId}', true);

                          // Also save consent/status to database if needed
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid != null) {
                            DatabaseService().upsertUserPreferences(
                              userId: uid,
                              consentPhotoReveal: true,
                            );
                          }
                          // Re-render dialog
                          setDialogState(() {});
                        },
                      )
                    else
                      CustomButton(
                        text: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSaving) return;

    final text = _messageController.text.trim();
    _messageController.clear();
    setState(() {
      _isTyping = false;
      _isSaving = true; // Show loading indicator
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.conversationId != null && userId != null) {
      try {
        // Query last message directly from messages table
        final lastMessages = await Supabase.instance.client
            .from('messages')
            .select('sender_id, text, created_at')
            .eq('conversation_id', widget.conversationId!)
            .order('created_at', ascending: false)
            .limit(1);
        
        debugPrint('🔍 Checking for exchange:');
        debugPrint('  Last message query result: $lastMessages');
        
        final lastSenderId = lastMessages.isNotEmpty 
            ? lastMessages[0]['sender_id'] as String?
            : null;
        final isExchange = lastSenderId != null && lastSenderId != userId;
        
        debugPrint('  📨 Last sender ID: $lastSenderId');
        debugPrint('  📨 Current user ID: $userId');
        debugPrint('  📨 Is exchange (different sender): $isExchange');
        
        
        // Send message to database (will appear via realtime subscription)
        await _db.sendMessage(
          conversationId: widget.conversationId!,
          senderId: userId,
          type: 'text',
          text: text,
          mood: _currentMood,
        );
        
        // Database trigger handles feeling increment automatically
        // Realtime subscription SHOULD update _feelingPercent, but we force a refresh
        // here to be completely sure the sender sees the update immediately.
        debugPrint('✅ Message sent. Forcing state refresh...');
        if (mounted) {
           Future.delayed(const Duration(milliseconds: 300), () {
             if (mounted) _loadConversation();
           });
        }
      } catch (e) {
        debugPrint('❌ Error in _sendMessage: $e');
      } finally {
        // Always reset sending state
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
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
                    _buildMoodOption('Curieux', 'curious.jpeg'),
                    _buildMoodOption('Taquin', 'playful.jpeg'),
                    _buildMoodOption('Romantique', 'dream.jpeg'),
                    _buildMoodOption('Joyeux', 'calm.jpeg'),
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

  Widget _buildMoodOption(String mood, String iconImage) {
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/$iconImage',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mood,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context).tr('dialogs.cancel'),
                              style: const TextStyle(
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
            // Database trigger will handle feeling increment automatically
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


  @override
  void dispose() {
    _msgSub?.cancel();
    _feelingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _record.dispose();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
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
