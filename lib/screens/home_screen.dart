import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/warm_gradient_background.dart';
import 'bottle_detail_screen.dart';
import 'all_bottles_screen.dart';
import 'send_bottle_screen.dart';
import 'chat/chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/voice_chat_modal.dart';
import '../widgets/photo_stamp_modal.dart';
import '../widgets/received_bottles_viewer.dart';
import '../widgets/empty_bottles_state.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';

/// Home Screen - Dynamic with database integration
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  int _receivedCount = 0;
  int _sentCount = 0;
  List<SentBottle> _recentSentBottles = [];
  Map<String, dynamic>? _userProfile;
  String _userName = 'User';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load all data in parallel
      final results = await Future.wait([
        _databaseService.getReceivedBottlesCount(userId),
        _databaseService.getSentBottlesCount(userId),
        _databaseService.getRecentSentBottles(userId, limit: 3),
        _databaseService.getProfile(userId),
      ]);

      if (mounted) {
        setState(() {
          _receivedCount = results[0] as int;
          _sentCount = results[1] as int;
          _recentSentBottles = results[2] as List<SentBottle>;
          _userProfile = results[3] as Map<String, dynamic>?;
          
          // Extract user info
          if (_userProfile != null) {
            _userName = _userProfile!['full_name'] ?? 'User';
            _avatarUrl = _userProfile!['avatar_url'];
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Scrollable content
            Positioned.fill(
              bottom: 76, // Space for navigation bar
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 402,
                      minWidth: screenWidth > 402 ? 402 : screenWidth,
                    ),
                    child: Column(
                      children: [
                        // Hero section with decorative circles
                        SizedBox(
                          height: 570,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Ellipse 2 - Top blur circle
                              Positioned(
                                left: 0,
                                top: -303,
                                child: Container(
                                  width: 400,
                                  height: 400,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0AC5C5)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                              // Ellipse 3 - Middle blur circle
                              Positioned(
                                left: 9,
                                top: 72,
                                child: Container(
                                  width: 400,
                                  height: 400,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0AC5C5)
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              // Hero Image - only show when bottles exist
                              if (_receivedCount > 0)
                                Positioned(
                                  top: 1,
                                  left: 0,
                                  right: 0,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Image.asset(
                                      'assets/images/hero_image.png',
                                      width: 360,
                                      height: 460,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              // Empty bottle image - show when no bottles
                              if (_receivedCount == 0 && !_isLoading)
                                Positioned(
                                  top: 1,
                                  left: 0,
                                  right: 0,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Image.asset(
                                      'assets/images/empty-bottle.png',
                                      width: 360,
                                      height: 460,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              // Header with profile
                              Positioned(
                                left: 15,
                                top: 78,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: _avatarUrl != null
                                              ? NetworkImage(_avatarUrl!)
                                              : const AssetImage(
                                                  'assets/images/profile_avatar.png') as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hey $_userName',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF151515),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Bottles received text (dynamic)
                              Positioned(
                                left: 15,
                                top: 453,
                                right: 15,
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF0AC5C5),
                                        ),
                                      )
                                    : Text(
                                        '$_receivedCount\nbottles received',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF151515),
                                          height: 1.2,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        // View bottle messages button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ReceivedBottlesViewer(),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFAFA),
                                border: Border.all(
                                  color: const Color(0xFF0AC5C5),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Text(
                                'View bottle messages',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0AC5C5),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Sent Bottles section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFCFC),
                              border: Border.all(
                                color: const Color(0xFFE3E3E3),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sent Bottles ($_sentCount)',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF151515),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Show empty state or bottles
                                if (_isLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(40),
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF0AC5C5),
                                      ),
                                    ),
                                  )
                                else if (_sentCount == 0)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: EmptyBottlesState(type: 'sent'),
                                    ),
                                  )
                                else
                                  ..._buildBottleRows(),
                              ],
                            ),
                          ),
                        ),

                        // Bottom padding for scrolling
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Fixed Floating Action Button (Plus Icon)
            Positioned(
              right: 16,
              bottom: 100,
              child: GestureDetector(
                onTap: () async {
                  // Navigate to send bottle screen and refresh on return
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SendBottleScreen(),
                    ),
                  );
                  // Refresh data when returning from send bottle screen
                  _loadData();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0AC5C5),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x331E1E1E),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/plus.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Fixed Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Already on home, refresh data
                        _loadData();
                      },
                      child: _buildNavItem(
                        iconPath: 'assets/icons/home_simple.svg',
                        label: 'Home',
                        isActive: true,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to chat screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                      child: _buildNavItem(
                        iconPath: 'assets/icons/chat_lines.svg',
                        label: 'Chat',
                        isActive: false,
                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBottleRows() {
    final widgets = <Widget>[];
    
    // Build rows of bottles (2 per row) + See all button
    for (int i = 0; i < _recentSentBottles.length; i += 2) {
      final bottle1 = _recentSentBottles[i];
      final bottle2 = i + 1 < _recentSentBottles.length ? _recentSentBottles[i + 1] : null;
      
      widgets.add(
        Row(
          children: [
            Expanded(
              child: _buildDynamicBottleCard(bottle1),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: bottle2 != null
                  ? _buildDynamicBottleCard(bottle2)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      
      if (i + 2 < _recentSentBottles.length) {
        widgets.add(const SizedBox(height: 20));
      }
    }
    
    // Add "See all" button as last item if there are bottles
    if (_recentSentBottles.isNotEmpty) {
      widgets.add(const SizedBox(height: 20));
      widgets.add(
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AllBottlesScreen(
                  isSent: true,
                ),
              ),
            );
          },
          child: Container(
            height: 128,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8FB),
              border: Border.all(
                color: const Color(0xFFE3E3E3),
                width: 0.8,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'See all',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF363636),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SvgPicture.asset(
                    'assets/icons/nav_arrow_down.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF363636),
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildDynamicBottleCard(SentBottle bottle) {
    // Determine card properties based on content type
    Color cardColor;
    String iconPath;
    String title;
    
    switch (bottle.contentType) {
      case 'voice':
        cardColor = const Color(0xFFFFFFFF);
        iconPath = 'assets/icons/microphone.svg';
        title = 'Voice Chat';
        break;
      case 'photo':
        cardColor = const Color(0xFFFFFBF5);
        iconPath = 'assets/icons/media_image.svg';
        title = 'Photo Stamp';
        break;
      case 'text':
      default:
        cardColor = const Color(0xFFFCF8FF);
        iconPath = 'assets/icons/chat_lines.svg';
        title = 'Text';
    }
    
    return GestureDetector(
      onTap: () {
        if (bottle.contentType == 'voice') {
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => VoiceChatModal(
              isReceived: false,
              onReply: () {
                Navigator.pop(context);
              },
            ),
          );
        } else if (bottle.contentType == 'photo') {
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => PhotoStampModal(
              imageUrl: bottle.photoUrl ?? 'assets/images/photo_stamp.png',
              caption: bottle.caption ?? 'Photo',
              isReceived: false,
              onReply: () {
                Navigator.pop(context);
              },
              onPrevious: () {},
              onNext: () {},
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BottleDetailScreen(
                mood: bottle.mood ?? 'Curious',
                messageType: 'Text',
                message: bottle.message ?? '',
                isReceived: false,
              ),
            ),
          );
        }
      },
      child: _buildBottleCard(
        color: cardColor,
        iconPath: iconPath,
        title: title,
        message: bottle.contentType == 'text' ? bottle.message : null,
        hasAudio: bottle.contentType == 'voice',
        hasImage: bottle.contentType == 'photo',
        status: bottle.status,
        isMatched: bottle.isMatched,
      ),
    );
  }

  Widget _buildBottleCard({
    required Color color,
    String? iconPath,
    required String title,
    String? message,
    bool hasAudio = false,
    bool hasImage = false,
    String status = 'floating',
    bool isMatched = false,
  }) {
    // Determine status badge properties
    String statusText;
    Color statusColor;
    IconData? statusIcon;
    
    switch (status) {
      case 'floating':
        statusText = '🌊 Floating';
        statusColor = const Color(0xFF0AC5C5);
        statusIcon = Icons.waves;
        break;
      case 'matched':
        statusText = '✓ Matched';
        statusColor = const Color(0xFF65ADA9);
        statusIcon = Icons.check_circle_outline;
        break;
      case 'delivered':
        statusText = '📬 Delivered';
        statusColor = const Color(0xFFD89736);
        statusIcon = Icons.mail_outline;
        break;
      case 'read':
        statusText = '👁 Read';
        statusColor = const Color(0xFF9B98E6);
        statusIcon = Icons.visibility_outlined;
        break;
      default:
        statusText = 'Sent';
        statusColor = const Color(0xFF737373);
        statusIcon = Icons.send_outlined;
    }
    
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: const Color(0xFFE3E3E3),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          Row(
            children: [
              if (iconPath != null)
                SvgPicture.asset(
                  iconPath,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF151515),
                    BlendMode.srcIn,
                  ),
                ),
              if (iconPath != null) const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Status badge on its own line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final perBar = 3 + 4;
                final count = (constraints.maxWidth / perBar).floor();
                final heights = [12.0, 20.0, 28.0, 16.0, 24.0, 14.0, 22.0, 18.0];
                return Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(count, (index) {
                      return Container(
                        width: 3,
                        height: heights[index % heights.length],
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0AC5C5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ],
          if (hasImage) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/photo_stamp.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF151515),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasAvatar)
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/profile_avatar.png'),
                fit: BoxFit.cover,
              ),
            ),
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
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isActive ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
            letterSpacing: 0.24,
          ),
        ),
      ],
    );
  }
}
