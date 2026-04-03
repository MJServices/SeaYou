import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/warm_gradient_background.dart';
import '../models/conversation.dart';
import 'received_bottles_screen.dart';
import 'send_bottle_screen.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_conversation_screen.dart';
import 'profile_screen.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../i18n/app_localizations.dart';
import 'new_bottles_list_screen.dart';
import '../services/tutorial_service.dart';
import 'secret_souls_screen.dart';
import 'door_of_desires_screen.dart';
import 'premium_screen.dart';
import '../widgets/profile_avatar.dart';
import '../services/onboarding_service.dart';
import '../services/entitlements_service.dart';
import '../services/bottle_matching_service.dart';

import '../widgets/tutorial_modal.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../widgets/bottom_nav_bar.dart';

/// Home Screen - Dynamic with database integration
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  int _receivedCount = 0;
  int _sentCount = 0;
  Map<String, dynamic>? _userProfile;
  String _userName = 'User';
  String? _avatarUrl;
  final List<RealtimeChannel> _messageChannels = []; // For optimized message listeners
  StreamSubscription<Map<String, dynamic>?>? _profileSub;
  String? _lastNotifiedBottleId;

  @override
  void initState() {
    super.initState();
    PresenceService.instance.init();
    _loadData();
    GlobalAudioController.instance.playAmbient();
    _subscribeProfile();
    _subscribeNewMessages();
    _subscribeNewBottles();
    _subscribeNewConversations();
    _triggerBottleRematching();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final t = TutorialService();
      final seen = await t.hasSeenHomeTutorial();
      // DISABLED: Premium coachmark popup removed per user request
      if (!seen && mounted) {
        await TutorialModal.show(context);
        await t.setSeenHomeTutorial();
      }
    });
  }

  @override
  void dispose() {
    for (final channel in _messageChannels) {
      _supabase.removeChannel(channel);
    }
    _profileSub?.cancel();
    GlobalAudioController.instance.stopAmbient();
    super.dispose();
  }


  Future<void> _loadData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _receivedCount = 0;
          _sentCount = 0;
          _userProfile = null;
          _isLoading = false;
        });
      }
      return;
    }

    // 🏁 SWR (Stale-While-Revalidate) INITIAL LOAD:
    if (mounted) {
      setState(() {
        _userProfile = DatabaseService.getProfileSync(userId);
        if (_userProfile != null) {
          _userName = _userProfile!['full_name'] ?? 'User';
          _avatarUrl = _userProfile!['avatar_url'];
        }

        _receivedCount = DatabaseService.getUnrepliedCountSync();
        _sentCount = DatabaseService.getSentCountSync();

        _isLoading = (_userProfile == null);
      });
    }

    try {
      // 🔄 PROGRESSIVE REFRESH:
      
      // 1. Profile (highest priority)
      _databaseService.getProfile(userId).then((profile) {
        if (mounted && profile != null) {
          setState(() {
            _userProfile = profile;
            _userName = profile['full_name'] ?? 'User';
            _avatarUrl = profile['avatar_url'];
            _isLoading = false;
          });

          // HARD GUARD: Enforce Profile Completion
          OnboardingService().resumeOnboarding(
            context, 
            profile,
            currentStep: OnboardingStep.completed
          );
        }
      });

      // 2. Unreplied Count (Circular Bottle)
      _databaseService.getUnrepliedBottlesCount(userId).then((count) {
        if (mounted) setState(() => _receivedCount = count);
      });

      // 3. Sent Count
      _databaseService.getSentBottlesCount(userId).then((count) {
        if (mounted) setState(() => _sentCount = count);
      });

    } catch (e) {
      debugPrint('❌ Error in progressive Home Screen load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerBottleRematching() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Run in background after a slight delay to not interfere with initial load
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          BottleMatchingService().autoMatchPendingBottlesForUser(userId);
        }
      });
    } catch (e) {
      debugPrint('Error triggering bottle re-matching: $e');
    }
  }

  void _subscribeProfile() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSub?.cancel();
    _profileSub = _databaseService.profileStream(userId).listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _userProfile = profile;
          _userName = profile['full_name'] ?? 'User';
          _avatarUrl = profile['avatar_url'];
        });
      }
    });
  }

  Future<void> _subscribeNewMessages() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final convs = await _databaseService.getUserConversations(userId);
      final convIds = convs.map((c) => c.id).toList();

      if (convIds.isEmpty) return;

      // OPTIMIZATION: Use a SINGLE efficient listener for all conversations
      for (final channel in _messageChannels) {
        _supabase.removeChannel(channel);
      }
      _messageChannels.clear();

      final newChannel = _supabase
          .channel('public:messages_unread')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'conversation_id',
              value: convIds,
            ),
            callback: (payload) async {
              final msg = payload.newRecord;
              final senderId = msg['sender_id'] as String?;
              final conversationId = msg['conversation_id'] as String;

              if (senderId != null && senderId != userId) {
                // Check if blocked
                final isBlocked = await _databaseService.isRelationBlocked(userId, senderId);
                if (isBlocked) return;

                // Show notification
                if (mounted) {
                  final conversation = convs.firstWhere((c) => c.id == conversationId, 
                    orElse: () => Conversation(
                        id: conversationId, 
                        userAId: '', 
                        userBId: '', 
                        createdAt: DateTime.now(), 
                        updatedAt: DateTime.now()
                    ));
                  
                  NotificationService().show(
                    context: context,
                    title: '💬 ${conversation.title ?? AppLocalizations.of(context).tr('notification.new_message')}',
                    message: msg['text'] as String? ?? AppLocalizations.of(context).tr('notification.you_have_new_message'),
                    icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 32),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatConversationScreen(
                            conversationId: conversationId,
                            contactName: conversation.title ?? 'Chat',
                            partnerId: senderId,
                          ),
                        ),
                      );
                    },
                  );

                  // Update counts
                  _loadData();
                }
              }
            },
          );
      
      newChannel.subscribe();
      _messageChannels.add(newChannel);
    } catch (e) {
      debugPrint('Error subscribing new messages: $e');
    }
  }

  Future<void> _subscribeNewBottles() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _supabase
          .from('received_bottles')
          .stream(primaryKey: ['id'])
          .eq('receiver_id', userId)
          .listen((data) async {
            if (data.isNotEmpty && mounted) {
              final latestBottle = data.last;
              final senderId = latestBottle['sender_id'] as String?;
              final isRead = latestBottle['is_read'] as bool? ?? false;
              final bottleId = latestBottle['id'] as String;

              if (senderId != null &&
                  senderId != userId &&
                  !isRead &&
                  bottleId != _lastNotifiedBottleId) {
                final isBlocked =
                    await _databaseService.isRelationBlocked(userId, senderId);
                if (isBlocked) return;

                _lastNotifiedBottleId = bottleId;

                NotificationService().show(
                  context: context,
                  title:
                      '🍾 ${AppLocalizations.of(context).tr('notification.new_bottle')}',
                  message: AppLocalizations.of(context)
                      .tr('notification.new_bottle_message'),
                  icon: const Icon(
                    Icons.mail,
                    color: Colors.white,
                    size: 32,
                  ),
                  gradientColors: [Colors.orange, Colors.orangeAccent],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewBottlesListScreen(),
                      ),
                    );
                  },
                );

                _loadData();
              }
            }
          });
    } catch (e) {
      debugPrint('Error subscribing to bottles: $e');
    }
  }

  Future<void> _subscribeNewConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _supabase
          .channel('public:conversations')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'conversations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'user_b_id',
              value: [userId],
            ),
            callback: (payload) async {
              final newConv = payload.newRecord;
              if (newConv['user_a_id'] == userId ||
                  newConv['user_b_id'] == userId) {
                final otherUserId = newConv['user_a_id'] == userId
                    ? newConv['user_b_id']
                    : newConv['user_a_id'];
                if (otherUserId != null) {
                  final isBlocked = await _databaseService.isRelationBlocked(
                      userId, otherUserId);
                  if (isBlocked) return;
                }

                if (mounted) {
                  NotificationService().show(
                    context: context,
                    title: 'New Connection!',
                    message: 'Someone replied to your secret message!',
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                  );

                  await _loadData();
                  _subscribeNewMessages();
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to new conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: WarmGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 90, // Adjusted to sit above nav bar
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 402,
                        minWidth: screenWidth > 402 ? 402 : screenWidth,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProfileScreen()));
                                    _loadData();
                                  },
                                  child: ProfileAvatar(
                                    imageUrl: _avatarUrl,
                                    radius: 20,
                                    isLoading: _isLoading,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _isLoading
                                      ? Container(
                                          width: 120,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withAlpha(50),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        )
                                      : Text(
                                          () {
                                            final String firstName = _userName
                                                .split(' ')
                                                .first
                                                .replaceAll(RegExp(r'\d+'), '');
                                            return '${AppLocalizations.of(context).tr('home.greeting')} $firstName';
                                          }(),
                                          style: const TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF151515),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_receivedCount > 0) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NewBottlesListScreen(),
                                  ),
                                ).then((_) => _loadData());
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ReceivedBottlesScreen(),
                                  ),
                                ).then((_) => _loadData());
                              }
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/homepage_bottle.png',
                                      width: 140,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _isLoading
                                    ? Container(
                                        width: 140,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withAlpha(50),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      )
                                    : Text(
                                        _receivedCount == 0
                                            ? AppLocalizations.of(context)
                                                .tr('home.new_messages_zero')
                                            : AppLocalizations.of(context)
                                                .tr('home.new_messages_one'),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF151515),
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)
                                      .tr('home.discover'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNavigationCard(
                                        imagePath:
                                            'assets/images/ongoing_conversation.jpeg',
                                        label: AppLocalizations.of(context)
                                            .tr('home.ongoing_conversations'),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ChatListScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildNavigationCard(
                                        imagePath:
                                            'assets/images/write_message.jpeg',
                                        label: AppLocalizations.of(context)
                                            .tr('home.write_message'),
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const SendBottleScreen(),
                                            ),
                                          );
                                          _loadData();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNavigationCard(
                                        imagePath:
                                            'assets/images/secretsouls.jpeg',
                                        label: AppLocalizations.of(context)
                                            .tr('home.secret_souls'),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const SecretSoulsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildNavigationCard(
                                        imagePath:
                                            'assets/images/desirecard.jpeg',
                                        label: AppLocalizations.of(context)
                                            .tr('home.door_of_desires'),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const DoorOfDesiresScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_userProfile?['gender']
                                      ?.toString()
                                      .toLowerCase() !=
                                  'woman' &&
                              _userProfile?['gender']
                                      ?.toString()
                                      .toLowerCase() !=
                                  'female' &&
                              _userProfile?['gender']
                                      ?.toString()
                                      .toLowerCase() !=
                                  'femme')
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PremiumScreen()),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0AC5C5),
                                        Color(0xFF65ADA9)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0AC5C5)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .tr('home.premium_cta'),
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextButton(
                              onPressed: () async {
                                final userId = _supabase.auth.currentUser?.id;
                                if (userId != null) {
                                  final entitlements = EntitlementsService();
                                  await entitlements.grantEntitlement(userId, 'premium', 'debug_manual_activation');
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('DEBUG: Premium Activated')),
                                    );
                                    _loadData();
                                  }
                                }
                              },
                              child: Text(
                                AppLocalizations.of(context)
                                    .tr('home.debug_activate_premium'),
                                style: const TextStyle(
                                    color: Color(0xFFFF5252),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Navigation
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavBar(
                  activeScreen: 'home',
                  userProfile: _userProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildNavigationCard({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 144,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
