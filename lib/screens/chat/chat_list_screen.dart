import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/warm_gradient_background.dart';
import '../profile_screen.dart';
import 'chat_conversation_screen.dart';
import 'archived_chats_screen.dart';

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

  final List<Map<String, dynamic>> _allConversations = [
    {
      'name': 'Boat',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '10:47 am',
      'mood': 'Curious',
      'isUnlocked': false,
    },
    {
      'name': 'Blake Johnson',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '09:21 am',
      'avatar': 'assets/images/avatar_1.png',
      'isUnlocked': true,
    },
    {
      'name': 'Sunset',
      'lastMessage': 'Voice Chat',
      'time': '10:47 am',
      'mood': 'Playful',
      'isVoice': true,
      'isUnlocked': false,
    },
    {
      'name': 'Violet Harrid',
      'lastMessage': 'Picture',
      'time': '10:47 am',
      'avatar': 'assets/images/avatar_2.png',
      'isImage': true,
      'isUnlocked': true,
    },
    {
      'name': 'Dream',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '10:47 am',
      'mood': 'Dreamy',
      'isUnlocked': false,
    },
    {
      'name': 'May Wint',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '10:47 am',
      'avatar': 'assets/images/avatar_3.png',
      'isUnlocked': true,
    },
    {
      'name': 'Water',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '10:47 am',
      'mood': 'Calm',
      'isUnlocked': false,
    },
    {
      'name': 'Alexis Warren',
      'lastMessage':
          'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
      'time': '10:47 am',
      'avatar': 'assets/images/avatar_4.png',
      'isUnlocked': true,
    },
    {
      'name': 'Spring',
      'lastMessage': 'Voice Chat',
      'time': '10:47 am',
      'mood': 'Dreamy',
      'isVoice': true,
      'isUnlocked': false,
    },
    {
      'name': 'Sorren Xaden',
      'lastMessage': 'Voice Chat',
      'time': '10:47 am',
      'avatar': 'assets/images/avatar_5.png',
      'isVoice': true,
      'isUnlocked': true,
    },
    {
      'name': 'Ocean',
      'lastMessage': 'That sounds amazing! I would love to see that picture.',
      'time': '08:15 am',
      'mood': 'Calm',
      'isUnlocked': false,
    },
    {
      'name': 'Emma Stone',
      'lastMessage': 'Thanks for sharing that with me!',
      'time': '07:45 am',
      'avatar': 'assets/images/avatar_1.png',
      'isUnlocked': true,
    },
    {
      'name': 'Moonlight',
      'lastMessage': 'Picture',
      'time': '07:30 am',
      'mood': 'Dreamy',
      'isImage': true,
      'isUnlocked': false,
    },
    {
      'name': 'Adventure',
      'lastMessage':
          'I went hiking yesterday and the view from the top was breathtaking!',
      'time': '06:52 am',
      'mood': 'Curious',
      'isUnlocked': false,
    },
    {
      'name': 'Sarah Miller',
      'lastMessage': 'Good morning! How are you today?',
      'time': '06:20 am',
      'avatar': 'assets/images/avatar_2.png',
      'isUnlocked': true,
    },
    {
      'name': 'Sunrise',
      'lastMessage': 'Voice Chat',
      'time': '05:45 am',
      'mood': 'Playful',
      'isVoice': true,
      'isUnlocked': false,
    },
    {
      'name': 'Michael Chen',
      'lastMessage': 'See you later!',
      'time': 'Yesterday',
      'avatar': 'assets/images/avatar_3.png',
      'isUnlocked': true,
    },
    {
      'name': 'Forest',
      'lastMessage':
          'The trees here are so peaceful. I could stay here forever.',
      'time': 'Yesterday',
      'mood': 'Calm',
      'isUnlocked': false,
    },
    {
      'name': 'Joy',
      'lastMessage': 'Picture',
      'time': 'Yesterday',
      'mood': 'Playful',
      'isImage': true,
      'isUnlocked': false,
    },
    {
      'name': 'David Park',
      'lastMessage': 'That was a great conversation!',
      'time': 'Yesterday',
      'avatar': 'assets/images/avatar_4.png',
      'isUnlocked': true,
    },
    {
      'name': 'Starlight',
      'lastMessage': 'Voice Chat',
      'time': 'Yesterday',
      'mood': 'Dreamy',
      'isVoice': true,
      'isUnlocked': false,
    },
    {
      'name': 'Lisa Anderson',
      'lastMessage': 'Looking forward to our next chat!',
      'time': 'Yesterday',
      'avatar': 'assets/images/avatar_5.png',
      'isUnlocked': true,
    },
    {
      'name': 'Thunder',
      'lastMessage':
          'The storm last night was incredible. Did you see the lightning?',
      'time': 'Yesterday',
      'mood': 'Curious',
      'isUnlocked': false,
    },
    {
      'name': 'Peace',
      'lastMessage': 'Just enjoying the quiet moments of life.',
      'time': '2 days ago',
      'mood': 'Calm',
      'isUnlocked': false,
    },
    {
      'name': 'Rainbow',
      'lastMessage': 'Picture',
      'time': '2 days ago',
      'mood': 'Playful',
      'isImage': true,
      'isUnlocked': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredConversations {
    var conversations = _allConversations;

    // Apply filter
    if (_selectedFilter == 'Unlocked') {
      conversations =
          conversations.where((conv) => conv['isUnlocked'] == true).toList();
    } else if (_selectedFilter == 'Anon') {
      conversations =
          conversations.where((conv) => conv['isUnlocked'] == false).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      conversations = conversations.where((conv) {
        final name = conv['name'].toString().toLowerCase();
        final message = conv['lastMessage'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || message.contains(query);
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

    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        return _buildConversationItem(conversations[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    String emptyMessage = _selectedFilter == 'Anon'
        ? 'You do not have any locked conversations here'
        : _selectedFilter == 'Unlocked'
            ? 'Keep the conversations going to unlock a connection'
            : 'You have not established a connection yet. Retrieve a bottle or wait for your bottle to be retrieved.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Image.asset(
            'assets/images/empty bottle.png',
            width: 360,
            height: 480,
            fit: BoxFit.contain,
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
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              contactName: conversation['name'],
              mood: conversation['mood'],
              isUnlocked: conversation['isUnlocked'] ?? false,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(conversation),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        conversation['name'],
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                      Text(
                        conversation['time'],
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
                  Row(
                    children: [
                      if (conversation['isVoice'] == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.mic,
                              size: 16, color: Color(0xFF363636)),
                        ),
                      if (conversation['isImage'] == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.image,
                              size: 16, color: Color(0xFF363636)),
                        ),
                      Expanded(
                        child: Text(
                          conversation['lastMessage'],
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
  }

  Widget _buildAvatar(Map<String, dynamic> conversation) {
    if (conversation['isUnlocked'] == true && conversation['avatar'] != null) {
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE3E3E3),
        ),
        child: const Icon(Icons.person, color: Color(0xFF737373)),
      );
    } else {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getMoodGradient(conversation['mood']),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE3E3E3),
            ),
            child: const Icon(Icons.person, size: 16, color: Color(0xFF737373)),
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
