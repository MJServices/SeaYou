import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'chat_conversation_screen.dart';
import '../../widgets/feeling_progress.dart';
import '../../services/database_service.dart';
import '../../models/conversation.dart';
import '../../i18n/app_localizations.dart';
import '../../services/entitlements_service.dart';

/// Chat List Screen - Shows all conversations with full functionality
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Conversation> _conversations = [];
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  String? _avatarUrl;
  String? _userGender;
  Map<String, Map<String, dynamic>> _partnerProfiles = {};
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isAccessGranted = false;
  StreamSubscription<Map<String, dynamic>?>? _profileSub;
  int _archivedCount = 0;

  @override
  void initState() {
    super.initState();

    // ⚡ INSTANT: Show whatever is already in the in-memory cache RIGHT NOW (0ms)
    final cached = DatabaseService.getConversationsSync();
    if (cached.isNotEmpty) {
      _conversations = cached;
      _isLoading = false;
      // Also populate partner profiles from profile cache
      for (final conv in cached) {
        if (_currentUserId != null) {
          final otherId = conv.getOtherUserId(_currentUserId);
          final p = DatabaseService.getProfileSync(otherId);
          if (p != null) _partnerProfiles[otherId] = p;
        }
      }
    }

    // Load current user from cache instantly
    if (_currentUserId != null) {
      final myProfile = DatabaseService.getProfileSync(_currentUserId);
      if (myProfile != null) {
        _avatarUrl = myProfile['avatar_url'] as String?;
        _userGender = myProfile['gender'] as String?;
        final cached = EntitlementsService.isPremiumOrWomanSync(_currentUserId);
        if (cached != null) {
          _isPremium = cached;
          _isAccessGranted = cached;
        }
      }
    }

    // Silently refresh everything in background
    _refreshInBackground();
    _subscribeProfile();
  }

  /// Silent background refresh — updates UI without any loading spinner
  Future<void> _refreshInBackground() async {
    await _loadUserProfile();
    await _loadConversations();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUserId == null) return;
    try {
      final profile = await _db.getProfile(_currentUserId);
      if (profile != null && mounted) {
        final access = await EntitlementsService().isPremiumOrWoman(_currentUserId);
        setState(() {
          _avatarUrl = profile['avatar_url'];
          _userGender = profile['gender'] as String?;
          _isPremium = access;
          _isAccessGranted = access;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (_currentUserId == null) return;
    try {
      // Fetch fresh data
      final List<Conversation> convs =
          await _db.getUserConversations(_currentUserId, forceRefresh: true);
      final List<String> blockedByMe = await _db.getBlockedUserIds(_currentUserId);
      final List<String> blockingMe = await _db.getBlockers(_currentUserId);
      final Set<String> allBlocked = {...blockedByMe, ...blockingMe};

      final List<Conversation> filteredConvs = convs.where((conv) {
        final partnerId = conv.getOtherUserId(_currentUserId);
        return !allBlocked.contains(partnerId);
      }).toList();

      final partnerIds = filteredConvs
          .map((c) => c.getOtherUserId(_currentUserId))
          .toSet()
          .toList();

      if (partnerIds.isNotEmpty) {
        final profiles = await _db.getProfiles(partnerIds);
        if (mounted) setState(() => _partnerProfiles = profiles);
      }

      if (mounted) {
        setState(() {
          _conversations = filteredConvs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  List<Conversation> get _filteredConversations {
    var conversations = _conversations;

    // Apply filter
    if (_selectedFilter == 'Unlocked') {
      conversations =
          conversations.where((conv) => conv.feelingPercent >= 25).toList();
    } else if (_selectedFilter == 'Anon') {
      conversations =
          conversations.where((conv) => conv.feelingPercent < 25).toList();
    }

    // Apply search (Local search on loaded conversations - might need optimization later)
    if (_searchQuery.isNotEmpty) {
      // Simple search on last message for now, as names require async fetch
      conversations = conversations.where((conv) {
        final message = (conv.lastMessage ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return message.contains(query);
      }).toList();
    }

    return conversations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              bottom: 90, // Space for navigation bar
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(context),
                    // _buildFilterTabs(), // Removed as per request
                    Expanded(
                      child: _buildConversationsList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavBar(
                activeScreen: 'chat',
                userProfile:
                    _avatarUrl != null ? {'avatar_url': _avatarUrl} : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).tr('chat.connections_title'),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showSearchDialog,
            child: const Icon(Icons.search, size: 24, color: Color(0xFF151515)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .tr('chat.search_placeholder'),
                  hintStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF737373),
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF0AC5C5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0AC5C5)),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      AppLocalizations.of(context).tr('chat.search_clear'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).tr('chat.search_done'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Color(0xFF0AC5C5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _profileSub?.cancel();
    super.dispose();
  }

  void _subscribeProfile() {
    if (_currentUserId == null) return;

    _profileSub?.cancel();
    _profileSub = _db.profileStream(_currentUserId).listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'];
        });
      }
    });
  }

  Widget _buildConversationsList() {
    final conversations = _filteredConversations;
    debugPrint(
        '📋 _buildConversationsList called with ${conversations.length} conversations');

    if (_isLoading && conversations.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (conversations.isEmpty) {
      debugPrint('⚠️ Conversations list is empty, showing empty state');
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    debugPrint(
        '✅ Building ListView with ${conversations.length} conversations');
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          debugPrint(
              '  Building conversation item $index: ${conversations[index].id}');
          return _buildConversationItem(conversations[index]);
        },
      ),
    );
  }

  bool _isUserPremiumLocked(int feelingPercent) {
    if (feelingPercent < 75) return false;
    return !_isAccessGranted;
  }

  Widget _buildEmptyState() {
    String emptyMessage = _selectedFilter == 'Anon'
        ? AppLocalizations.of(context).tr('chat.empty_no_locked')
        : _selectedFilter == 'Unlocked'
            ? AppLocalizations.of(context).tr('chat.empty_no_unlocked')
            : AppLocalizations.of(context).tr('chat.empty_no_connections');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty-bottle.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    if (_currentUserId == null) return const SizedBox.shrink();

    final otherUserId = conversation.getOtherUserId(_currentUserId);
    final profile = _partnerProfiles[otherUserId];

    if (profile == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE3E3E3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100, height: 16, color: const Color(0xFFE3E3E3)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final profileName = (profile['username'] != null &&
            profile['username'].toString().isNotEmpty)
        ? profile['username']
        : (profile['full_name'] != null &&
                profile['full_name'].toString().isNotEmpty)
            ? profile['full_name']
            : AppLocalizations.of(context).tr('chat.anonymous');

    final rawMask = conversation.getPartnerMask(_currentUserId);
    String? translatedMask;
    if (rawMask != null) {
      final m = rawMask.toLowerCase();
      if (m == 'secret' || m == 'soul' || m == 'secret soul') {
        translatedMask = AppLocalizations.of(context).tr('common.secret_soul');
      } else if (m == 'desire' || m == 'fantasy' || m == 'door of desires') {
        translatedMask = AppLocalizations.of(context).tr('common.door_of_desires');
      } else if (m == 'anonymous' || m == 'anonymous soul') {
        translatedMask = AppLocalizations.of(context).tr('common.anonymous_soul');
      } else {
        translatedMask = rawMask;
      }
    }

    final name = conversation.feelingPercent >= 100
        ? profileName
        : (translatedMask ?? profileName);

    final age = profile['age'];
    final department = profile['department'];
    final partnerInfo = (age != null && department != null)
        ? AppLocalizations.of(context).tr('chat.partner_info',
            params: {'age': age.toString(), 'department': department.toString()})
        : '';

    final isLocked = _isUserPremiumLocked(conversation.feelingPercent);
    final isUnlocked = conversation.feelingPercent >= 100;
    final rawLastMessage = conversation.lastMessage ??
        AppLocalizations.of(context).tr('chat.start_chatting_hint');
    final lastMessage = isLocked
        ? AppLocalizations.of(context).tr('chat.restricted_message')
        : _translateMilestoneLastMessage(context, rawLastMessage);
    final displayFeelingPercent = isLocked ? 75 : conversation.feelingPercent;
    final time = _formatTime(conversation.lastMessageTime);
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              contactName: name,
              mood: null,
              isUnlocked: isUnlocked,
              conversationId: conversation.id,
              partnerId: otherUserId, // Passing partnerId to assist initialization
            ),
          ),
        ).then((_) {
          // ⚡ On return: silent background refresh — no blocking spinner
          _refreshInBackground();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(isUnlocked, hasUnread),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF151515),
                        ),
                      ),
                      if (partnerInfo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            partnerInfo,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF737373),
                            ),
                          ),
                        ),
                      Text(
                        time,
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
                  FeelingProgress(
                    percent: displayFeelingPercent,
                    compact: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread ? const Color(0xFF151515) : const Color(0xFF363636),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateMilestoneLastMessage(BuildContext context, String message) {
    // Maps hardcoded English milestone summaries to their localization keys
    final Map<String, String> milestoneMap = {
      'Quote unlocked': 'chat.milestone_summary_25',
      'Voicemail unlocked': 'chat.milestone_summary_50',
      'Intimacy question unlocked': 'chat.milestone_summary_75',
      'Photo revealed ✨': 'chat.milestone_summary_100',
    };

    if (milestoneMap.containsKey(message)) {
      return AppLocalizations.of(context).tr(milestoneMap[message]!);
    }

    return message;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);

    // Today: show time in 24h format
    if (now.year == localTime.year &&
        now.month == localTime.month &&
        now.day == localTime.day) {
      return DateFormat.Hm().format(localTime);
    }
    // Yesterday
    else if (diff.inDays <= 1 && now.day != localTime.day) {
      return AppLocalizations.of(context).tr('chat.time_yesterday');
    }
    // Within the current week: show day name
    else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(localTime);
    }
    // Older: show month and day
    else {
      return DateFormat('MMM d').format(localTime);
    }
  }

  Widget _buildAvatar(bool isUnlocked, bool hasUnread) {
    // Request: Reduce size drastically, Solid Orange (Unread) vs Solid White (Read).
    // Effectively a status dot, removing the image.
    return Container(
      width: 16, // Much smaller size
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasUnread ? const Color(0xFFFF9800) : Colors.white,
        boxShadow: [
          if (!hasUnread) // Add subtle shadow to white dot to ensure visibility against light background
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
    );
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
          colors: [Color(0xFF0AC5C5), Color(0xFF0AC5C5)],
        );
    }
  }

  Widget _buildArchiveButton() {
    return const SizedBox.shrink(); // Hide archive for now or simplify
  }

  // Removed _buildNavigationBar as it is inline replaced by BottomNavBar in build()
}
