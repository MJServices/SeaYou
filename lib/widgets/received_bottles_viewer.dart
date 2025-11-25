import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/bottle_detail_screen.dart';
import 'voice_chat_modal.dart';
import 'photo_stamp_modal.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';

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

      final bottles = await _databaseService.getAllReceivedBottles(userId);
      
      debugPrint('🔍 Loaded ${bottles.length} bottles');
      for (var b in bottles) {
        debugPrint('📝 Bottle ID: ${b.id}, Content: ${b.message}, Type: ${b.contentType}');
      }

      if (mounted) {
        setState(() {
          _bottles = bottles;
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No bottles received yet',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0AC5C5),
                ),
                child: const Text('Go Back'),
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
            // Pass navigation callbacks to BottleDetailScreen if needed, 
            // but currently we handle navigation here with overlay arrows
          )
        else if (type == 'voice')
          VoiceChatModal(
            isReceived: true,
            duration: '00:00', // TODO: Store duration in DB or fetch metadata
            onReply: () {
              Navigator.pop(context);
            },
          )
        else if (type == 'photo')
          PhotoStampModal(
            imageUrl: currentBottle.photoUrl ?? '',
            caption: currentBottle.caption ?? '',
            isReceived: true,
            onReply: () {
              Navigator.pop(context);
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

          // Counter indicator - Moved to top to avoid overlap
          Positioned(
            top: 60,
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
      ],
    );
  }
}
