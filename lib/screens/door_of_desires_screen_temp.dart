import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/database_service.dart';
import '../services/entitlements_service.dart';
import '../services/auth_service.dart';

class DoorOfDesiresScreen extends StatefulWidget {
  const DoorOfDesiresScreen({super.key});

  @override
  State<DoorOfDesiresScreen> createState() => _DoorOfDesiresScreenState();
}

class _DoorOfDesiresScreenState extends State<DoorOfDesiresScreen> {
  final DatabaseService _db = DatabaseService();
  final PageController _pageController = PageController();
  final List<Map<String, dynamic>> _fantasies = [];
  int _currentIndex = 0;
  bool _loading = false;
  bool _isPremium = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final tier = await EntitlementsService().getTier(user.id);
      _isPremium = tier == 'premium' || tier == 'elite';
    }
    
    if (_isPremium) {
      await _loadFantasies();
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _loadFantasies() async {
    if (_loading) return;
    
    setState(() => _loading = true);
    
    final currentUserId = AuthService().currentUser?.id;
    final newFantasies = await _db.listFantasies(page: _page);
    
    // Filter out user's own fantasy
    final filtered = newFantasies.where((f) => f['user_id'] != currentUserId).toList();
    
    setState(() {
      _fantasies.addAll(filtered);
      _page++;
      _loading = false;
    });
  }

  void _nextFantasy() {
    if (_currentIndex < _fantasies.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (!_loading) {
      // Load more fantasies
      _loadFantasies();
    }
  }

  void _previousFantasy() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_fantasies.isEmpty) return;
    
    final fantasy = _fantasies[_currentIndex];
    final user = AuthService().currentUser;
    if (user == null) return;

    // Show confirmation modal
    final confirmed = await showDialog<bool>(
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
                color: Color(0xFFFFD700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start Anonymous Conversation?',
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
                'You will start an anonymous conversation about this fantasy. The owner will see it in their conversations.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5D4037),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
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
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E2723),
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

    if (confirmed != true || !mounted) return;

    // Create conversation
    try {
      final convId = await _db.startAnonymousFantasyConversation(
        fantasyId: fantasy['id'] as String,
        requesterId: user.id,
        ownerId: fantasy['user_id'] as String,
      );

      if (mounted) {
        if (convId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation started! Check your messages.'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
          // Navigate to conversations or stay here
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start conversation'),
              backgroundColor: Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPremium) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF5E6),
                Color(0xFFFFE8CC),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Premium Feature',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Door of Desires is available for Premium members only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E8), // Creamy off-white background
      body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 24,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Door of Desires',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card with navigation
              Expanded(
                child: _loading && _fantasies.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                      )
                    : _fantasies.isEmpty
                        ? const Center(
                            child: Text(
                              'No fantasies available',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                color: Color(0xFF5D4037),
                              ),
                            ),
                          )
                        : Stack(
                            children: [
                              // PageView for cards
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() => _currentIndex = index);
                                  // Load more when near end
                                  if (index >= _fantasies.length - 2) {
                                    _loadFantasies();
                                  }
                                },
                                itemCount: _fantasies.length,
                                itemBuilder: (context, index) {
                                  final fantasy = _fantasies[index];
                                  return _buildFantasyCard(fantasy);
                                },
                              ),

                              // Left arrow
                              if (_currentIndex > 0)
                                Positioned(
                                  left: 8,
                                  top: 0,
                                  bottom: 80,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: _previousFantasy,
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
                                          color: Color(0xFF5D4037),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Right arrow
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 80,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: _nextFantasy,
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
                                        color: Color(0xFF5D4037),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),

              // Send Message Button - iOS pill-shaped
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GestureDetector(
                  onTap: _fantasies.isEmpty ? null : _sendMessage,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _fantasies.isEmpty
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFFFFB703), // Warm orange
                      borderRadius: BorderRadius.circular(27), // Pill-shaped
                      boxShadow: _fantasies.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFFFB703).withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Send a Message',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _fantasies.isEmpty
                            ? const Color(0xFF9E9E9E)
                            : Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFantasyCard(Map<String, dynamic> fantasy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFDDB3), // Warm peachy-orange
              Color(0xFFFFE8C5), // Light peach
              Color(0xFFFFF0D9), // Very light cream-peach
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFDDB3).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Stack(
            children: [
              // Content
              Center(
                child: SingleChildScrollView(
                  child: Text(
                    fantasy['text'] as String? ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFD2691E), // Chocolate orange
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Source label
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Source',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFB8860B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
