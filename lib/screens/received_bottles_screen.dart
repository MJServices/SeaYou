import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/status_bar.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';
import 'premium_screen.dart';
import 'send_bottle_screen.dart';
import '../widgets/voice_chat_modal.dart';
import '../widgets/photo_stamp_modal.dart';
import '../widgets/warm_gradient_background.dart';
import '../i18n/app_localizations.dart';

class ReceivedBottlesScreen extends StatefulWidget {
  final ReceivedBottle? initialBottle;
  const ReceivedBottlesScreen({super.key, this.initialBottle});

  @override
  State<ReceivedBottlesScreen> createState() => _ReceivedBottlesScreenState();
}

class _ReceivedBottlesScreenState extends State<ReceivedBottlesScreen> {
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<ReceivedBottle> _bottles = [];
  bool _isLoading = true;
  String? _gender;
  bool _isPremium = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      if (widget.initialBottle != null) {
        _db.markBottleAsRead(widget.initialBottle!.id);
      } else if (_bottles.isNotEmpty) {
        _db.markBottleAsRead(_bottles[_currentIndex].id);
      }
    });
  }

  Future<void> _loadData() async {
    if (_currentUserId == null) return;

    try {
      final profile = await _db.getProfile(_currentUserId);
      if (profile != null) {
        _gender = profile['gender'];
        // Read tier (text) not is_premium (boolean) for correct premium check
        final tier = profile['tier'] as String? ?? 'free';
        _isPremium = tier == 'premium' || tier == 'elite';
      }

      final allBottles = await _db.getAllReceivedBottles(_currentUserId);

      // Only unreplied bottles, and deduplicate by sender (keep most recent per sender)
      final unreplied = allBottles.where((b) => !b.isReplied).toList();
      final seenSenders = <String?>{};
      final deduplicated = <ReceivedBottle>[];
      for (final b in unreplied) {
        if (!seenSenders.contains(b.senderId)) {
          seenSenders.add(b.senderId);
          deduplicated.add(b);
        }
      }

      if (mounted) {
        setState(() {
          if (widget.initialBottle != null) {
            _bottles = [widget.initialBottle!];
          } else {
            _bottles = deduplicated;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bottles: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleReply(ReceivedBottle bottle) async {
    // Premium Gate check
    final isMale = _gender == 'Man' || _gender == 'Male';
    if (isMale && !_isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumScreen()),
      );
      return;
    }

    // Handle Reply for different types
    if (bottle.contentType == 'text') {
      // Immediate Disappearance
      final bottleId = bottle.id;
      setState(() {
        _bottles.removeWhere((b) => b.id == bottleId);
        if (_currentIndex >= _bottles.length && _bottles.isNotEmpty) {
          _currentIndex = _bottles.length - 1;
        }
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SendBottleScreen(
            replyToBottleId: bottleId,
            replyToUserId: bottle.senderId,
          ),
        ),
      );
      _loadData();
    } else if (bottle.contentType == 'voice') {
      showDialog(
        context: context,
        builder: (context) => VoiceChatModal(
          isReceived: true,
          audioUrl: bottle.audioUrl,
          onReply: () async {
            Navigator.pop(context);
            // Immediate Disappearance: remove from local list before navigating
            final bottleId = bottle.id;
            setState(() {
              _bottles.removeWhere((b) => b.id == bottleId);
              if (_currentIndex >= _bottles.length && _bottles.isNotEmpty) {
                _currentIndex = _bottles.length - 1;
              }
            });

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SendBottleScreen(
                  replyToBottleId: bottleId,
                  replyToUserId: bottle.senderId,
                ),
              ),
            );
            _loadData(); // Still refresh in background
          },
        ),
      );
    } else if (bottle.contentType == 'photo') {
      showDialog(
        context: context,
        builder: (context) => PhotoStampModal(
          imageUrl: bottle.photoUrl ?? '',
          caption: bottle.caption ?? '',
          isReceived: true,
          onReply: () async {
            Navigator.pop(context);
            // Immediate Disappearance
            final bottleId = bottle.id;
            setState(() {
              _bottles.removeWhere((b) => b.id == bottleId);
              if (_currentIndex >= _bottles.length && _bottles.isNotEmpty) {
                _currentIndex = _bottles.length - 1;
              }
            });

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SendBottleScreen(
                  replyToBottleId: bottleId,
                  replyToUserId: bottle.senderId,
                ),
              ),
            );
            _loadData();
          },
        ),
      );
    }
  }

  void _nextBottle() {
    if (_currentIndex < _bottles.length - 1) {
      setState(() => _currentIndex++);
      _db.markBottleAsRead(_bottles[_currentIndex].id);
    }
  }

  void _prevBottle() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _db.markBottleAsRead(_bottles[_currentIndex].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))),
      );
    }

    if (_bottles.isEmpty) {
      return Scaffold(
        body: WarmGradientBackground(
          child: Column(
            children: [
              const CustomStatusBar(),
              _buildHeader(context),
              const Expanded(
                child: Center(
                  child: Text(
                    'No new bottles found.',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        color: Color(0xFF737373)),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }

    final bottle = _bottles[_currentIndex];
    final isMale = _gender == 'Man' || _gender == 'Male';
    final isLocked = isMale && !_isPremium;

    return Scaffold(
      body: WarmGradientBackground(
        child: Column(
          children: [
            // Removed CustomStatusBar() as requested
            const SizedBox(height: 10), // Minimal top padding
            _buildHeader(context),
            // Main Content Area - Fixed Layout (No Scroll)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior
                    .translucent, // Ensure swipes are caught even on empty space
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _prevBottle();
                  } else if (details.primaryVelocity! < 0) {
                    _nextBottle();
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    // Bottle Image - Circular Version
                    Container(
                      width: 160,
                      height: 160,
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
                    const SizedBox(height: 10),
                    // Counter REMOVED as requested
                    /*
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A4A4A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_bottles.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    */
                    const Spacer(flex: 1),
                    // Message Card
                    _buildMessageCard(bottle, isLocked),
                    const Spacer(flex: 2),
                    // Action Button
                    GestureDetector(
                      onTap: () => _handleReply(bottle),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 10),
                        decoration: BoxDecoration(
                          // White border, transparent or semi-transparent fill
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(
                              4), // Slightly rounded corners
                          color: Colors.white.withValues(
                              alpha: 0.2), // Semi-transparent for "glass" feel
                        ),
                        child: Text(
                          isLocked ? 'Upgrade to Read' : 'Répondre',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 18, // Slightly larger
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E3E85), // Purple text
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF151515)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMessageCard(ReceivedBottle bottle, bool isLocked) {
    // Format sender info like Secret Souls: "FirstName, Age - City (DeptNum)"
    String senderInfo = bottle.senderNickname ?? 'Unknown';
    if (bottle.senderAge != null) {
      senderInfo = '${bottle.senderNickname}, ${bottle.senderAge}';

      String locationInfo = '';
      if (bottle.senderCity != null && bottle.senderCity!.isNotEmpty) {
        locationInfo = bottle.senderCity!;
      }
      if (bottle.senderDepartment != null &&
          bottle.senderDepartment!.isNotEmpty) {
        final deptNum = bottle.senderDepartment!.split(' - ').first;
        if (locationInfo.isNotEmpty) {
          locationInfo = '$locationInfo ($deptNum)';
        } else {
          locationInfo = bottle.senderDepartment!;
        }
      }
      if (locationInfo.isNotEmpty) {
        senderInfo = '$senderInfo - $locationInfo';
      }
    }

    return Container(
      width: 320, // Wider
      height: 280, // Fixed height
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Transparent as requested
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
            0), // Sharp or slight radius? Image looks sharp/minimal
        border:
            Border.all(color: Colors.white, width: 3), // Prominent white border
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reply Context (NEW)
          if (bottle.replyToContentType != null) ...[
            Text(
              _getReplyContextLabel(bottle.replyToContentType!),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF737373),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getReplyContextPreview(bottle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              width: 60,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: Center(
              child: isLocked
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: Colors.orange, size: 40),
                        SizedBox(height: 16),
                        Text(
                          'This message is locked.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF151515),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      // Scroll *inside* card if text is long
                      child: Text(
                        bottle.contentType == 'text'
                            ? _getTranslatedMessage(context, bottle.message)
                            : (bottle.contentType == 'voice'
                                ? '🎤 Voice Message'
                                : '📷 Photo Message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20, // Bold large text
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF151515),
                          height: 1.3,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Sender Info with Age/Department (UPDATED)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bottle.senderCity != null || bottle.senderDepartment != null)
                const Icon(Icons.location_on,
                    size: 12, color: Color(0xFF737373)),
              if (bottle.senderCity != null || bottle.senderDepartment != null)
                const SizedBox(width: 4),
              Flexible(
                child: Text(
                  senderInfo,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getReplyContextLabel(String contentType) {
    switch (contentType) {
      case 'quote':
        return 'Reply to your quote:';
      case 'voice':
      case 'audio':
        return 'Reply to your voice message:';
      case 'bio':
        return 'Reply to your bio:';
      case 'fantasy':
        return 'Reply to your fantasy:';
      case 'photo':
        return 'Reply to your photo:';
      default:
        return 'Reply to:';
    }
  }

  String _getReplyContextPreview(ReceivedBottle bottle) {
    if (bottle.replyToContent != null && bottle.replyToContent!.isNotEmpty) {
      return '"${bottle.replyToContent}"';
    }

    switch (bottle.replyToContentType) {
      case 'voice':
      case 'audio':
        return '🎤 Voice message';
      case 'photo':
        return '📷 Photo';
      default:
        return '';
    }
  }

  String _getTranslatedMessage(BuildContext context, String? message) {
    if (message == null) return '';
    final l10n = AppLocalizations.of(context);

    if (message.startsWith('Replying to bio: ')) {
      return message.replaceFirst(
          'Replying to bio: ', l10n.tr('chamber.replying_to_bio'));
    } else if (message.startsWith('Replying to: ')) {
      return message.replaceFirst(
          'Replying to: ', l10n.tr('chamber.replying_to_content'));
    }
    return message;
  }
}
