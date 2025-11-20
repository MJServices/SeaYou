import 'package:flutter/material.dart';
import '../screens/bottle_detail_screen.dart';
import 'voice_chat_modal.dart';
import 'photo_stamp_modal.dart';

/// Received Bottles Viewer - Shows received messages one at a time with navigation
/// Displays voice, text, and photo messages separately with arrow navigation
class ReceivedBottlesViewer extends StatefulWidget {
  const ReceivedBottlesViewer({super.key});

  @override
  State<ReceivedBottlesViewer> createState() => _ReceivedBottlesViewerState();
}

class _ReceivedBottlesViewerState extends State<ReceivedBottlesViewer> {
  int currentIndex = 0;

  // Sample received bottles data - voice, text, and photo messages
  final List<Map<String, dynamic>> bottles = [
    {
      'type': 'text',
      'mood': 'Dreamy',
      'message':
          'Hi. Prior to our previous conversation, I saw the river you mentioned while taking a walk after a pretty chill day. The sight was truly amazing as you described. The sun on the river was beautiful as you described.\n\nI could attach a picture I took of it if you do not mind. Let me know if you\'ll be willing to rate my non-photography skill.',
    },
    {
      'type': 'text',
      'mood': 'Curious',
      'message':
          'Hi. Prior to our previous conversation, I saw the river you mentioned while taking a walk after a pretty chill day. The sight was truly amazing as you described. The sun on the river was beautiful as you described.\n\nI could attach a picture I took of it if you do not mind. Let me know if you\'ll be willing to rate my non-photography skill.',
    },
    {
      'type': 'voice',
      'mood': 'Playful',
      'duration': '00:12:19',
    },
    {
      'type': 'photo',
      'mood': 'Calm',
      'imageUrl': 'assets/images/photo_stamp.png',
      'caption': 'The picture',
    },
  ];

  void _nextBottle() {
    if (currentIndex < bottles.length - 1) {
      setState(() {
        currentIndex++;
      });
    }
  }

  void _previousBottle() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBottle = bottles[currentIndex];
    final type = currentBottle['type'] as String;

    return Stack(
      children: [
        // Main content based on type
        if (type == 'text')
          BottleDetailScreen(
            mood: currentBottle['mood'] as String,
            messageType: 'Text',
            message: currentBottle['message'] as String,
            isReceived: true,
          )
        else if (type == 'voice')
          VoiceChatModal(
            isReceived: true,
            duration: currentBottle['duration'] as String? ?? '00:00:00',
            onReply: () {
              Navigator.pop(context);
            },
          )
        else if (type == 'photo')
          PhotoStampModal(
            imageUrl: currentBottle['imageUrl'] as String,
            caption: currentBottle['caption'] as String? ?? '',
            isReceived: true,
            onReply: () {
              Navigator.pop(context);
            },
            onPrevious: currentIndex > 0 ? _previousBottle : null,
            onNext: currentIndex < bottles.length - 1 ? _nextBottle : null,
          ),

        // Navigation arrows overlay (for text and voice only)
        if (type != 'photo') ...[
          // Left arrow
          if (currentIndex > 0)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: GestureDetector(
                onTap: _previousBottle,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xFF0AC5C5),
                    size: 20,
                  ),
                ),
              ),
            ),

          // Right arrow
          if (currentIndex < bottles.length - 1)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: GestureDetector(
                onTap: _nextBottle,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF0AC5C5),
                    size: 20,
                  ),
                ),
              ),
            ),

          // Counter indicator
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1} / ${bottles.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
