import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../widgets/warm_gradient_background.dart';
import 'chat_profile_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/feeling_progress.dart';
import '../../services/feeling_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../home_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String contactName;
  final String? mood;
  final bool isUnlocked;
  final String? conversationId;
  final String? partnerId;
  final String? partnerName;

  const ChatConversationScreen({
    super.key,
    required this.contactName,
    this.mood,
    this.isUnlocked = false,
    this.conversationId,
    this.partnerId,
    this.partnerName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late final AudioRecorder _record;
  final DatabaseService _db = DatabaseService();

  bool _isTyping = false;
  bool _isSaving = false; // Track if message is being sent
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isPlayingVoice = false;
  String? _playingVoiceId;
  late final AudioPlayer _audioPlayer;

  int _feelingPercent = 0;
  String? _threadTitle;
  String? _partnerAvatarUrl;
  String? _myAvatarUrl;
  String? _partnerUsername;
  String? _partnerId;
  late final FeelingController _feelingController;

  bool _isPhotoRevealed = false;
  bool _isShowingMilestoneModal = false; // Prevents double-stacked 75% modals
  bool _isInitialLoad = true; // Prevents 75% lock flicker

  // 🔒 Feeling Bar Limit State
  String? _userGender;
  bool _hasAnsweredNaughty = false;

  // Milestone tracking
  final Set<int> _shownMilestones =
      {}; // Track which milestones have been shown
  int _previousFeelingPercent = 0;

  List<ChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<Map<String, dynamic>>? _convSub;
  late final UploadController _uploadController;
  double _uploadProgress = 0.0;
  String _currentMood = 'Curieux';

  // Store conversation data for feeling bar
  Conversation? _conversation;
  bool _isBlocked = false;
  bool _isPremium = false; // Track if user has premium subscription
  bool _isAccessGranted =
      false; // Track if user has free access (Woman) or Premium
  Map<String, dynamic>? _partnerProfile;
  StreamSubscription<Map<String, dynamic>?>? _partnerProfileSub;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _feelingController = FeelingController();

    // 🛡️ Safe initialization of potentially crashing native plugins
    try {
      _record = AudioRecorder();
      _audioPlayer = AudioPlayer();
    } catch (e) {
      debugPrint('❌ Error initializing audio plugins: $e');
      // We don't crash the UI if audio fails, it will just not work.
    }

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

    // 🎧 Centralized Audio Listener
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        debugPrint('🎵 [AudioPlayer] Playback complete.');
        setState(() {
          _isPlayingVoice = false;
          _playingVoiceId = null;
        });
      }
    });

    Future.microtask(_checkMilestones);

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final futures = <Future>[
        _loadPremiumStatus(),
        if (widget.conversationId != null) _loadConversation(),
        if (widget.conversationId != null) _loadInitialMessages(),
        if (widget.partnerId != null || widget.conversationId != null)
          _fetchPartnerProfile(),
      ];

      await Future.wait(futures).timeout(const Duration(seconds: 10),
          onTimeout: () {
        debugPrint('⚠️ Warning: Chat initialization timed out after 10s');
        return [];
      });
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

      // Optimistic message sync using periodic polling + conv trigger (since _msgSub is unreliable)
      // Polling guarantees updates even if Realtime drops entirely.
      const syncInterval = Duration(seconds: 4);
      Timer.periodic(syncInterval, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _syncMessages();
      });

      // Subscribe to conversation changes to update feeling bar
      _convSub = _db.subscribeConversation(widget.conversationId!).listen((row) {
        if (mounted) {
          debugPrint(
              '📊 [REALTIME-CONV] Received update: feeling=${row['feeling_percent']}');
          // Also check/mark read status if new messages came
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            _db.markMessagesAsRead(widget.conversationId!, currentUserId);
          }

          setState(() {
            _conversation = Conversation.fromJson(row);
            _feelingPercent = _conversation!.feelingPercent;
            _threadTitle = _conversation!.title;
            
            // Sync message stream manually as fallback
            _syncMessages();

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
      }, onError: (err) {
        debugPrint('❌ [REALTIME-CONV] Stream Error: $err');
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
            .select('tier, gender, avatar_url')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            final tier = profile['tier'] as String? ?? 'free';
            _isPremium = tier == 'premium' || tier == 'elite';
            _userGender = profile['gender'] as String?;
            _myAvatarUrl = profile['avatar_url'] as String?;
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
        final count = diff.inMinutes;
        final key = 'chat.time_ago_m${count > 1 ? "_plural" : ""}';
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${AppLocalizations.of(context).tr(key, params: {
              'count': count.toString()
            })}";
      } else if (diff.inHours < 24) {
        final count = diff.inHours;
        final key = 'chat.time_ago_h${count > 1 ? "_plural" : ""}';
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${AppLocalizations.of(context).tr(key, params: {
              'count': count.toString()
            })}";
      } else {
        final count = diff.inDays;
        final key = 'chat.time_ago_d${count > 1 ? "_plural" : ""}';
        return "${AppLocalizations.of(context).tr('chat.last_seen')} ${AppLocalizations.of(context).tr(key, params: {
              'count': count.toString()
            })}";
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
      final currentUserId = AuthService().currentUser?.id ?? '';
      final revealedKey =
          'is_photo_revealed_${widget.conversationId}_$currentUserId';
      if (mounted) {
        setState(() {
          _isPhotoRevealed = prefs.getBool(revealedKey) ?? false;
        });
      }

      await _fetchPartnerProfile();

      // 🛡️ Consolidated: Extract naughty answer & milestones directly from Conversation model
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

      // 🛡️ Ensure any missed milestones (e.g. while offline) trigger the popup when the conversation loads.
      _checkMilestones();
    }
  }

  Future<void> _fetchPartnerProfile() async {
    // If we already have the partnerId, we can start fetching immediately without waiting for conversation object
    final partnerIdToUse = widget.partnerId ??
        (_conversation != null
            ? (_conversation!.userAId == AuthService().currentUser?.id
                ? _conversation!.userBId
                : _conversation!.userAId)
            : null);

    if (partnerIdToUse == null) return;

    try {
      final currentUserId = AuthService().currentUser?.id;
      final partnerId = partnerIdToUse;

      if (partnerId == currentUserId) {
        debugPrint('⚠️ Warning: partnerId matches currentUserId');
        return;
      }

      // Set initial name from widget to prevent flicker while loading
      if (mounted && (_partnerUsername == null || _partnerUsername!.isEmpty)) {
        setState(() {
          _partnerUsername = widget.partnerName ?? widget.contactName;
        });
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
          _partnerUsername =
              profileData?['full_name'] as String? ?? widget.contactName;
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

    // CRITICAL: Sort DESCENDING (Newest First) for reverse:true ListView
    msgs.sort((a, b) {
      return b.createdAt.millisecondsSinceEpoch
          .compareTo(a.createdAt.millisecondsSinceEpoch);
    });

    debugPrint(
        '✅ Messages sorted DESCENDING by millisecondsSinceEpoch (timezone-independent)');

    if (mounted) {
      setState(() {
        _messages = msgs;
      });
      // In a reversed list, bottom is 0.0
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Immediate scroll check for reverse: true list
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _syncMessages() async {
    if (widget.conversationId == null) return;
    try {
      // 1. Force conversation update so feeling/naughty state is instantly accurate
      await _loadConversation();
      
      // 2. Fetch new messages safely
      final msgs = await _db.getMessages(widget.conversationId!);
      msgs.sort((a, b) => b.createdAt.millisecondsSinceEpoch
          .compareTo(a.createdAt.millisecondsSinceEpoch));
          
      if (mounted) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final latestDbMsgId = msgs.isNotEmpty ? msgs.first.id : null;
        final existingLatestMsgId = _messages.where((m) => !m.id.startsWith('temp_')).isNotEmpty 
            ? _messages.firstWhere((m) => !m.id.startsWith('temp_')).id 
            : null;

        bool isNewContent = (latestDbMsgId != existingLatestMsgId);

        setState(() {
          // Keep optimistic messages that haven't registered yet
          final tempMsgs = _messages.where((m) => m.id.startsWith('temp_')).toList();
          _messages = [...tempMsgs, ...msgs];
          
          // Clear temp messages if the real one has arrived (simple heuristic: if we got a new message from us, clear temps)
          if (isNewContent && msgs.isNotEmpty && msgs.first.senderId == currentUserId) {
              _messages.removeWhere((m) => m.id.startsWith('temp_'));
          }
        });
        
        if (isNewContent) {
           _scrollToBottom();
        }
      }
    } catch (e, stack) {
      debugPrint('Sync messages error: $e\n$stack');
    }
  }

  String _formatTime(dynamic createdAt) {
    try {
      DateTime dt;
      if (createdAt is DateTime) {
        dt = createdAt;
      } else {
        dt = DateTime.parse(createdAt as String);
      }
      // Use intl for localized 24h/12h formatting
      return DateFormat.Hm().format(dt.toLocal());
    } catch (_) {
      return '';
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
                if (mounted) {
                  setState(() => _hasAnsweredNaughty = true);
                  _syncMessages(); // Force fetch just in case!
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .tr('chat.answer_submitted')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
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
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  }
                },
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _partnerUsername ?? widget.contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF151515),
                            ),
                          ),
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
      reverse: true, // Standard for chat: index 0 is at the bottom
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 96, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isMe = message.isMe;
    bool isMilestone = message.mood?.startsWith('milestone_') ?? false;
    bool isNaughty = message.mood?.startsWith('naughty_') ?? false;
    
    if (isNaughty) {
      bool bothAnswered = false;
      if (_conversation != null) {
        final a1 = _conversation!.user1NaughtyAnswer;
        final a2 = _conversation!.user2NaughtyAnswer;
        bothAnswered = (a1 != null && a1.trim().isNotEmpty) && (a2 != null && a2.trim().isNotEmpty);
      }
      
      // 1. Show nothing until both persons answer
      if (!bothAnswered) {
        return const SizedBox.shrink();
      }
      
      // 2. Only show the question and answer of the partner, not the current user's
      if (isMe) {
        return const SizedBox.shrink();
      }
    }

    // Milestones and Intimacy Questions are always shown on the right side for both users per user request
    bool alignRight = isMe || isMilestone || isNaughty;

    // Use message's saved mood if available, otherwise use default 'Curieux' for old messages
    final messageMood = message.mood ?? 'Curieux';
    final gradient = _getMoodGradient(messageMood);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!alignRight) ...[
                Expanded(
                  child: Text(
                    _partnerUsername ?? widget.contactName,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF363636),
                    ),
                  ),
                ),
              ],
              if (alignRight) ...[
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).tr('common.you'),
                    style: const TextStyle(
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
                  bottomLeft: Radius.circular(alignRight ? 16 : 0),
                  bottomRight: Radius.circular(alignRight ? 0 : 16),
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
                  _buildMessageContent(message, isMe), // Still pass TRUE isMe status for secret revealing logic
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
                  final mediaUrl = message.mediaUrl!;
                  final source = mediaUrl.startsWith('http')
                      ? UrlSource(mediaUrl)
                      : DeviceFileSource(mediaUrl);
                  await _audioPlayer.play(source);
                  // Automatic reset handled by centralized listener
                }
              } catch (e) {
                debugPrint('Error playing standard voice message: $e');

                // Fallback attempt for corrupted local paths
                if (mounted &&
                    message.mediaUrl != null &&
                    !message.mediaUrl!.startsWith('http')) {
                  try {
                    final profileResp = await Supabase.instance.client
                        .from('profiles')
                        .select('secret_audio_url')
                        .eq('id', message.senderId)
                        .single();
                    final realUrl = profileResp['secret_audio_url'] as String?;
                    if (realUrl != null && realUrl.startsWith('http')) {
                      await _audioPlayer.play(UrlSource(realUrl));
                      return; // Successfully recovered!
                    }
                  } catch (_) {}
                }

                if (mounted) {
                  setState(() {
                    _isPlayingVoice = false;
                    _playingVoiceId = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)
                        .tr('errors.voice_unavailable')),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ));
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

      // 🔄 [HARDENED CANONICAL] Question Parser
      String? partnerQ;
      final currentUserIdStr = sb.Supabase.instance.client.auth.currentUser?.id;
      final myId = (currentUserIdStr ?? "").toLowerCase().trim();

      if (questionText.contains('|--RECIPROCAL--|')) {
        final parts = questionText.split('|--RECIPROCAL--|');
        final dataParts = parts[1].split('|--SPLIT--|');
        for (final part in dataParts) {
          final colonIndex = part.indexOf(':');
          if (colonIndex != -1) {
            final userIdPart = part.substring(0, colonIndex).toLowerCase().trim();
            final content = part.substring(colonIndex + 1);
            
            // Canonical check: skip if it belongs to current viewer
            if (myId.isNotEmpty && userIdPart != myId && content.isNotEmpty) {
              partnerQ = content;
              break;
            }
          }
        }
      }

      // 🛡️ Redundant Identity Check: 
      // If the model flag says 'isMe' OR the raw senderId matches our ID, we MUST NOT show the partner answer.
      final isReallyMe = message.isMe || (currentUserIdStr != null && message.senderId.toLowerCase().trim() == myId);

      final String displayQuestion;
      if (isReallyMe) {
        // Find OUR own question text in the payload
        String? myQ;
        if (questionText.contains('|--RECIPROCAL--|')) {
          final parts = questionText.split('|--RECIPROCAL--|');
          final dataParts = parts[1].split('|--SPLIT--|');
          for (final part in dataParts) {
             final colonIndex = part.indexOf(':');
             if (colonIndex != -1) {
               final userIdPart = part.substring(0, colonIndex).toLowerCase().trim();
               if (userIdPart == myId) {
                 myQ = part.substring(colonIndex + 1);
                 break;
               }
             }
          }
        }
        displayQuestion = myQ ?? questionText;
      } else {
        displayQuestion = (partnerQ != null && partnerQ.isNotEmpty)
            ? partnerQ
            : AppLocalizations.of(context).tr('chat.naughty_question_hidden_until_answered');
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
            displayQuestion,
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
      String rawText = message.text ?? '';
      final currentUserIdStr = sb.Supabase.instance.client.auth.currentUser?.id;
      final myId = (currentUserIdStr ?? "").toLowerCase().trim();
      String? partnerAnswer;

      // 🔄 [HARDENED CANONICAL] Answer Parser - ALWAYS show partner's answer
      if (rawText.contains('|--RECIPROCAL--|')) {
        final parts = rawText.split('|--RECIPROCAL--|');
        final dataParts = parts[1].split('|--SPLIT--|');
        
        for (final part in dataParts) {
          final colonIndex = part.indexOf(':');
          if (colonIndex != -1) {
            final userIdPart = part.substring(0, colonIndex).toLowerCase().trim();
            final content = part.substring(colonIndex + 1).trim();
            
            // Explicitly filter out viewer's ID for reciprocity
            if (myId.isNotEmpty && userIdPart != myId && content.isNotEmpty) {
              partnerAnswer = content;
              break;
            }
          }
        }
      } 

      // 🛡️ Redundant Identity Check: 
      // Ensure we NEVER show text in our OWN legacy or malformed bubbles.
      final isReallyMe = message.isMe || (currentUserIdStr != null && message.senderId.toLowerCase().trim() == myId);

      // Final Answer Text Logic
      String? answerQuestion;
      final String answerText;
      
      if (isReallyMe && partnerAnswer == null) {
        // It's my bubble, but partner hasn't replied yet.
        answerText = AppLocalizations.of(context).tr('chat.naughty_question_hidden_until_answered');
      } else if (partnerAnswer != null && partnerAnswer.isNotEmpty) {
        // We found a partner answer! 
        // 🔄 Check for embedded question text
        if (partnerAnswer.contains('|--QTEXT--|')) {
          final qParts = partnerAnswer.split('|--QTEXT--|');
          answerQuestion = qParts[0];
          answerText = qParts[1];
        } else {
          answerText = partnerAnswer;
        }
      } else if (!isReallyMe && !rawText.contains('|--RECIPROCAL--|')) {
        // Legacy fallback: if it's NOT me, the raw text IS the partner's answer.
        if (rawText.contains('|--QTEXT--|')) {
           final qParts = rawText.split('|--QTEXT--|');
           answerQuestion = qParts[0];
           answerText = qParts[1];
        } else {
           answerText = rawText;
        }
      } else {
        answerText = AppLocalizations.of(context).tr('chat.naughty_question_hidden_until_answered');
      }

      final hasPartnerAnswer = partnerAnswer != null && partnerAnswer.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                (hasPartnerAnswer 
                    ? AppLocalizations.of(context).tr('chat.naughty_question_partner_choice')
                    : AppLocalizations.of(context).tr('chat.naughty_question_waiting_partner'))
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
          if (answerQuestion != null && answerQuestion.isNotEmpty) ...[
            Text(
              answerQuestion,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Color(0xFF363636), // Slightly lighter than answer
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            answerText,
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
    } else if (message.mood?.startsWith('milestone_') ?? false) {
      String title = message.text ?? '';
      String? extraContent;
      String? audioUrl = message.mediaUrl;
      final currentUserId = AuthService().currentUser?.id;

      // 🔄 [ROBUST RECIPROCAL] Parser using User IDs
      if (title.contains('|--RECIPROCAL--|')) {
        final parts = title.split('|--RECIPROCAL--|');
        title = parts[0];
        final dataParts = parts[1].split('|--SPLIT--|');
        
        String? foundData;
        final myId = currentUserId?.trim();

        for (final part in dataParts) {
          final colonIndex = part.indexOf(':');
          if (colonIndex != -1) {
            final userIdPart = part.substring(0, colonIndex).trim();
            final content = part.substring(colonIndex + 1);
            
            // We want to show the content that does NOT belong to us (Reciprocal)
            if (userIdPart != myId && content.isNotEmpty) {
              foundData = content;
              break;
            }
          }
        }

        if (message.mood == 'milestone_50') {
          audioUrl = foundData;
        } else {
          extraContent = foundData;
        }
      } else if (title.contains('|--CONTENT--|')) {
        // Fallback for legacy messages
        final parts = title.split('|--CONTENT--|');
        title = parts[0];
        extraContent = parts.length > 1 ? parts[1] : null;
      }

      final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
      final voiceId = message.id;
      final isPlaying = _isPlayingVoice && _playingVoiceId == voiceId;

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
            else if (message.mood == 'milestone_50')
              const SizedBox.shrink() // Managed by the audio player
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
                  child: (_isPhotoRevealed && extraContent.startsWith('http'))
                      ? Image.network(extraContent, fit: BoxFit.cover)
                      : const Center(
                          child: Icon(Icons.lock_outline,
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

                        final mediaUrl = audioUrl; // Use the parsed Reciprocal URL
                        if (mediaUrl == null) return;
                        final source = mediaUrl.startsWith('http')
                            ? UrlSource(mediaUrl)
                            : DeviceFileSource(mediaUrl);
                        await _audioPlayer.play(source);
                        // Automatic reset handled by centralized listener
                      }
                    } catch (e) {
                      debugPrint('Error playing milestone audio: $e');

                      // Auto-recovery for legacy local paths in historical milestones
                      if (mounted && audioUrl != null && !audioUrl.startsWith('http')) {
                        try {
                          final profileResp = await Supabase.instance.client
                              .from('profiles')
                              .select('secret_audio_url')
                              .eq('id', message.senderId)
                              .single();
                          final realUrl =
                              profileResp['secret_audio_url'] as String?;
                          if (realUrl != null && realUrl.startsWith('http')) {
                            await _audioPlayer.play(UrlSource(realUrl));
                            return; // Successfully recovered!
                          }
                        } catch (_) {}
                      }

                      if (mounted) {
                        setState(() {
                          _isPlayingVoice = false;
                          _playingVoiceId = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(AppLocalizations.of(context)
                              .tr('errors.voice_unavailable')),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ));
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
              mainAxisSize: MainAxisSize.min,
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
                                  hintText: AppLocalizations.of(context)
                                      .tr('chat.start_chatting_hint'),
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
    final currentUserId = AuthService().currentUser?.id ?? '';
    final seenKey = 'seen_milestones_${widget.conversationId}_$currentUserId';
    final seenList = prefs.getStringList(seenKey) ?? [];
    final seenSet = seenList.map(int.parse).toSet();

    // Check if we've crossed any milestone thresholds
    final milestones = [25, 50, 75, 100];

    for (final threshold in milestones) {
      if (_feelingPercent >= threshold && !seenSet.contains(threshold)) {
        if (_isShowingMilestoneModal) return; // Prevent concurrent stack triggers
        
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
          // 💡 RECIPROCAL FETCH: Fetch BOTH current user's data and partner's data
          String? mySecret;
          String? partnerSecret;
          String? myAudioUrl;
          String? partnerAudioUrl;

          try {
            final partnerId = _conversation!.userAId == currentUserId
                ? _conversation!.userBId
                : _conversation!.userAId;

            // Fetch both profiles
            final results = await Future.wait([
              Supabase.instance.client
                  .from('profiles')
                  .select('secret_quote, secret_audio_url, avatar_url')
                  .eq('id', currentUserId)
                  .single(),
              Supabase.instance.client
                  .from('profiles')
                  .select('secret_quote, secret_audio_url, avatar_url')
                  .eq('id', partnerId)
                  .single()
            ]);

            final myProfile = results[0];
            final partnerProfile = results[1];

            if (threshold == 25) {
              mySecret = myProfile['secret_quote'] as String?;
              partnerSecret = partnerProfile['secret_quote'] as String?;
            } else if (threshold == 50) {
              myAudioUrl = myProfile['secret_audio_url'] as String?;
              partnerAudioUrl = partnerProfile['secret_audio_url'] as String?;
            } else if (threshold == 75) {
              // Fetch intimate questions for BOTH
              final resultsQ = await Future.wait([
                Supabase.instance.client
                    .from('intimate_questions')
                    .select('question_1, question_2, question_3')
                    .eq('conversation_id', widget.conversationId!)
                    .eq('user_id', currentUserId)
                    .maybeSingle(),
                Supabase.instance.client
                    .from('intimate_questions')
                    .select('question_1, question_2, question_3')
                    .eq('conversation_id', widget.conversationId!)
                    .eq('user_id', partnerId)
                    .maybeSingle()
              ]);

              for (int i = 0; i < 2; i++) {
                final resp = resultsQ[i];
                if (resp != null) {
                  final q = [
                    resp['question_1'] as String?,
                    resp['question_2'] as String?,
                    resp['question_3'] as String?
                  ].where((e) => e != null && e.isNotEmpty).join('\n\n');
                  if (i == 0) mySecret = q; else partnerSecret = q;
                }
              }

              final fallback = AppLocalizations.of(context).tr('chat.milestone_75_congrats');
              mySecret ??= fallback;
              partnerSecret ??= fallback;
            } else if (threshold == 100) {
              mySecret = myProfile['avatar_url'] as String?;
              partnerSecret = partnerProfile['avatar_url'] as String?;
            }
          } catch (e) {
            debugPrint('❌ Error fetching reciprocal data for milestone: $e');
          }

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showMilestoneModal(
                milestone,
                partnerBio: partnerSecret, // Still pass partner secret for the modal experience
                partnerSecretAudioUrl: partnerAudioUrl,
                mySecret: mySecret,
                myAudioUrl: myAudioUrl,
              );
            }
          });
        }
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
      {String? myContent, String? partnerContent, String? myAudioUrl, String? partnerAudioUrl}) async {
    if (widget.conversationId == null) return;

    final userId = AuthService().currentUser?.id;
    if (userId == null) return;

    // 🛡️ Prevent duplicate messages for the same milestone in local state
    final milestoneMood = 'milestone_${milestone.percentage}';
    final alreadyExists = _messages.any((m) => m.mood == milestoneMood);
    if (alreadyExists) {
      debugPrint('⚠️ Milestone message for ${milestone.percentage}% already exists, skipping.');
      return;
    }

    debugPrint('📣 Posting reciprocal milestone message: ${milestone.percentage}%');

    try {
      if (_conversation == null) {
        debugPrint('❌ [MILESTONE] Conversation is null, cannot post message');
        return;
      }
      // 💬 [RECIPROCAL] Dynamic content based on user IDs
      final currentUserId = AuthService().currentUser?.id;
      final userId = currentUserId ?? 'unknown';
      final partnerId = _conversation!.userAId == userId 
          ? _conversation!.userBId 
          : _conversation!.userAId;

      // Format: Title|--RECIPROCAL--|userIdA:dataA|--SPLIT--|userIdB:dataB
      String title = milestone.getTitle(context);
      String encodedText = '$title|--RECIPROCAL--|$userId:';
      
      if (milestone.percentage == 50) {
        encodedText += '${myAudioUrl ?? ""}|--SPLIT--|$partnerId:${partnerAudioUrl ?? ""}';
      } else {
        encodedText += '${myContent ?? ""}|--SPLIT--|$partnerId:${partnerContent ?? ""}';
      }

      // ⚡ OPTIMISTIC UI: Add to local list immediately
      final tempId = 'temp_milestone_${milestone.percentage}_${DateTime.now().millisecondsSinceEpoch}';
      final tempMsg = ChatMessage(
        id: tempId,
        conversationId: widget.conversationId!,
        senderId: userId,
        type: 'text',
        text: encodedText,
        createdAt: DateTime.now(),
        isMe: true,
        mood: milestoneMood,
      );

      if (mounted) {
        setState(() {
          _messages.add(tempMsg);
          _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        _scrollToBottom();
      }

      await _db.sendMessage(
        conversationId: widget.conversationId!,
        senderId: userId,
        type: 'text',
        text: encodedText,
        mood: milestoneMood,
        feelingDelta: 0,
        lastMessageSummary: AppLocalizations.of(context)
            .tr('chat.milestone_summary_${milestone.percentage}'),
      );
    } catch (e) {
      debugPrint('❌ [MILESTONE] Error posting message: $e');
    }
  }

  Future<void> _showMilestoneModal(
    FeelingMilestone milestone, {
    String? partnerBio,
    String? partnerSecretAudioUrl,
    String? mySecret,
    String? myAudioUrl,
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

    if (!mounted) {
      _isShowingMilestoneModal = false;
      return;
    }

    _isShowingMilestoneModal = true;

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
          Navigator.pop(context); // close modal
          _showPremiumPaywall();
          await _loadPremiumStatus();
          if (!_isPremium && mounted) Navigator.pop(context);
        },
        onContinue: () {
          Navigator.pop(context);
          // 💬 RECIPROCAL: Post message containing BOTH secrets
          _postMilestoneMessage(
            milestone,
            myContent: mySecret,
            partnerContent: partnerBio,
            myAudioUrl: myAudioUrl,
            partnerAudioUrl: partnerSecretAudioUrl,
          );

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
                        // Immediately fetch conversation state and messages so it displays natively
                        _loadConversation();
                        _syncMessages();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)
                                .tr('chat.answer_submitted')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
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

    // After dialog is dismissed, release stack lock and force rebuild
    _isShowingMilestoneModal = false;
    
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

                        // Manual trigger: Now that they clicked reveal, post the milestone to the chat thread!
                        _postMilestoneMessage(FeelingMilestone.heart,
                            myContent: _myAvatarUrl,
                            partnerContent: _partnerAvatarUrl);

                        // Persist revealed state locally
                        final prefs = await SharedPreferences.getInstance();
                        final currentUserId =
                            AuthService().currentUser?.id ?? '';
                        await prefs.setBool(
                            'is_photo_revealed_${widget.conversationId}_$currentUserId',
                            true);

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
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSaving) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.conversationId != null && userId != null) {
      if (_editingMessage != null) {
        // For edits, we just wait for the DB for now to avoid complexity
        try {
          await _db.updateMessage(_editingMessage!.id, text);
          if (mounted) setState(() => _editingMessage = null);
        } catch (e) {
          debugPrint('❌ Error updating message: $e');
        }
        return;
      }

      // HAPTIC FEEDBACK: Immediate physical confirmation
      HapticFeedback.lightImpact();

      // OPTIMISTIC UPDATE: Create and add a temporary message immediately
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticMsg = ChatMessage(
        id: tempId,
        conversationId: widget.conversationId!,
        senderId: userId,
        type: 'text',
        text: text,
        createdAt: DateTime.now(),
        isMe: true,
        mood: _currentMood,
        replyToId: _replyingTo?.id,
      );

      if (mounted) {
        // ATOMIC STATE UPDATE: Consolidate input clear, message addition, and feeling progress
        setState(() {
          _messageController.clear();
          _isTyping = false;
          _messages.insert(0, optimisticMsg);
          _replyingTo = null; // Clear reply state immediately
        });
        _scrollToBottom();
      }

      try {
        // Optimized: SEND new message in background without blocking UI
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
          replyToId: optimisticMsg.replyToId,
        );

        // Immediate refresh of conversation data for faster progress update
        if (mounted) _loadConversation();
      } catch (e) {
        debugPrint('❌ Error in _sendMessage: $e');
        if (mounted) {
          // Remove the optimistic message if it failed and restore text
          setState(() {
            _messages.removeWhere((m) => m.id == tempId);
            _messageController.text = text;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending message: $e')),
          );
        }
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
            content: Text(AppLocalizations.of(context).tr('chat.mood.changed',
                params: {
                  'mood': AppLocalizations.of(context)
                      .tr('chat.mood.${mood.toLowerCase()}')
                })),
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
                AppLocalizations.of(context)
                    .tr('chat.mood.${mood.toLowerCase()}'),
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

  @override
  void dispose() {
    _msgSub?.cancel();
    _convSub?.cancel();
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
