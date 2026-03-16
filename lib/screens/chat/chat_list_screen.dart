import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'chat_conversation_screen.dart';
import '../../widgets/feeling_progress.dart';
import '../../services/database_service.dart';
import '../../models/conversation.dart';
import '../../i18n/app_localizations.dart';

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
  bool _isPremium = false;
  StreamSubscription<Map<String, dynamic>?>? _profileSub;
  int _archivedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadUserProfile();
    _subscribeProfile();
    _loadArchivedCount();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUserId == null) return;
    try {
      final profile = await _db.getProfile(_currentUserId);
      if (profile != null && mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'];
          _userGender = profile['gender'] as String?;
          final tier = profile['tier'] as String? ?? 'free';
          _isPremium = tier == 'premium' || tier == 'elite';
          debugPrint('👤 ChatList: Loaded User Profile: Gender=$_userGender, Tier=$tier, Premium=$_isPremium');
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot load conversations: user not logged in');
      return;
    }
    debugPrint('🔄 Loading conversations for user: $_currentUserId');

    // Get all conversations
    final convs = await _db.getUserConversations(_currentUserId);
    debugPrint('✅ Loaded ${convs.length} conversations');

    // Get blocked user IDs (Users I blocked)
    final blockedByMe = await _db.getBlockedUserIds(_currentUserId);
    // Get blockers (Users who blocked me)
    final blockingMe = await _db.getBlockers(_currentUserId);

    final allBlocked = {...blockedByMe, ...blockingMe};

    debugPrint(
        '🚫 Blocked contexts: ByMe=${blockedByMe.length}, BlockingMe=${blockingMe.length}');

    // Filter out conversations with blocked users (bidirectional)
    final List<Conversation> filteredConvs = [];
    for (var conv in convs) {
      final partnerId =
          conv.userAId == _currentUserId ? conv.userBId : conv.userAId;

      if (!allBlocked.contains(partnerId)) {
        filteredConvs.add(conv);
      } else {
        debugPrint(
            '  - Filtering out conversation with blocked user: $partnerId');
      }
    }

    debugPrint(
        '✅ Showing ${filteredConvs.length} conversations (${convs.length - filteredConvs.length} blocked)');

    for (var conv in filteredConvs) {
      debugPrint(
          '  - Conversation ${conv.id}: user_a=${conv.userAId}, user_b=${conv.userBId}, updated=${conv.lastMessageTime}');
    }

    if (mounted) {
      setState(() {
        _conversations = filteredConvs;
      });
      _loadArchivedCount(); // Refresh archived count when conversations change
    }
  }

  Future<void> _loadArchivedCount() async {
    if (_currentUserId == null) return;
    // Count conversations where is_archived = true
    // For now, set to 0 since we need to check if archived field exists
    // This will be updated when database has archived conversations
    setState(() {
      _archivedCount =
          0; // TODO: Fetch from database when archived feature is implemented
    });
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
            BottomNavBar(
              activeScreen: 'chat',
              userProfile:
                  _avatarUrl != null ? {'avatar_url': _avatarUrl} : null,
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

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab('All', AppLocalizations.of(context).tr('chat.filter_all')),
          const SizedBox(width: 10),
          _buildTab('Unlocked',
              AppLocalizations.of(context).tr('chat.filter_unlocked')),
          const SizedBox(width: 10),
          _buildTab(
              'Anon', AppLocalizations.of(context).tr('chat.filter_anon')),
        ],
      ),
    );
  }

  Widget _buildTab(String filter, String label) {
    bool isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFAFA) : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0AC5C5) : const Color(0xFFE3E3E3),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF363636),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    final conversations = _filteredConversations;
    debugPrint(
        '📋 _buildConversationsList called with ${conversations.length} conversations');

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
    final gender = _userGender?.toLowerCase();
    final isFemale = gender == 'female' || gender == 'woman' || gender == 'femme';
    if (isFemale) return false; // Females not locked by paywall
    return !_isPremium; // Males locked if not premium
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Image.asset(
                'assets/images/empty-bottle.png',
                width: 200,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: _db.getProfile(otherUserId),
      builder: (context, snapshot) {
        // ... (Omitting debug prints for brevity if preferred, or keeping them)
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24), // Reduced margin
            child: Row(
              children: [
                Container(
                  width: 40, // Reduced size
                  height: 40,
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
                      Container(
                          width: 100,
                          height: 16,
                          color: const Color(0xFFE3E3E3)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const SizedBox.shrink(); // Or fallback UI
        }

        // Request: Display actual usernames/full names instead of "anonymous"
        // And prioritize conversation.title if set (nickname)
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
            translatedMask =
                AppLocalizations.of(context).tr('common.secret_soul');
          } else if (m == 'desire' ||
              m == 'fantasy' ||
              m == 'door of desires') {
            translatedMask =
                AppLocalizations.of(context).tr('common.door_of_desires');
          } else if (m == 'anonymous' || m == 'anonymous soul') {
            translatedMask =
                AppLocalizations.of(context).tr('common.anonymous_soul');
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
            ? AppLocalizations.of(context).tr('chat.partner_info', params: {
                'age': age.toString(),
                'department': department.toString()
              })
            : '';

        final isLocked = _isUserPremiumLocked(conversation.feelingPercent);
        final isUnlocked = conversation.feelingPercent >= 100;
        final lastMessage = isLocked 
            ? AppLocalizations.of(context).tr('chat.restricted_message')
            : (conversation.lastMessage ?? AppLocalizations.of(context).tr('chat.start_chatting_hint'));
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
                  mood: null, // Removed hardcoded 'Curious'
                  isUnlocked: isUnlocked,
                  conversationId: conversation.id,
                ),
              ),
            ).then((_) => _loadConversations());
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24), // Reduced spacing
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Center align
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
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
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
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread
                              ? const Color(0xFF151515)
                              : const Color(0xFF363636),
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
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    // Today: show time
    if (diff.inDays == 0) {
      final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final m = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'pm' : 'am';
      return '$h:$m $ampm';
    }
    // Yesterday
    else if (diff.inDays == 1) {
      return AppLocalizations.of(context).tr('chat.time_yesterday');
    }
    // Within the current week: show day name
    else if (diff.inDays < 7) {
      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ];
      return days[time.weekday % 7];
    }
    // Older: show month and day
    else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[time.month - 1]} ${time.day}';
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
