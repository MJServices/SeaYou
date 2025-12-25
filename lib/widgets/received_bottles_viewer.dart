import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/bottle_detail_screen.dart';
import '../screens/send_bottle_screen.dart';
import 'voice_chat_modal.dart';
import 'photo_stamp_modal.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';
import '../i18n/app_localizations.dart';

/// Received Bottles Viewer - Shows received messages one at a time with navigation
/// Displays voice, text, and photo messages separately with arrow navigation
class ReceivedBottlesViewer extends StatefulWidget {
  const ReceivedBottlesViewer({super.key});

  @override
  State<ReceivedBottlesViewer> createState() => _ReceivedBottlesViewerState();
}

class _ReceivedBottlesViewerState extends State<ReceivedBottlesViewer> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  int currentIndex = 0;
  bool _isLoading = true;
  List<ReceivedBottle> _bottles = [];
  bool _showReplied = false; // false = unreplied, true = replied

  @override
  void initState() {
    super.initState();
    _loadBottles();
  }

  Future<void> _loadBottles() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final allBottles = await _databaseService.getAllReceivedBottles(userId);
      
      // Filter based on current tab
      final filteredBottles = allBottles.where((bottle) {
        return _showReplied ? bottle.isReplied : !bottle.isReplied;
      }).toList();
      
      debugPrint('🔍 Loaded ${filteredBottles.length} ${_showReplied ? "replied" : "unreplied"} bottles');

      if (mounted) {
        setState(() {
          _bottles = filteredBottles;
          currentIndex = 0; // Reset to first bottle when switching tabs
          _isLoading = false;
        });
        
        // Mark first bottle as read if exists
        if (_bottles.isNotEmpty) {
          _markAsRead(0);
        }
      }
    } catch (e) {
      debugPrint('Error loading received bottles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(int index) async {
    if (index < 0 || index >= _bottles.length) return;
    
    final bottle = _bottles[index];
    if (!bottle.isRead) {
      await _databaseService.markBottleAsRead(bottle.id);
      // Update local state to reflect read status without full reload
      setState(() {
        _bottles[index] = bottle.copyWith(isRead: true);
      });
    }
  }

  void _nextBottle() {
    if (currentIndex < _bottles.length - 1) {
      setState(() {
        currentIndex++;
      });
      _markAsRead(currentIndex);
    }
  }

  void _previousBottle() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _markAsRead(currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0AC5C5)),
        ),
      );
    }

    if (_bottles.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          // Solid cream background
          color: const Color(0xFFFAF0D6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // No bottles image (full width)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Image.asset(
                  'assets/images/nobottles.jpeg',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // Text with localization (with fallback)
              Builder(
                builder: (context) {
                  try {
                    return Text(
                      _showReplied 
                          ? AppLocalizations.of(context).tr('bottles.empty.replied')
                          : AppLocalizations.of(context).tr('bottles.empty.new'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF151515),
                      ),
                    );
                  } catch (e) {
                    // Fallback if localization not available
                    return Text(
                      _showReplied ? '0 Nouvelles bouteilles répondues' : '0 Nouvelles bouteilles',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF151515),
                      ),
                    );
                  }
                },
              ),
              const Spacer(),
              // Retour button
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE3E3E3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        try {
                          return Text(
                            AppLocalizations.of(context).tr('common.back'),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0AC5C5),
                            ),
                          );
                        } catch (e) {
                          return const Text(
                            'Retour',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0AC5C5),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentBottle = _bottles[currentIndex];
    final type = currentBottle.contentType;

    return Stack(
      children: [
        // Main content based on type
        if (type == 'text')
          BottleDetailScreen(
            mood: currentBottle.mood ?? 'Happy',
            messageType: 'Text',
            message: currentBottle.message ?? '',
            isReceived: true,
            bottleId: currentBottle.id,
            senderId: currentBottle.senderId,
            isReplied: currentBottle.isReplied,
          )
        else if (type == 'voice')
          VoiceChatModal(
            isReceived: true,
            audioUrl: () {
              debugPrint('🎵 Voice Bottle Data:');
              debugPrint('  - contentType: ${currentBottle.contentType}');
              debugPrint('  - audioUrl: ${currentBottle.audioUrl}');
              debugPrint('  - message: ${currentBottle.message}');
              debugPrint('  - id: ${currentBottle.id}');
              return currentBottle.audioUrl;
            }(),
            duration: '00:00:21', // TODO: Calculate from audio file
            onReply: () async {
              Navigator.pop(context); // Close modal
              // Navigate to SendBottleScreen with reply context
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SendBottleScreen(
                    replyToBottleId: currentBottle.id,
                    replyToUserId: currentBottle.senderId,
                  ),
                ),
              );
            },
          )
        else if (type == 'photo')
          PhotoStampModal(
            imageUrl: currentBottle.photoUrl ?? '',
            caption: currentBottle.caption ?? '',
            isReceived: true,
            onReply: () async {
              Navigator.pop(context); // Close modal
              // Navigate to SendBottleScreen with reply context
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SendBottleScreen(
                    replyToBottleId: currentBottle.id,
                    replyToUserId: currentBottle.senderId,
                  ),
                ),
              );
            },
            onPrevious: currentIndex > 0 ? _previousBottle : null,
            onNext: currentIndex < _bottles.length - 1 ? _nextBottle : null,
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
          if (currentIndex < _bottles.length - 1)
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
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1} / ${_bottles.length}',
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

        // Filter toggle button at top-right
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() => _showReplied = !_showReplied);
              _loadBottles();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _showReplied 
                    ? [const Color(0xFF737373), const Color(0xFF5A5A5A)]
                    : [const Color(0xFF0AC5C5), const Color(0xFF08A3A3)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showReplied ? Icons.history : Icons.mail,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showReplied ? 'Replied' : 'New',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    // Removed - using floating button instead
    return const SizedBox.shrink();
  }
}
