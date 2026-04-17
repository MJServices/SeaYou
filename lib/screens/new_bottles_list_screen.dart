import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/entitlements_service.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';
import 'received_bottles_screen.dart'; // To navigate to detailed view
import 'premium_screen.dart';
import '../widgets/warm_gradient_background.dart';
import '../i18n/app_localizations.dart';

class NewBottlesListScreen extends StatefulWidget {
  const NewBottlesListScreen({super.key});

  @override
  State<NewBottlesListScreen> createState() => _NewBottlesListScreenState();
}

class _NewBottlesListScreenState extends State<NewBottlesListScreen> {
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<ReceivedBottle> _bottles = [];
  bool _isLoading = true;
  bool _isAccessGranted = false;
  StreamSubscription? _bottleSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToBottles();
  }

  @override
  void dispose() {
    _bottleSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBottles() {
    if (_currentUserId == null) return;

    _bottleSubscription = Supabase.instance.client
        .from('received_bottles')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', _currentUserId)
        .listen((_) {
          if (mounted) {
            _loadData();
          }
        });
  }

  Future<void> _loadData() async {
    if (_currentUserId == null) return;

    try {
      final profile = await _db.getProfile(_currentUserId);
      if (profile != null) {
        // Use EntitlementsService for more robust check (Premium OR Woman)
        // This is our single source of truth for free access
        _isAccessGranted =
            await EntitlementsService().isPremiumOrWoman(_currentUserId);
      }

      final allBottles = await _db.getAllReceivedBottles(_currentUserId, forceRefresh: true);
      // Deduplicate by sender (one bottle per sender)
      final seenSenders = <String?>{};
      final deduplicated = <ReceivedBottle>[];
      for (final b in allBottles) {
        if (!seenSenders.contains(b.senderId)) {
          seenSenders.add(b.senderId);
          deduplicated.add(b);
        }
      }

      if (mounted) {
        setState(() {
          _bottles = deduplicated;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bottles list: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBottleTap(int index) {
    if (_isLocked()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumScreen()),
      );
    } else {
      // Navigate to the existing swipeable view, starting at this bottle
      // We need to update ReceivedBottlesScreen to accept an initialIndex if possible
      // Or just push it (it loads all bottles anyway)
      // Ideally we modify ReceivedBottlesScreen to accept 'initialIndex'
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceivedBottlesScreen(
            initialBottle: _bottles[index],
          ),
        ),
      ).then((_) => _loadData());
    }
  }

  bool _isLocked() {
    return !_isAccessGranted;
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isLocked();

    if (!_isLoading && _bottles.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF0D6), // Warm sand — matches nobottles.jpeg background
        body: SafeArea(
          child: Column(
            children: [
              // Simple back arrow — no fake status bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF5C4A2A)),
                    ),
                  ],
                ),
              ),
              // Image fills most of the screen
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/nobottles.jpeg',
                          width: 320,
                          height: 320,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.mail_outline,
                            size: 120,
                            color: Color(0xFF8D6E63),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context).tr('bottles.no_new_bottles'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0AC5C5)))
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)
                                .tr('bottles.list_title_new'),
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 22, // Matches image
                              fontWeight: FontWeight.w700,
                              color: Color(
                                  0xFF9E3E85), // Purple/Pink color from image
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/homepage_bottle.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.mail_outline,
                                    size: 80,
                                    color: Color(0xFF8D6E63)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _bottles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final bottle = _bottles[index];
                          // "Nouveau message de Sophie"
                          final displayName =
                              bottle.senderNickname ?? 'Unknown';
                          final text = AppLocalizations.of(context).tr(
                            'bottles.new_message_from',
                            params: {'name': displayName},
                          );

                          return GestureDetector(
                            onTap: () => _handleBottleTap(index),
                            child: Row(
                              children: [
                                // Dot indicator
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: bottle.isRead
                                        ? Colors.white
                                        : const Color(0xFFEAA900),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Text content
                                Expanded(
                                  child: locked
                                      ? ImageFiltered(
                                          imageFilter: ImageFilter.blur(
                                              sigmaX: 5, sigmaY: 5),
                                          child: Text(
                                            text,
                                            style: const TextStyle(
                                              fontFamily:
                                                  'PlayfairDisplay', // Looks serif in image
                                              fontSize: 18,
                                              color: Color(0xFF4A4A4A),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          text,
                                          style: const TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            fontSize: 18,
                                            color: Color(0xFF4A4A4A),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Upgrade Button (if locked)
                    if (locked)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const PremiumScreen()),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0AC5C5), // Turquoise
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              AppLocalizations.of(context)
                                  .tr('bottles.go_premium'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bottom Navigation Bar placeholder (visual only, real one is in MainScaffold)
                    // Since we push this screen, we might hide the main nav or just show back button?
                    // The image shows the main nav bar.
                    // If we replace the Home View with this, we keep the nav bar.
                    // But navigation.push covers the nav bar usually unless we use nested nav.
                    // For now, let's just assume standard push behavior and maybe add a back button or close logic if needed.
                    // Update: Image DOES show the Bottom Nav. This implies this might be a "new page" inside the Home Tab interaction.

                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
