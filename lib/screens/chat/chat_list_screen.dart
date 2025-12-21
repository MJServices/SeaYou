import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../profile_screen.dart';
import '../door_of_desires_screen.dart';
import 'chat_conversation_screen.dart';
import 'archived_chats_screen.dart';
import '../../widgets/feeling_progress.dart';
import '../../services/database_service.dart';
import '../../models/conversation.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadUserAvatar();
  }

  Future<void> _loadUserAvatar() async {
    if (_currentUserId == null) return;
    try {
      final profile = await _db.getProfile(_currentUserId!);
      if (profile != null && mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot load conversations: user not logged in');
      return;
    }
    debugPrint('🔄 Loading conversations for user: $_currentUserId');
    final convs = await _db.getUserConversations(_currentUserId!);
    debugPrint('✅ Loaded ${convs.length} conversations');
    for (var conv in convs) {
      debugPrint('  - Conversation ${conv.id}: user_a=${conv.userAId}, user_b=${conv.userBId}, updated=${conv.lastMessageTime}');
    }
    if (mounted) {
      setState(() {
        _conversations = convs;
      });
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
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildFilterTabs(),
              Expanded(
                child: _buildConversationsList(),
              ),
              _buildArchiveButton(),
              _buildNavigationBar(context),
            ],
          ),
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
          const Text(
            'Connections',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF151515),
            ),
          ),
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
                  hintText: 'Search conversations...',
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
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
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
    super.dispose();
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab('All'),
          const SizedBox(width: 10),
          _buildTab('Unlocked'),
          const SizedBox(width: 10),
          _buildTab('Anon'),
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
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
    debugPrint('📋 _buildConversationsList called with ${conversations.length} conversations');

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

    debugPrint('✅ Building ListView with ${conversations.length} conversations');
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          debugPrint('  Building conversation item $index: ${conversations[index].id}');
          return _buildConversationItem(conversations[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    String emptyMessage = _selectedFilter == 'Anon'
        ? 'You do not have any locked conversations here'
        : _selectedFilter == 'Unlocked'
            ? 'Keep the conversations going to unlock a connection'
            : 'You have not established a connection yet. Retrieve a bottle or wait for your bottle to be retrieved.';

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
    
    final otherUserId = conversation.getOtherUserId(_currentUserId!);
    debugPrint('  👤 Building conversation item, fetching profile for: $otherUserId');
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: _db.getProfile(otherUserId),
      builder: (context, snapshot) {
        debugPrint('  📊 Profile FutureBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('  ❌ Profile fetch error: ${snapshot.error}');
        }
        // Show skeleton only while actively loading
        if (snapshot.connectionState != ConnectionState.done) {
          // Loading skeleton or simple placeholder
          return Container(
            margin: const EdgeInsets.only(bottom: 28),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE3E3E3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 16, color: const Color(0xFFE3E3E3)),
                      const SizedBox(height: 6),
                      Container(width: 200, height: 12, color: const Color(0xFFE3E3E3)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Profile loaded (or null if doesn't exist) - display conversation anyway
        final profile = snapshot.data ?? {};
        final name = conversation.feelingPercent >= 100 
            ? (profile['full_name'] ?? 'Unknown') 
            : (conversation.title ?? 'Anonymous');
        // Use profile mood if available, otherwise default
        final mood = 'Curious'; // TODO: Store mood in profile or conversation
        final isUnlocked = conversation.feelingPercent >= 100;
        final lastMessage = conversation.lastMessage ?? 'Start chatting...';
        final time = _formatTime(conversation.lastMessageTime);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatConversationScreen(
                  contactName: name,
                  mood: mood,
                  isUnlocked: isUnlocked,
                  conversationId: conversation.id,
                ),
              ),
            ).then((_) => _loadConversations()); // Refresh on return
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(isUnlocked, mood, profile['avatar_url']),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF151515),
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
                      const SizedBox(height: 6),
                      FeelingProgress(
                        percent: conversation.feelingPercent,
                        compact: true,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF363636),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
    
    if (diff.inDays == 0) {
      final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final m = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'pm' : 'am';
      return '$h:$m $ampm';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  Widget _buildAvatar(bool isUnlocked, String mood, String? avatarUrl) {
    if (isUnlocked) {
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE3E3E3),
        ),
        child: avatarUrl != null 
            ? ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Image.network(avatarUrl, fit: BoxFit.cover),
              )
            : const Icon(Icons.person, color: Color(0xFF737373)),
      );
    } else {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getMoodGradient(mood),
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
          colors: [Color(0xFF0AC5C5), Color(0xFF0AC5C5)],
        );
    }
  }

  Widget _buildArchiveButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE3E3E3), width: 0.5),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ArchivedChatsScreen(),
            ),
          );
        },
        child: const Center(
          child: Text(
            'View Archived (32)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF0AC5C5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: _buildNavItem(
              iconPath: 'assets/icons/home_simple.svg',
              label: 'Home',
              isActive: false,
            ),
          ),
          _buildNavItem(
            iconPath: 'assets/icons/chat_lines.svg',
            label: 'Chat',
            isActive: true,
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DoorOfDesiresScreen(),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.door_front_door_outlined,
                  size: 24,
                  color: Color(0xFF737373),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Desires',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            child: _buildNavItem(
              iconPath: null,
              label: 'Profile',
              isActive: false,
              hasAvatar: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    String? iconPath,
    required String label,
    required bool isActive,
    bool hasAvatar = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAvatar)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE0E0E0),
              image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 16, color: Color(0xFF737373))
                : null,
          )
        else if (iconPath != null)
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
              BlendMode.srcIn,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
          ),
        ),
      ],
    );
  }
}
