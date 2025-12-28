import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/entitlements_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import '../utils/app_text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      final tier = await EntitlementsService().getTier(user.id);
      if (mounted) {
        setState(() {
          _isPremium = tier == 'premium' || tier == 'elite';
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
    final newFantasies = await _db.listFantasies(page: _page);

    // Filter out user's own fantasy
    final filtered =
        newFantasies.where((f) => f['user_id'] != currentUserId).toList();

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
      // Complete the swipe
      _swipeController.forward().then((_) {
        setState(() {
          if (_currentIndex < _fantasies.length - 1) {
            _currentIndex++;
          }
          _swipeController.reset();

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

    // Show message input dialog (like Secret Souls)
    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.message_outlined,
                size: 48,
                color: Color(0xFF8A2BE2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start Anonymous Conversation',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Write your first message to start the conversation about this fantasy',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5D4037),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Message input field
              TextField(
                controller: messageController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF9E9E9E),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final msg = messageController.text.trim();
                        if (msg.isNotEmpty) {
                          Navigator.pop(dialogContext, msg);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2BE2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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

    // If user cancelled or didn't type a message, return
    if (message == null || message.isEmpty || !mounted) return;

    // Create conversation WITH the message
    try {
      debugPrint('🚀 Attempting to create fantasy conversation...');
      debugPrint('  Fantasy ID: ${fantasy['id']}');
      debugPrint('  Requester ID: ${user.id}');
      debugPrint('  Owner ID: ${fantasy['user_id']}');
      debugPrint('  Message: $message');
      
      final convId = await _db.startAnonymousFantasyConversation(
        fantasyId: fantasy['id'] as String,
        requesterId: user.id,
        ownerId: fantasy['user_id'] as String,
        initialMessage: message, // Pass the message
      );

      debugPrint('📬 Conversation creation result: $convId');

      if (mounted) {
        if (convId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent! They will see it in their conversations.'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message - conversation creation failed'),
              backgroundColor: Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ ERROR sending fantasy message: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    }
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
                                'No fantasies available',
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
                        color: const Color(0xFF8A2BE2), // Purple/Blueish from reference
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.4),
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
                              color: const Color(0xFF8A2BE2).withValues(alpha: 0.4),
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
                        // TODO: Navigate to Premium Subscribe Screen
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Navigate to Premium Subscription')),
                        );
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
                              color: const Color(0xFFFF00FF).withValues(alpha: 0.3),
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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
                  final angle = _swipeController.value * 0.1; // Reduced rotation for full screen feel
                  final offset = _swipeController.value * cardWidth; // Swipe full width
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
                  color: Colors.transparent, // Transparent to show static background
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
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SingleChildScrollView(
                                child: Text(
                                  _fantasies[_currentIndex]['text'] as String? ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.4,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 4,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
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
