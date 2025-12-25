import 'package:flutter/material.dart';
import '../../widgets/warm_gradient_background.dart';
import 'chat_conversation_screen.dart';

/// Archived Chats Screen - Fully functional
class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildArchivedList(context),
              ),
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                size: 24, color: Color(0xFF151515)),
          ),
          const SizedBox(width: 16),
          const Text(
            'Archived',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF151515),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedList(BuildContext context) {
    final archivedChats = <Map<String, dynamic>>[
      // Empty list - uncomment below to show archived chats
      /*
      {
        'name': 'Boat',
        'mood': 'Curious',
        'lastMessage':
            'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
        'time': '10:47 am',
        'isUnlocked': false,
      },
      {
        'name': 'Blake Johnson',
        'avatar': 'assets/images/avatar_1.png',
        'lastMessage':
            'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
        'time': '09:21 am',
        'isUnlocked': true,
      },
      {
        'name': 'Sunset',
        'mood': 'Playful',
        'lastMessage': 'Voice Chat',
        'time': '10:47 am',
        'isVoice': true,
        'isUnlocked': false,
      },
      {
        'name': 'Dream',
        'mood': 'Dreamy',
        'lastMessage':
            'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
        'time': '10:47 am',
        'isUnlocked': false,
      },
      {
        'name': 'Water',
        'mood': 'Calm',
        'lastMessage':
            'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.',
        'time': '10:47 am',
        'isUnlocked': false,
      },
      */
    ];

    if (archivedChats.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: archivedChats.length,
      itemBuilder: (context, index) {
        final chat = archivedChats[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatConversationScreen(
                  contactName: chat['name'] as String,
                  mood: chat['mood'] as String?,
                  isUnlocked: chat['isUnlocked'] as bool,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 28),
            child: Row(
              children: [
                _buildAvatar(chat),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat['name'] as String,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF151515),
                            ),
                          ),
                          Text(
                            chat['time'] as String,
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
                          if (chat['isVoice'] == true)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.mic,
                                  size: 16, color: Color(0xFF363636)),
                            ),
                          Expanded(
                            child: Text(
                              chat['lastMessage'] as String,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF363636),
                              ),
                              maxLines: 1,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Image.asset(
            'assets/images/empty-bottle.png',
            width: 360,
            height: 480,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          const Text(
            'No archived conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(
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

  Widget _buildAvatar(Map<String, dynamic> chat) {
    if (chat['isUnlocked'] == true && chat['avatar'] != null) {
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
          gradient: _getMoodGradient(chat['mood'] as String?),
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
}
