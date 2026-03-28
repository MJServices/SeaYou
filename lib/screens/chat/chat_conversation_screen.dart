import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

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
import '../../services/entitlements_service.dart';

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
  final bool _hasAutoShownNaughty = false;
  bool _isInitialLoad = true; // Prevents 75% lock flicker

  // 🔒 Feeling Bar Limit State
  String? _userGender;
  bool _hasAnsweredNaughty = false;

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
  String? _partnerUsername;
  String? _partnerId;
  late final FeelingController _feelingController;
  // Milestone tracking
  final Set<int> _shownMilestones =
      {}; // Track which milestones have been shown
  int _previousFeelingPercent = 0;

  List<ChatMessage> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  String _currentMood = 'Curieux';

  // Store conversation data for feeling bar
  Conversation? _conversation;
  bool _isBlocked = false;
  bool _isPremium = false; // Track if user has premium subscription
  bool _isAccessGranted = false; // Track if user has free access (Woman) or Premium
  Map<String, dynamic>? _partnerProfile;
  StreamSubscription<Map<String, dynamic>?>? _partnerProfileSub;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

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

    // Load all critical data in parallel to avoid flickers
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final futures = <Future>[
        _loadPremiumStatus(),
        if (widget.conversationId != null) _loadConversation(),
        if (widget.conversationId != null) _loadInitialMessages(),
      ];

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error initializing chat data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }

    if (widget.conversationId != null) {
      _feelingController.subscribe(widget.conversationId!);

      // Get current user ID for message alignment
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        _db.markMessagesAsRead(widget.conversationId!, currentUserId);
      }

      // Subscribe to new messages in realtime
      _db.subscribeMessages(widget.conversationId!).listen((messageData) {
        if (mounted) {
          final eventType = messageData['event_type'];
          final messageId = messageData['id'];

          debugPrint(
              '📨 Received realtime event: $eventType for message ID: $messageId');

          setState(() {
            if (eventType == 'delete') {
              _messages.removeWhere((m) => m.id == messageId);
              debugPrint('✅ Deleted message from local list');
            } else {
              final message = ChatMessage.fromJson(messageData,
                  currentUserId: currentUserId);
              final existingIndex =
                  _messages.indexWhere((m) => m.id == message.id);

              if (eventType == 'insert' || eventType == 'INSERT') {
                if (existingIndex == -1) {
                  _messages.add(message);
                  _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  debugPrint('✅ Added new message');
                }
              } else if (eventType == 'update' || eventType == 'UPDATE') {
                if (existingIndex != -1) {
                  _messages[existingIndex] = message;
                  debugPrint('✅ Updated existing message');
                } else {
                  // If for some reason we missed the insert, add it now
                  _messages.add(message);
                  _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                }
              }
            }
          });

          if (eventType == 'insert' || eventType == 'INSERT') {
            _scrollToBottom();
          }

          // Refresh conversation state (feeling percent)
          _loadConversation();
        }
      });

      // Subscribe to conversation changes to update feeling bar
      _db.subscribeConversation(widget.conversationId!).listen((row) {
        if (mounted) {
          debugPrint(
              '📊 Received conversation update via realtime: feeling=${row['feeling_percent']}');
          // Also check/mark read status if new messages came
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            _db.markMessagesAsRead(widget.conversationId!, currentUserId);
          }

          setState(() {
            _conversation = Conversation.fromJson(row);
            _feelingPercent = _conversation!.feelingPercent;
            _threadTitle = _conversation!.title;

            // 🛡️ Ensure naughty answer state is synced from RT update too
            final isUserA = _conversation!.userAId == currentUserId;
            final userAnswer = isUserA
                ? _conversation!.user1NaughtyAnswer
                : _conversation!.user2NaughtyAnswer;
            _hasAnsweredNaughty =
                userAnswer != null && userAnswer.trim().isNotEmpty;
          });
          if (_partnerUsername == null && _conversation != null) {
            _fetchPartnerProfile();
          }
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

  Future<void> _loadPremiumStatus() async {
    try {
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        // Use EntitlementsService for centralized access logic
        final access = await EntitlementsService().isPremiumOrWoman(userId);
        
        // Fetch profile for tier (text) and gender (for local display if needed)
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('tier, gender')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            final tier = profile['tier'] as String? ?? 'free';
            _isPremium = tier == 'premium' || tier == 'elite';
            _userGender = profile['gender'] as String?;
            _isAccessGranted = access;
            debugPrint(
                '👤 Loaded User: Gender=$_userGender, Tier=$tier, Premium=$_isPremium, AccessGranted=$_isAccessGranted');
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading premium/gender status: $e');
    }
  }

  bool get _isPartnerOnline {
    if (_partnerProfile == null || _partnerProfile!['last_active'] == null) {
      return false;
    }
    try {
      final lastActiveStr = _partnerProfile!['last_active'] as String;
      final lastActive = DateTime.parse(lastActiveStr).toUtc();
      final now = DateTime.now().toUtc();
      // Consider online if active within last 2 minutes
      return now.difference(lastActive).inMinutes < 2;
    } catch (e) {
      return false;
    }
  }

  String get _lastSeenText {
    if (_partnerProfile == null || _partnerProfile!['last_active'] == null) {
      return '';
    }
    try {
      final lastActiveStr = _partnerProfile!['last_active'] as String;
      final lastActive = DateTime.parse(lastActiveStr).toUtc();
      final now = DateTime.now().toUtc();
      final diff = now.difference(lastActive);

      if (diff.inMinutes < 2) {
        return AppLocalizations.of(context).tr('chat.online_status');
      } else if (diff.inMinutes < 60) {
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${diff.inMinutes}m ago";
      } else if (diff.inHours < 24) {
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${diff.inHours}h ago";
      } else {
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${diff.inDays}d ago";
      }
    } catch (e) {
      return '';
    }
  }

  /// 🔒 Determines if the user is locked out by the 75% limit
  bool get _isPremiumLocked {
    // 1. If below 75%, never locked
    if (_feelingPercent < 75) return false;

    // 2. Centralized access logic (Premium or Woman)
    if (_isAccessGranted) {
      // Exempt users (Women/Premium) are ONLY gated by the intimacy question
      return !_hasAnsweredNaughty;
    }

    // Unprivileged users are locked at 75% by the paywall unconditionally
    return true;
  }

  Future<void> _loadConversation() async {
    if (widget.conversationId == null) return;
    final conversation = await _db.getConversation(widget.conversationId!);
    if (conversation != null && mounted) {
      setState(() {
        _conversation = conversation;
        _feelingPercent = conversation.feelingPercent;
        _threadTitle = conversation.title;
        _previousFeelingPercent =
            conversation.feelingPercent; // Set initial previous
      });

      // Load photo reveal state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final revealedKey = 'is_photo_revealed_${widget.conversationId}';
      if (mounted) {
        setState(() {
          _isPhotoRevealed = prefs.getBool(revealedKey) ?? false;
        });
      }

      await _fetchPartnerProfile();

      // 🛡️ Consolidated: Extract naughty answer & milestones directly from Conversation model
      final currentUserId = AuthService().currentUser?.id;
      final isUserA = conversation.userAId == currentUserId;

      // 1. Set seen milestones
      final userMilestones = isUserA
          ? conversation.userASeenMilestones
          : conversation.userBSeenMilestones;

      if (userMilestones != null) {
        _shownMilestones.addAll(userMilestones);
        debugPrint(
            '📚 Loaded milestones from Conversation model: $_shownMilestones');
      }

      // 2. Set naughty answer status
      final userAnswer = isUserA
          ? conversation.user1NaughtyAnswer
          : conversation.user2NaughtyAnswer;

      if (mounted) {
        setState(() {
          _hasAnsweredNaughty =
              userAnswer != null && userAnswer.trim().isNotEmpty;
          debugPrint('🔒 Naughty answer status: $_hasAnsweredNaughty');
        });
      }

      _feelingController.setInitial(
        percent: conversation.feelingPercent,
        title: conversation.title,
      );
    }
  }

  Future<void> _fetchPartnerProfile() async {
    if (_conversation == null) return;
    try {
      final currentUserId = AuthService().currentUser?.id;
      final partnerId = _conversation!.userAId == currentUserId
          ? _conversation!.userBId
          : _conversation!.userAId;

      if (partnerId == currentUserId) {
        debugPrint('⚠️ Warning: partnerId matches currentUserId');
      }

      final profileData = await _db.getProfile(partnerId);
      debugPrint(
          '🔍 ChatConversation: fetched profileData for $partnerId: $profileData');

      if (currentUserId == null) return;

      final blocked = await _db.isRelationBlocked(currentUserId, partnerId);

      if (mounted) {
        setState(() {
          _partnerId = partnerId;
          _partnerAvatarUrl = profileData?['avatar_url'] as String?;
          _partnerUsername = profileData?['full_name'] as String?;
          _isBlocked = blocked;
          debugPrint(
              '🔍 ChatConversation: set _partnerUsername to $_partnerUsername');
        });
      }

      _partnerProfileSub?.cancel();
      _partnerProfileSub = _db.profileStream(partnerId).listen((profile) {
        if (mounted) {
          setState(() {
            _partnerProfile = profile;
            if (profile != null) {
              _partnerAvatarUrl = profile['avatar_url'] as String?;
              _partnerUsername = profile['full_name'] as String?;
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error pre-fetching partner avatar or block status: $e');
    }
  }

  Future<void> _loadInitialMessages() async {
    if (widget.conversationId == null) return;
    debugPrint(
        '🔄 Loading initial messages for conversation: ${widget.conversationId}');

    final msgs = await _db.getMessages(widget.conversationId!);
    debugPrint('📥 Loaded ${msgs.length} messages');

    // Debug: Print raw timestamps before sorting
    debugPrint('🔍 Raw timestamps BEFORE sorting:');
    for (var i = 0; i < msgs.length && i < 5; i++) {
      debugPrint(
          '  [$i] ${msgs[i].createdAt} | UTC: ${msgs[i].createdAt.toUtc()} | Millis: ${msgs[i].createdAt.millisecondsSinceEpoch} | Text: ${msgs[i].text?.substring(0, (msgs[i].text?.length ?? 0) > 10 ? 10 : (msgs[i].text?.length ?? 0))}');
    }

    // CRITICAL: Sort by millisecondsSinceEpoch for timezone-independent comparison
    // This is the STANDARD way to compare timestamps across timezones
    msgs.sort((a, b) {
      return a.createdAt.millisecondsSinceEpoch
          .compareTo(b.createdAt.millisecondsSinceEpoch);
    });

    debugPrint(
        '✅ Messages sorted by millisecondsSinceEpoch (timezone-independent)');
    debugPrint('📝 Last 3 messages AFTER sorting:');
    if (msgs.length >= 3) {
      final last3 = msgs.sublist(msgs.length - 3);
      for (var msg in last3) {
        debugPrint(
            '  ${msg.createdAt} | Millis: ${msg.createdAt.millisecondsSinceEpoch} | ${msg.text?.substring(0, (msg.text?.length ?? 0) > 15 ? 15 : (msg.text?.length ?? 0))}');
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
    if (_isInitialLoad) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0AC5C5)),
          ),
        ),
      );
    }

    if (_isPremiumLocked) {
      return Scaffold(
        body: WarmGradientBackground(
          child: SafeArea(
            child: _buildLockedMilestoneView(),
          ),
        ),
      );
    }

    if (_isBlocked) {
      return Scaffold(
        body: WarmGradientBackground(
          child: SafeArea(
            child: _buildBlockedView(),
          ),
        ),
      );
    }

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

  Widget _buildLockedMilestoneView() {
    final l10n = AppLocalizations.of(context);
    final title = l10n.tr('chat.milestone_75_reached_title');
    String desc;
    String buttonText;
    VoidCallback onPressed;

    if (_isAccessGranted) {
      // locked because they haven't answered the naughty question
      desc = l10n.tr('chat.milestone_75_desc_naughty');
      buttonText = l10n.tr('chat.milestone_75_button_naughty');
      onPressed = () {
        if (widget.conversationId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NaughtyQuestionsScreen(
              conversationId: widget.conversationId!,
              onComplete: () {
                if (mounted) setState(() => _hasAnsweredNaughty = true);
                Navigator.pop(context);
              },
            ),
          ),
        );
      };
    } else {
      // locked by premium paywall — no access to naughty questions
      desc = l10n.tr('chat.milestone_75_desc_premium');
      buttonText = l10n.tr('chat.milestone_75_button_unlock');
      onPressed = _showPremiumPaywall;
    }

    return Column(
      children: [
        // Small header with back button so they can exit the chat
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    size: 24, color: Color(0xFF151515)),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Icon(Icons.lock_outline,
                  size: 80, color: Color(0xFF0AC5C5)),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Color(0xFF737373),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: buttonText,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildBlockedView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    size: 24, color: Color(0xFF151515)),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Icon(Icons.block, size: 80, color: Color(0xFFEF4444)),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.of(context).tr('chat.blocked_title') !=
                        'chat.blocked_title'
                    ? AppLocalizations.of(context).tr('chat.blocked_title')
                    : 'Conversation bloquée',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF151515),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).tr('chat.blocked_desc') !=
                        'chat.blocked_desc'
                    ? AppLocalizations.of(context).tr('chat.blocked_desc')
                    : 'Vous ne pouvez plus accéder à cette conversation car cet utilisateur a été bloqué.',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Color(0xFF151515),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
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
                    border:
                        Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
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
                  if (widget.conversationId == null || _conversation == null) {
                    return;
                  }

                  if (_feelingPercent >= 100 && !_isPhotoRevealed) {
                    _showPhotoReveal();
                    return;
                  }

                  final currentUserId = AuthService().currentUser?.id;
                  final partnerId = _conversation!.userAId == currentUserId
                      ? _conversation!.userBId
                      : _conversation!.userAId;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatProfileScreen(
                        conversationId: widget.conversationId!,
                        partnerId: _partnerId ?? partnerId,
                        feelingPercent: _feelingPercent,
                        contactName:
                            (_feelingPercent >= 100 && _partnerUsername != null)
                                ? _partnerUsername!
                                : widget.contactName,
                        mood: widget.mood,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFBF0),
                    border: Border.all(
                      color: (_feelingPercent >= 100 && !_isPhotoRevealed)
                          ? const Color(
                              0xFF0AC5C5) // Highlight if ready to reveal
                          : const Color(0xFFE8E8E8),
                      width: (_feelingPercent >= 100 && !_isPhotoRevealed)
                          ? 2.5
                          : 1.5,
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
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2));
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.person,
                                                color: Color(0xFF0AC5C5)),
                                  )
                                : const Icon(Icons.person,
                                    color: Color(0xFF0AC5C5)),
                          )
                        : (_feelingPercent >= 100)
                            ? const Icon(Icons.card_giftcard,
                                size: 22, color: Color(0xFF0AC5C5))
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _partnerUsername ?? widget.contactName,
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
                            Text(
                              _lastSeenText,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: _isPartnerOnline
                                    ? const Color(0xFF0AC5C5)
                                    : const Color(0xFF737373),
                              ),
                            ),
                        ],
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
              Text(
                AppLocalizations.of(context).tr('chat.feeling_level_title'),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).tr('chat.feeling_level_subtitle'),
                style: const TextStyle(
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
              _buildConnectionItem(
                  AppLocalizations.of(context).tr('chat.milestone_bio'),
                  unlockedMilestones.contains(25)),
              _buildConnectionItem(
                  AppLocalizations.of(context).tr('chat.milestone_audio'),
                  unlockedMilestones.contains(50)),
              _buildConnectionItem(
                  AppLocalizations.of(context).tr('chat.milestone_naughty'),
                  unlockedMilestones.contains(75)),
              _buildConnectionItem(
                  AppLocalizations.of(context).tr('chat.milestone_photo'),
                  _feelingPercent >= 100),
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: isUnlocked
                    ? const Color(0xFF363636)
                    : const Color(0xFF737373),
              ),
            ),
          ),
        ],
      ),
    );
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
          colors: [
            Color(0xFFFF9F9B),
            Color(0xFFFF6D68)
          ], // Same as 'Taquin' (Naughty)
        );
      default:
        // Handle localized naughty questions (naughty_question_1, naughty_question_2, etc.)
        if (mood != null && mood.startsWith('naughty_question_')) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)],
          );
        }
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
    // Use message's saved mood if available, otherwise use default 'Curieux' for old messages
    final messageMood = message.mood ?? 'Curieux';
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
                    _feelingPercent >= 100
                        ? (_partnerUsername ?? widget.contactName)
                        : (_conversation?.getPartnerMask(
                                Supabase.instance.client.auth.currentUser?.id ??
                                    '') ??
                            widget.contactName),
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
          GestureDetector(
            onHorizontalDragEnd: (details) {
              // Swipe right to reply
              if (details.primaryVelocity! > 500) {
                _onReply(message);
              }
            },
            onLongPress: () => _showMessageOptions(message),
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.replyToId != null)
                    _buildRepliedMessageContext(message.replyToId!),
                  _buildMessageContent(message, isMe),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
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
              try {
                if (isPlaying) {
                  await _audioPlayer.stop();
                  setState(() {
                    _isPlayingVoice = false;
                    _playingVoiceId = null;
                  });
                } else {
                  if (message.mediaUrl == null) return;
                  await _audioPlayer.stop();
                  setState(() {
                    _isPlayingVoice = true;
                    _playingVoiceId = voiceId;
                  });
                  await _audioPlayer.play(UrlSource(message.mediaUrl!));
                  _audioPlayer.onPlayerComplete.listen((event) {
                    if (mounted && _playingVoiceId == voiceId) {
                      setState(() {
                        _isPlayingVoice = false;
                        _playingVoiceId = null;
                      });
                    }
                  });
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isPlayingVoice = false;
                    _playingVoiceId = null;
                  });
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
    } else if (message.mood == 'naughty_question_intro' ||
        (message.mood != null &&
            message.mood!.startsWith('naughty_question'))) {
      // Determine if it's a specific question or the generic mood
      String questionText = message.text ?? '';
      if (message.mood!.startsWith('naughty_question_')) {
        final id = message.mood!.replaceFirst('naughty_question_', '');
        // Use translation key if it exists
        questionText = AppLocalizations.of(context).tr('surprise.q$id');
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)
                    .tr('chat.naughty_question_main_title')
                    .toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            questionText,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 16,
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
          Row(
            children: [
              const Icon(Icons.forum, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                isMe
                    ? AppLocalizations.of(context)
                        .tr('chat.naughty_question_your_answer')
                    : AppLocalizations.of(context)
                        .tr('chat.naughty_question_partner_choice'),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
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
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF151515),
            ),
          ),
        ],
      );
    } else if (message.mood?.startsWith('milestone_') ?? false) {
      final isMilestone50 = message.mood == 'milestone_50';
      final hasAudio = message.mediaUrl != null;
      final voiceId = message.id;
      final isPlaying = _isPlayingVoice && _playingVoiceId == voiceId;

      // Extract content if present (separated by |--CONTENT--|)
      String title = message.text ?? '';
      String? extraContent;
      if (title.contains('|--CONTENT--|')) {
        final parts = title.split('|--CONTENT--|');
        title = parts[0];
        extraContent = parts.length > 1 ? parts[1] : null;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).tr('common.milestone_header'),
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Only show title if there is no extra content and no audio for milestone 50
          if ((extraContent == null || extraContent.isEmpty) &&
              !(hasAudio && message.mood == 'milestone_50'))
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151515),
              ),
            ),

          // Render extra content (Bio for 25%, Photo for 100%, etc.)
          if (extraContent != null && extraContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (message.mood == 'milestone_25')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  extraContent,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF151515),
                  ),
                ),
              )
            else if (message.mood == 'milestone_75')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  extraContent,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF151515),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (message.mood == 'milestone_100')
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (extraContent.startsWith('http'))
                      ? Image.network(extraContent, fit: BoxFit.cover)
                      : const Center(
                          child: Icon(Icons.person,
                              size: 50, color: Colors.white)),
                ),
              ),
          ],

          if (hasAudio) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      if (isPlaying) {
                        await _audioPlayer.pause();
                        setState(() {
                          _isPlayingVoice = false;
                        });
                      } else {
                        // Stop any current playing
                        if (_isPlayingVoice) {
                          await _audioPlayer.stop();
                        }

                        setState(() {
                          _isPlayingVoice = true;
                          _playingVoiceId = voiceId;
                        });

                        await _audioPlayer.play(UrlSource(message.mediaUrl!));
                        _audioPlayer.onPlayerComplete.listen((event) {
                          if (mounted && _playingVoiceId == voiceId) {
                            setState(() {
                              _isPlayingVoice = false;
                              _playingVoiceId = null;
                            });
                          }
                        });
                      }
                    } catch (e) {
                      debugPrint('Error playing milestone audio: $e');
                      if (mounted) {
                        setState(() {
                          _isPlayingVoice = false;
                          _playingVoiceId = null;
                        });
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
            ),
          ],
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

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final isMe = _replyingTo!.senderId ==
        (Supabase.instance.client.auth.currentUser?.id);
    final senderName = isMe
        ? 'You'
        : (_feelingPercent >= 100
            ? (_partnerUsername ?? widget.contactName)
            : (_conversation?.getPartnerMask(
                    Supabase.instance.client.auth.currentUser?.id ?? '') ??
                widget.contactName));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
              color: isMe ? const Color(0xFF0AC5C5) : const Color(0xFFFF9800),
              width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe
                        ? const Color(0xFF0AC5C5)
                        : const Color(0xFFFF9800),
                  ),
                ),
                Text(
                  _replyingTo!.text ??
                      (_replyingTo!.type == 'image'
                          ? 'Picture'
                          : 'Voice Message'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF737373)),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF9800), width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 16, color: Color(0xFFFF9800)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editing Message',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9800),
                  ),
                ),
                Text(
                  _editingMessage!.text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF737373)),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
                _isTyping = false;
              });
            },
          ),
        ],
      ),
    );
  }

  void _onReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _showMessageOptions(ChatMessage message) {
    final isMe =
        message.senderId == (Supabase.instance.client.auth.currentUser?.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF0AC5C5)),
              title: const Text('Reply',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _onReply(message);
              },
            ),
            if (isMe && message.type == 'text')
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF0AC5C5)),
                title: const Text('Edit',
                    style: TextStyle(fontFamily: 'Montserrat')),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete',
                    style:
                        TextStyle(fontFamily: 'Montserrat', color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF0AC5C5)),
              title: const Text('Copy Text',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                if (message.text != null) {
                  Clipboard.setData(ClipboardData(text: message.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.text ?? '';
      _isTyping = _messageController.text.isNotEmpty;
    });
  }

  void _confirmDelete(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await _db.deleteMessage(message.id);
      // Realtime subscription should handle UI update, but we can also update local state
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  Widget _buildRepliedMessageContext(String replyToId) {
    // Find the original message in the list
    final repliedMsg = _messages.firstWhere(
      (m) => m.id == replyToId,
      orElse: () => ChatMessage(
        id: '',
        conversationId: '',
        senderId: '',
        type: 'text',
        text: 'Message deleted or not found',
        createdAt: DateTime.now(),
      ),
    );

    if (repliedMsg.id.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Message not found',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
        ),
      );
    }

    final isMe =
        repliedMsg.senderId == (Supabase.instance.client.auth.currentUser?.id);
    final senderName = isMe
        ? 'You'
        : (_feelingPercent >= 100
            ? (_partnerUsername ?? widget.contactName)
            : (_conversation?.getPartnerMask(
                    Supabase.instance.client.auth.currentUser?.id ?? '') ??
                widget.contactName));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
              color: isMe ? const Color(0xFF0AC5C5) : const Color(0xFFFF9800),
              width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMe ? const Color(0xFF0AC5C5) : const Color(0xFFFF9800),
            ),
          ),
          Text(
            repliedMsg.text ??
                (repliedMsg.type == 'image' ? 'Picture' : 'Voice Message'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    // 🛡️ Prevent flicker: shows nothing or a basic loading state
    // until we know for sure if we are locked or not.
    if (_isInitialLoad) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE3E3E3)),
          ),
        ),
      );
    }

    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: const Border(top: BorderSide(color: Color(0xFFE3E3E3))),
        ),
        child: const Center(
          child: Text(
            'This conversation is no longer available.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Color(0xFF737373),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE3E3E3), width: 0.5),
        ),
      ),
      child: _isPremiumLocked
          ? _buildPremiumLockState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_uploadProgress > 0 && _uploadProgress < 1.0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(value: _uploadProgress),
                  ),
                if (_replyingTo != null) _buildReplyPreview(),
                if (_editingMessage != null) _buildEditingPreview(),
                Row(
                  children: [
                    // Camera icon removed - text only per request
                    const SizedBox(width: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: const Color(0xFFE3E3E3), width: 0.8),
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
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(context).tr('chat.start_chatting_hint'),
                                  hintStyle: const TextStyle(
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
                            // Voice and Image icons removed - text only per request
                            const SizedBox(width: 8),
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
                                ? const LinearGradient(colors: [
                                    Color(0xFF0AC5C5),
                                    Color(0xFF08A3A3)
                                  ])
                                : LinearGradient(colors: [
                                    const Color(0xFF0AC5C5)
                                        .withValues(alpha: 0.5),
                                    const Color(0xFF08A3A3)
                                        .withValues(alpha: 0.5)
                                  ]),
                            shape: BoxShape.circle,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  _editingMessage != null
                                      ? Icons.edit
                                      : Icons.send,
                                  color: Colors.white,
                                  size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPremiumLockState() {
    // Determine the primary reason for the lock
    final gender = _userGender?.toLowerCase();
    final isFemale =
        gender == 'female' || gender == 'woman' || gender == 'femme';

    // Females only see the question flow.
    // Males see premium flow if not premium, else question flow.
    final needsNaughtyQuestion =
        isFemale ? !_hasAnsweredNaughty : (_isPremium && !_hasAnsweredNaughty);

    final l10n = AppLocalizations.of(context);
    String title = l10n.tr('chat.milestone_75_reached_title');
    String description = needsNaughtyQuestion
        ? l10n.tr('chat.milestone_75_desc_naughty')
        : l10n.tr('chat.milestone_75_desc_premium');
    String buttonText = needsNaughtyQuestion
        ? l10n.tr('chat.milestone_75_button_naughty')
        : l10n.tr('chat.milestone_75_button_unlock');
    VoidCallback onPressed = needsNaughtyQuestion
        ? _showNaughtyQuestionsScreen
        : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PremiumScreen(
                  onPremiumActivated: () {
                    // Payment done → pop back to chat and refresh
                    Navigator.of(context).pop();
                    _loadPremiumStatus();
                  },
                ),
              ),
            ).then((_) {
              _loadPremiumStatus();
            });
          };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF151515),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0AC5C5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNaughtyQuestionsScreen() {
    if (widget.conversationId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NaughtyQuestionsScreen(
          conversationId: widget.conversationId!,
          onComplete: () {
            if (mounted) {
              setState(() {
                _hasAnsweredNaughty = true;
              });
            }
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    AppLocalizations.of(context).tr('chat.answer_submitted')),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  void _insertQuote() {
    if (_isPremiumLocked) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _scrollToBottom();

    if (widget.conversationId != null) {
      _db.sendMessage(
        conversationId: widget.conversationId!,
        senderId: userId,
        type:
            'quote', // Treat as text for DB compatibility if needed, or 'quote'
        text: '“A shared moment matters more.”',
        mood: _currentMood,
        feelingDelta: 5,
      );
    }
  }

  Future<void> _checkMilestones() async {
    if (widget.conversationId == null || _isBlocked) return;

    debugPrint(
        '🎯 Checking milestones: current=$_feelingPercent, previous=$_previousFeelingPercent');

    // Load seen milestones from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'seen_milestones_${widget.conversationId}';
    final seenList = prefs.getStringList(seenKey) ?? [];
    final seenSet = seenList.map(int.parse).toSet();

    // Check if we've crossed any milestone thresholds
    final milestones = [25, 50, 75, 100];

    for (final threshold in milestones) {
      if (_feelingPercent >= threshold && !seenSet.contains(threshold)) {
        debugPrint(
            '✅ Milestone $threshold% reached and NOT seen locally! Showing modal...');

        // Mark as seen immediately to prevent duplicate shows
        seenSet.add(threshold);
        await prefs.setStringList(
            seenKey, seenSet.map((e) => e.toString()).toList());

        // Also save to database (shared status)
        if (!_shownMilestones.contains(threshold)) {
          _shownMilestones.add(threshold);
          _saveMilestoneToDatabase(threshold);
        }

        final milestone = FeelingMilestone.fromPercentage(threshold);
        if (milestone != null) {
          // Fetch partner data if needed for the milestone
          String? partnerBio;
          String? partnerSecretAudioUrl;

          if (_conversation != null) {
            try {
              final currentUserId = AuthService().currentUser?.id;
              final partnerId = _conversation!.userAId == currentUserId
                  ? _conversation!.userBId
                  : _conversation!.userAId;

              final response = await Supabase.instance.client
                  .from('profiles')
                  .select('about, secret_audio_url')
                  .eq('id', partnerId)
                  .single();

              partnerBio = response['about'] as String?;
              partnerSecretAudioUrl = response['secret_audio_url'] as String?;
            } catch (e) {
              debugPrint('❌ Error fetching partner data for milestone: $e');
            }
          }

          // Determine content to show in the chat bubble based on milestone
          String? milestoneContent;
          if (milestone.percentage == 25) {
            milestoneContent = partnerBio ??
                AppLocalizations.of(context).tr('chat.milestone_no_bio');
          } else if (milestone.percentage == 50) {
            // No extra text content for 50%, the audio player is the material
            milestoneContent = null;
          } else if (milestone.percentage == 75) {
            // ONLY fetch intimate questions if the user is PREMIUM
            if (_isPremium) {
              try {
                final currentUserId = AuthService().currentUser?.id;
                final partnerId = _conversation!.userAId == currentUserId
                    ? _conversation!.userBId
                    : _conversation!.userAId;

                final questionsResponse = await Supabase.instance.client
                    .from('intimate_questions')
                    .select('question_1, question_2, question_3')
                    .eq('conversation_id', widget.conversationId!)
                    .eq('user_id', partnerId)
                    .maybeSingle();

                if (questionsResponse != null) {
                  final q1 = questionsResponse['question_1'] as String?;
                  final q2 = questionsResponse['question_2'] as String?;
                  final q3 = questionsResponse['question_3'] as String?;

                  List<String> questions = [];
                  if (q1 != null && q1.isNotEmpty) questions.add(q1);
                  if (q2 != null && q2.isNotEmpty) questions.add(q2);
                  if (q3 != null && q3.isNotEmpty) questions.add(q3);

                  if (questions.isNotEmpty) {
                    milestoneContent = questions.join('\n\n');
                  } else {
                    milestoneContent = AppLocalizations.of(context)
                        .tr('chat.milestone_75_congrats');
                  }
                } else {
                  milestoneContent = AppLocalizations.of(context)
                      .tr('chat.milestone_75_congrats');
                }
              } catch (e) {
                milestoneContent = AppLocalizations.of(context)
                    .tr('chat.milestone_75_congrats');
              }
            } else {
              // Non-premium users just get the generic "congrats" text, no answers!
              milestoneContent =
                  AppLocalizations.of(context).tr('chat.milestone_75_congrats');
            }
          } else if (milestone.percentage == 100) {
            milestoneContent =
                _partnerAvatarUrl; // Link to reveals photo if exists
          }

          // NEW: Auto-post milestone to chat thread
          _postMilestoneMessage(milestone,
              content: milestoneContent, audioUrl: partnerSecretAudioUrl);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showMilestoneModal(
                milestone,
                partnerBio: partnerBio,
                partnerSecretAudioUrl: partnerSecretAudioUrl,
              );
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
      final fieldName =
          isUserA ? 'user_a_seen_milestones' : 'user_b_seen_milestones';

      await Supabase.instance.client.from('conversations').update({
        fieldName: _shownMilestones.toList(),
      }).eq('id', widget.conversationId!);
      debugPrint('✅ Milestone saved to $fieldName');
    } catch (e) {
      debugPrint('❌ Error saving milestone: $e');
    }
  }

  Future<void> _postMilestoneMessage(FeelingMilestone milestone,
      {String? content, String? audioUrl}) async {
    if (widget.conversationId == null) return;

    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    debugPrint(
        '📣 Posting milestone message to thread: ${milestone.percentage}%');

    try {
      // Determine message type and content
      String? mediaUrl;
      int? duration;

      if (milestone.percentage == 50 && audioUrl != null) {
        mediaUrl = audioUrl;
        duration = 3; // Provide a default duration for the media
      }

      // We use a custom mood to identify this as a milestone message in the UI
      // For content-rich milestones (25% bio, 75% naughty, 100% photo),
      // we append the content to the text field with a separator
      String messageText = milestone.getTitle(context);
      if (content != null && content.isNotEmpty) {
        messageText = '$messageText|--CONTENT--|$content';
      }

      await _db.sendMessage(
        conversationId: widget.conversationId!,
        senderId: userId,
        type:
            'text', // Always use text for milestones to ensure DB compatibility
        text: messageText,
        mood: 'milestone_${milestone.percentage}',
        mediaUrl: mediaUrl,
        duration: duration,
        feelingDelta: 0,
        lastMessageSummary: AppLocalizations.of(context)
            .tr('chat.milestone_summary_${milestone.percentage}'),
      );
    } catch (e) {
      debugPrint('❌ Error posting milestone message: $e');
    }
  }

  Future<void> _showMilestoneModal(
    FeelingMilestone milestone, {
    String? partnerBio,
    String? partnerSecretAudioUrl,
  }) async {
    debugPrint(
        '🎉 _showMilestoneModal called for: ${milestone.getTitle(context)}');

    // Show in-app notification for milestone unlock
    if (mounted) {
      NotificationService().show(
        context: context,
        title: AppLocalizations.of(context).tr('chat.milestone_unlock_title'),
        message: milestone == FeelingMilestone.gift
            ? null // Hide the subtitle specifically for 75% milestone
            : milestone.getTitle(context),
        icon: Text(
          milestone.icon,
          style: const TextStyle(fontSize: 32),
        ),
      );
    }

    // Data is now passed in to avoid redundant fetching
    debugPrint(
        '✅ Milestone data - bio: ${partnerBio != null}, audio: ${partnerSecretAudioUrl != null}');

    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, skipping modal');
      return;
    }

    debugPrint('🎭 Showing dialog for ${milestone.getTitle(context)}');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MilestoneUnlockModal(
        milestone: milestone,
        partnerBio: partnerBio,
        partnerSecretAudioUrl: partnerSecretAudioUrl,
        isPremium: _isPremium,
        userGender: _userGender,
        onPremiumRequested: () async {
          Navigator.pop(context); // close the milestone unlocked modal
          _showPremiumPaywall(); // the function itself shows dialog synchronously
          // Check if they upgraded
          await _loadPremiumStatus();
          if (!_isPremium && mounted) {
            // Kick them out of the conversation back to the previous screen
            Navigator.pop(context);
          }
        },
        onContinue: () {
          Navigator.pop(context);
          // At 75% milestone: only premium males and females can answer naughty questions
          if (milestone == FeelingMilestone.gift) {
            final isFemale = _userGender?.toLowerCase() == 'female' ||
                _userGender?.toLowerCase() == 'woman' ||
                _userGender?.toLowerCase() == 'femme';

            if (isFemale || _isPremium) {
              debugPrint(
                  '🎁 75% milestone – navigating premium/female to Naughty Questions');

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

                      if (mounted) {
                        setState(() {
                          _hasAnsweredNaughty = true;
                        });
                      }

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)
                              .tr('chat.answer_submitted')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ),
              );
            }
            // Non-premium males: their path is via onPremiumRequested in the modal button
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

    // After dialog is dismissed, force a rebuild so _isPremiumLocked re-evaluates.
    // This ensures non-premium males cannot bypass the lock by dismissing the modal.
    if (mounted) {
      setState(() {});

      // For the 75% milestone specifically: if the user is still locked
      // (non-premium male), immediately show the hard lock screen.
      if (milestone == FeelingMilestone.gift && _isPremiumLocked) {
        debugPrint(
            '🔒 75% modal closed, user still locked – enforcing hard lock');
        // `build()` will now return `_buildLockedMilestoneView()` on next frame.
      }
    }

    debugPrint('🎭 Dialog closed');
  }

  void _showPremiumPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumScreen(
          onPremiumActivated: () {
            // Payment done → pop back to chat and refresh
            Navigator.of(context).pop();
            _checkPremiumStatus();
          },
        ),
      ),
    ).then((_) async {
      // Refresh status after returning from premium screen
      await _checkPremiumStatus();
      
      // After reactivation, scroll to bottom to ensure user is at the newest messages
      // This solves the issue of returning to the beginning of the conversation.
      _scrollToBottom();

      // If user is still locked (didn't upgrade and is at 75%+ milestone),
      // redirect them to the home screen to avoid the "naughty question" trap.
      if (mounted && _isPremiumLocked) {
        debugPrint('🚪 User still locked at 75% - redirecting to Home');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _checkPremiumStatus() async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    final profile = await _db.getProfile(userId);
    if (profile != null && mounted) {
      setState(() {
        final tier = profile['tier'] as String? ?? 'free';
        _isPremium = tier == 'premium' || tier == 'elite';
      });
    }
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
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).tr('chat.photo_reveal.title'),
                    style: const TextStyle(
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
                      GestureDetector(
                        onTap: () {
                          if (_isPhotoRevealed && partnerPhotoUrl != null) {
                            Navigator.pop(context); // Close reveal dialog first
                            _showFullScreenImage(partnerPhotoUrl);
                          }
                        },
                        child: Container(
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
                      ),
                      if (!_isPhotoRevealed)
                        ClipOval(
                          child: Container(
                            width: 240,
                            height: 240,
                            color: Colors.black.withValues(alpha: 0.7),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline,
                                    color: Colors.white, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(context)
                                      .tr('chat.photo_reveal.feeling_overlay'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
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
                        ? AppLocalizations.of(context)
                            .tr('chat.photo_reveal.match_found')
                        : AppLocalizations.of(context)
                            .tr('chat.photo_reveal.desc'),
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
                      text: AppLocalizations.of(context)
                          .tr('chat.photo_reveal.button'),
                      onPressed: () async {
                        setState(() {
                          _isPhotoRevealed = true;
                        });

                        // Persist revealed state locally
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                            'is_photo_revealed_${widget.conversationId}', true);

                        // Also save consent/status to database if needed
                        final uid =
                            Supabase.instance.client.auth.currentUser?.id;
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
                      text: AppLocalizations.of(context)
                          .tr('chat.photo_reveal.close'),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _sendMessage() async {
    if (_isPremiumLocked) return;
    if (_messageController.text.trim().isEmpty || _isSaving) return;

    final text = _messageController.text.trim();
    if (_editingMessage == null) {
      _messageController.clear();
    }

    setState(() {
      _isTyping = false;
      _isSaving = true; // Show loading indicator
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.conversationId != null && userId != null) {
      try {
        if (_editingMessage != null) {
          // UPDATE existing message
          await _db.updateMessage(_editingMessage!.id, text);
          _messageController.clear();
          setState(() {
            _editingMessage = null;
          });
        } else {
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

          // SEND new message
          await _db.sendMessage(
            conversationId: widget.conversationId!,
            senderId: userId,
            type: 'text',
            text: text,
            mood: _currentMood,
            feelingDelta: _db.calculateFeelingPoints(
              type: 'text',
              text: text,
            ),
            replyToId: _replyingTo?.id,
          );

          setState(() {
            _replyingTo = null;
          });
        }

        // Database trigger handles feeling increment automatically
        debugPrint('✅ Message sent/updated. Forcing state refresh...');
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _loadConversation();
          });
        }
      } catch (e) {
        debugPrint('❌ Error in _sendMessage: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
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
            Text(
              AppLocalizations.of(context).tr('chat.mood.title'),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).tr('chat.mood.subtitle'),
              style: const TextStyle(
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
            content: Text(AppLocalizations.of(context).tr('chat.mood.changed', params: {'mood': AppLocalizations.of(context).tr('chat.mood.${mood.toLowerCase()}')})),
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
                AppLocalizations.of(context).tr('chat.mood.${mood.toLowerCase()}'),
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
              title: Text(AppLocalizations.of(context).tr('chat.attachment.take_photo'),
                  style: const TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF0AC5C5)),
              title: Text(AppLocalizations.of(context).tr('chat.attachment.from_gallery'),
                  style: const TextStyle(fontFamily: 'Montserrat')),
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
    if (_isPremiumLocked) return;
    if (!_isPremium && _feelingPercent < 100) return;
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
              feelingDelta: 5,
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
    if (_isPremiumLocked) return;
    if (!_isPremium && _feelingPercent < 100) return;
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
              feelingDelta: 5,
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
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context).tr('errors.image_selection')}: $e')),
        );
      }
    }
  }

  Future<void> _showVoiceRecorder() async {
    if (_isPremiumLocked) return;
    if (!_isPremium && _feelingPercent < 50) return;
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).tr('permissions.microphone'))),
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
                Text(
                  AppLocalizations.of(context).tr('chat.voice_message.recording'),
                  style: const TextStyle(
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
                Text(
                  AppLocalizations.of(context).tr('chat.voice_message.title'),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).tr('chat.voice_message.hint'),
                  style: const TextStyle(
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
                              _isRecording ? AppLocalizations.of(context).tr('chat.voice_message.send') : AppLocalizations.of(context).tr('chat.voice_message.record'),
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
          feelingDelta: 5,
        );
        // Database trigger will handle feeling increment automatically
      }
    }

    setState(() {
      _recordingPath = null;
      _recordingDuration = 0;
    });
  }


  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
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
    _partnerProfileSub?.cancel();
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
