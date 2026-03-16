import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/entitlements_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import 'chat/chat_conversation_screen.dart';
import 'premium_screen.dart';
import 'purchase_scrolls_screen.dart';

class DoorOfDesiresScreen extends StatefulWidget {
  const DoorOfDesiresScreen({super.key});

  @override
  State<DoorOfDesiresScreen> createState() => _DoorOfDesiresScreenState();
}

class _DoorOfDesiresScreenState extends State<DoorOfDesiresScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final List<Map<String, dynamic>> _fantasies = [];
  int _currentIndex = 0;
  bool _loading = false;
  bool _isPremium = false;
  int _page = 0;
  late AnimationController _swipeController;

  // New state for the Gate
  bool _showGate = true;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: -1.0, // Allow left swipe (negative values)
      upperBound: 1.0, // Allow right swipe (positive values)
      value: 0.0, // Start centered
    );
    _init();
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final isPremiumOrWoman =
          await EntitlementsService().isPremiumOrWoman(user.id);
      if (mounted) {
        setState(() {
          _isPremium = isPremiumOrWoman;
        });
      }
    }

    if (_isPremium) {
      await _loadFantasies();
    }
  }

  Future<void> _loadFantasies() async {
    if (_loading) return;

    setState(() => _loading = true);

    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId == null) {
      setState(() => _loading = false);
      return;
    }

    // Load fantasies
    final newFantasies = await _db.listFantasies(page: _page);

    // Filter out anyone they've already messaged
    final filtered = newFantasies.where((f) {
      final fantasyUserId = f['user_id'] as String?;
      debugPrint('🔍 DoorOfDesires: Checking user $fantasyUserId');

      if (fantasyUserId == null) return false;

      // TEMPORARILY DISABLED for verification
      // if (repliedPartnerIds.contains(fantasyUserId)) {
      //   debugPrint('🔍 DoorOfDesires: Skipping $fantasyUserId (already replied)');
      //   return false;
      // }

      return true;
    }).toList();

    debugPrint(
        '🔍 DoorOfDesires: Fetched ${newFantasies.length}, Filtered ${filtered.length}');

    setState(() {
      _fantasies.addAll(filtered);
      _page++;
      _loading = false;
    });
  }

  void _swipeCard(DragUpdateDetails details) {
    setState(() {
      _swipeController.value += details.primaryDelta! / 300;
    });
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_swipeController.value > 0.5 || _swipeController.value < -0.5) {
      // Store the direction before animation
      // REVERSED LOGIC: Positive value = swipe RIGHT = previous (backward)
      // REVERSED LOGIC: Negative value = swipe LEFT = next (forward)
      final bool isRightSwipe = _swipeController.value > 0;

      // Animate to the appropriate end position
      final targetValue = isRightSwipe ? 1.0 : -1.0;
      _swipeController.animateTo(targetValue).then((_) {
        setState(() {
          // Left swipe (negative) - move forward to NEXT
          if (!isRightSwipe && _currentIndex < _fantasies.length - 1) {
            _currentIndex++;
          }
          // Right swipe (positive) - move backward to PREVIOUS
          else if (isRightSwipe && _currentIndex > 0) {
            _currentIndex--;
          }
          _swipeController.value = 0; // Reset to center

          // Load more when near end
          if (_currentIndex >= _fantasies.length - 2 && !_loading) {
            _loadFantasies();
          }
        });
      });
    } else {
      // Return to center
      _swipeController.animateTo(0);
    }
  }

  Future<void> _sendMessage() async {
    if (_fantasies.isEmpty) return;

    final fantasy = _fantasies[_currentIndex];
    final user = AuthService().currentUser;
    if (user == null) return;

    // 1. Check for existing conversation
    // If conversation exists, go directly to chat
    final existingConvId =
        await _db.getConversationId(user.id, fantasy['user_id'] as String);
    if (existingConvId != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            conversationId: existingConvId,
            contactName:
                AppLocalizations.of(context).tr('common.door_of_desires'),
          ),
        ),
      );
      return;
    }

    // 2. Check limits (Scrolls available)
    final hasScrolls = await _db.hasAvailableScrolls(user.id);
    if (!hasScrolls) {
      if (!mounted) return;
      _showOutOfScrollsDialog();
      return;
    }

    // 3. Show message input dialog (like Secret Souls)
    final messageController = TextEditingController();
    if (!mounted) return;
    final message = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFFFAF9F6), // Premium Off-White
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: Color(0xFF8A2BE2)),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(dialogContext).tr('chamber.anonymous_soul'),
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext, null),
                    child: Icon(Icons.close_rounded,
                        size: 22, color: Colors.grey.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (modalContext, setDialogState) {
                  final l10n = AppLocalizations.of(modalContext);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Styled TextField
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: messageController,
                            maxLines: 2,
                            maxLength: 200,
                            autofocus: true,
                            onChanged: (value) => setDialogState(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.tr('chamber.whisper_hint'),
                              hintStyle: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                color: Colors.grey.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                              counterText: '',
                            ),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              color: Color(0xFF2D2D2D),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Action Column
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${messageController.text.length}/200',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Premium Send Button
                          GestureDetector(
                            onTap: () {
                              final msg = messageController.text.trim();
                              if (msg.isNotEmpty) {
                                Navigator.pop(modalContext, msg);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: messageController.text.trim().isEmpty
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : const Color(0xFF8A2BE2),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: messageController.text.trim().isEmpty
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF8A2BE2)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                              ),
                              child: Text(
                                l10n.tr('chamber.send'),
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Subtle Cancel
                          GestureDetector(
                            onTap: () => Navigator.pop(modalContext, null),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                l10n.tr('dialogs.cancel'),
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.grey.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    // If user cancelled or didn't type a message, return
    if (message == null || message.isEmpty || !mounted) return;

    // 3. Send Bottle (NOT Conversation)
    try {
      debugPrint('🚀 Sending fantasy bottle...');
      debugPrint('  Fantasy ID: ${fantasy['id']}');
      debugPrint('  Requester ID: ${user.id}');
      debugPrint('  Owner ID: ${fantasy['user_id']}');
      debugPrint('  Message: $message');

      final l10n = AppLocalizations.of(context);
      final replyPrefix = l10n.tr('chamber.replying_to_content');

      // 3. Deduct scroll (Verify and consume)
      final deducted = await _db.deductScroll(user.id);
      if (!deducted) {
        if (!mounted) return;
        _showOutOfScrollsDialog();
        return;
      }

      final bottleId = await _db.sendDirectBottle(
        senderId: user.id,
        receiverId: fantasy['user_id'] as String,
        contentType: 'text', // Bottle content
        message: message,
        replyToContentType: 'fantasy',
        replyToContent: fantasy['fantasy_text'] as String?,
        replyPrefix: replyPrefix,
      );

      debugPrint('📬 Bottle creation result: $bottleId');

      if (mounted) {
        if (bottleId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)
                  .tr('chamber.bottle_sent_success')),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 4),
            ),
          );

          // Remove the fantasy from the list so they can't reply again
          setState(() {
            if (_currentIndex < _fantasies.length) {
              _fantasies.removeAt(_currentIndex);
              // If list becomes empty or near empty, load more
              if (_fantasies.length < 3) {
                _loadFantasies();
              }
              // Adjust index if needed
              if (_currentIndex >= _fantasies.length) {
                _currentIndex = 0; // Or handle empty state
              }
              // Reset swipe controller just in case
              _swipeController.value = 0;
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context).tr('errors.send_bottle_failed')),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ ERROR sending fantasy bottle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  void _showOutOfScrollsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final tr = AppLocalizations.of(context);
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_edu,
                    size: 50, color: Color(0xFF8A2BE2)),
                const SizedBox(height: 16),
                Text(
                  tr.tr('profile.out_of_scrolls_title'),
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr.tr('profile.out_of_scrolls_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PurchaseScrollsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(tr.tr('profile.get_scrolls')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr.tr('dialogs.cancel'),
                    style: const TextStyle(color: Color(0xFF5D4037)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If Gate is active, show the Gate (Check for premium happens inside or before)
    // The requirement says: "Visible actions: Become Premium (if non-Premium) / Direct access (if Premium)"
    // So we show the Gate first.

    if (_showGate) {
      return _buildGate(context);
    }

    // Default Premium View (The Door of Desires Content)
    final tr = AppLocalizations.of(context);

    // Dark/Mystical Design for Premium
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/door of desires.jpg',
            fit: BoxFit.cover,
          ),

          // Content Overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        tr.tr('home.door_of_desires'),
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Swipe label
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 0, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      tr.tr('chamber.swipe'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),

                // Card Stack Container
                Expanded(
                  child: _loading && _fantasies.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8A2BE2),
                          ),
                        )
                      : _fantasies.isEmpty
                          ? Center(
                              child: Text(
                                AppLocalizations.of(context)
                                    .tr('chamber.no_fantasies'),
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 18,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : _buildCardStack(),
                ),

                // Send Message Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: GestureDetector(
                    onTap: _fantasies.isEmpty ? null : _sendMessage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(
                            0xFF8A2BE2), // Purple/Blueish from reference
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF8A2BE2).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        tr.tr('chamber.send_message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Montserrat', // Button usually sans serif
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGate(BuildContext context) {
    final tr = AppLocalizations.of(context);

    // Background can be the same mystical image but with a dark overlay
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/door of desires.jpg',
            fit: BoxFit.cover,
          ),
          // Dark Overlay
          Container(
            color: Colors.black.withValues(alpha: 0.7),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Title
                  Text(
                    tr.tr('door_of_desires.gate.title'),
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Description
                  Text(
                    tr.tr('door_of_desires.gate.description'),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Action Button
                  if (_isPremium)
                    // Direct Access (Premium)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showGate = false;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A2BE2),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tr.tr('door_of_desires.gate.action.access'),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    // Become Premium (Non-Premium)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PremiumScreen()),
                        ).then(
                            (_) => _init()); // Refresh status after returning
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF00FF), Color(0xFFFF00AA)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF00FF)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tr.tr('door_of_desires.gate.action.premium'),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Close Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      child: Text(
                        tr.tr('door_of_desires.gate.action.close'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight; // Full available height
        final cardWidth = constraints.maxWidth;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Main card (front)
            GestureDetector(
              onHorizontalDragUpdate: _swipeCard,
              onHorizontalDragEnd: _onSwipeEnd,
              child: AnimatedBuilder(
                animation: _swipeController,
                builder: (context, child) {
                  final angle = _swipeController.value *
                      0.1; // Reduced rotation for full screen feel
                  final offset =
                      _swipeController.value * cardWidth; // Swipe full width
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: Transform.rotate(
                      angle: angle,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  color: Colors
                      .transparent, // Transparent to show static background
                  child: Stack(
                    children: [
                      // White Border Inset
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fantasies[_currentIndex]['text']
                                              as String? ??
                                          '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'PlayfairDisplay',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                        height: 1.4,
                                      ),
                                    ),
                                    // User Info display
                                    Builder(builder: (context) {
                                      final profile =
                                          _fantasies[_currentIndex]['profiles'];
                                      if (profile == null) {
                                        return const SizedBox.shrink();
                                      }

                                      final department =
                                          profile['department'] as String?;
                                      final age = profile['age'];

                                      String displayInfo = '';
                                      if (age != null) {
                                        displayInfo = '$age';
                                      }

                                      if (department != null &&
                                          department.isNotEmpty) {
                                        final deptNum =
                                            department.split(' - ').first;
                                        if (displayInfo.isNotEmpty) {
                                          displayInfo = '$displayInfo, $deptNum';
                                        } else {
                                          displayInfo = deptNum;
                                        }
                                      }

                                      if (displayInfo.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.black54,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                displayInfo,
                                                style: const TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
