import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../i18n/app_localizations.dart';
import 'chat/chat_conversation_screen.dart';
import 'premium_screen.dart';
import '../services/entitlements_service.dart';

class SecretSoulsScreen extends StatefulWidget {
  const SecretSoulsScreen({super.key});

  @override
  State<SecretSoulsScreen> createState() => _SecretSoulsScreenState();
}

class _SecretSoulsScreenState extends State<SecretSoulsScreen> {
  final DatabaseService _db = DatabaseService();
  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final List<Map<String, dynamic>> _content = [];
  String _selectedFilter = 'all'; // all, photo, audio, quote
  int _currentIndex = 0;
  int _page = 0;
  bool _loading = false;
  bool _isPremium = false;
  bool _showGate = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final isPremiumOrWoman = await EntitlementsService().isPremiumOrWoman(user.id);
      if (mounted) {
        setState(() {
          _isPremium = isPremiumOrWoman;
        });
      }
    }

    if (_isPremium) {
      _loadContent();
    }
  }



  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadContent({int recursionCount = 0}) async {
    if (_loading) return;
    if (recursionCount > 5) { // Limit recursion to avoid infinite loops
      setState(() => _loading = false);
      return;
    }
    
    setState(() => _loading = true);
    
    final user = AuthService().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    // Get IDs of users we've already replied to
    final repliedPartnerIds = await _db.getRepliedPartnerIds(user.id);
    
    final contentType = _selectedFilter == 'all' ? null : _selectedFilter;
    final newContent = await _db.getSecretSoulsContent(
      contentType: contentType,
      page: _page,
    );
    
    if (newContent.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Filter out items from users we've already messaged (Double safety: exclude self)
    final filteredContent = newContent.where((item) {
      final itemUserId = item['user_id'] as String?;
      return itemUserId != null && itemUserId != user.id && !repliedPartnerIds.contains(itemUserId);
    }).toList();
    
    if (filteredContent.isEmpty && newContent.isNotEmpty) {
      // All items in this page were filtered out, try next page
      _page++;
      _loading = false; // Reset to allow next call
      return _loadContent(recursionCount: recursionCount + 1);
    }

    setState(() {
      _content.addAll(filteredContent);
      _page++;
      _loading = false;
    });
  }

  void _changeFilter(String filter) {
    if (_selectedFilter == filter) return;
    
    setState(() {
      _selectedFilter = filter;
      _content.clear();
      _page = 0;
      _currentIndex = 0;
    });
    
    _loadContent();
  }

  void _nextContent() {
    if (_currentIndex < _content.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (!_loading) {
      _loadContent();
    }
  }

  void _previousContent() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_content.isEmpty) return;
    
    final content = _content[_currentIndex];
    final user = AuthService().currentUser;
    if (user == null) return;

    // 1. Check for existing conversation
    // If we already have a chat, open it directly
    final existingConvId = await _db.getConversationId(user.id, content['user_id'] as String);
    if (existingConvId != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            conversationId: existingConvId,
            contactName: 'Secret Soul',
          ),
        ),
      );
      return;
    }
    
    // 2. Check limits (Max 3 per week)
    final canSend = await _db.canSendMessageThisWeek(user.id);
    if (!canSend) {
      if (!mounted) return;
      _showLimitReachedDialog();
      return;
    }

    // 3. Show message input dialog
    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFFFFFDF5), // Premium light cream
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
                   const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFD4B483)),
                   const SizedBox(width: 8),
                   const Text(
                    'Secret Whisper',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext, null),
                    child: Icon(Icons.close_rounded, size: 22, color: Colors.grey.withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDialogState) {
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
                                color: Colors.black.withOpacity(0.03),
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
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13, 
                                color: Colors.grey.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                              counterText: '',
                            ),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14, 
                              color: Color(0xFF3E2723),
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
                              color: Colors.grey.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Premium Send Button
                          GestureDetector(
                            onTap: () {
                              final msg = messageController.text.trim();
                              if (msg.isNotEmpty) {
                                Navigator.pop(dialogContext, msg);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: messageController.text.trim().isEmpty 
                                    ? Colors.grey.withOpacity(0.2)
                                    : const Color(0xFFD4B483),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: messageController.text.trim().isEmpty ? [] : [
                                  BoxShadow(
                                    color: const Color(0xFFD4B483).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Send',
                                style: TextStyle(
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
                            onTap: () => Navigator.pop(dialogContext, null),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                AppLocalizations.of(context).tr('dialogs.cancel'),
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.grey.withOpacity(0.7),
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

    // 4. Send Bottle (NOT Conversation)
    try {
      debugPrint('🚀 SECRET SOULS: Sending bottle...');
      debugPrint('  Content ID: ${content['id']}');
      debugPrint('  Requester ID: ${user.id}');
      debugPrint('  Owner ID: ${content['user_id']}');
      debugPrint('  Message: $message');
      
      final bottleId = await _db.sendDirectBottle(
        senderId: user.id,
        receiverId: content['user_id'] as String,
        contentType: 'text', // Bottle content is text (the reply)
        message: message,
      );
      
      debugPrint('📬 SECRET SOULS: Bottle ID returned: $bottleId');
      
      if (bottleId != null) {
        debugPrint('✅ SECRET SOULS: Bottle sent successfully, incrementing usage...');
        // Increment usage
        await _db.incrementWeeklyMessages(user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bottle sent! Wait for their reply to chat.'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 4),
            ),
          );

          // ADDED: Immediate disappearance
          setState(() {
            if (_currentIndex < _content.length) {
              _content.removeAt(_currentIndex);
              // Adjust index if needed
              if (_currentIndex >= _content.length && _content.isNotEmpty) {
                _currentIndex = _content.length - 1;
              }
              // If we removed the item, we might need to load more if the list is getting empty
              if (_content.length < 3) {
                _loadContent();
              }
            }
          });
        }
      } else {
        debugPrint('❌ SECRET SOULS: Bottle ID is NULL - send failed');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).tr('errors.send_bottle_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ SECRET SOULS: Exception caught: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final tr = AppLocalizations.of(context);
        return Dialog(
          backgroundColor: const Color(0xFFFFF7E6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_outlined, size: 50, color: Color(0xFFD4B483)),
                const SizedBox(height: 16),
                Text(
                  tr.tr('limits.weekly.title'),
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr.tr('limits.weekly.message'),
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
                      MaterialPageRoute(builder: (context) => const PremiumScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE4C687),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Discover Premium'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr.tr('limits.weekly.ok'),
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

  Widget _buildGate(BuildContext context) {
    final tr = AppLocalizations.of(context);
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/soulpaper.jpg',
            fit: BoxFit.cover,
          ),
          // Dark Overlay
          Container(
            color: Colors.black.withOpacity(0.7),
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
                    tr.tr('secret_souls.gate.title'),
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
                    tr.tr('secret_souls.gate.description'),
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
                          color: const Color(0xFFE4C687),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE4C687).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tr.tr('secret_souls.gate.action.access'),
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
                          MaterialPageRoute(builder: (context) => const PremiumScreen()),
                        ).then((_) => _init());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE4C687), Color(0xFFD4B483)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE4C687).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tr.tr('secret_souls.gate.action.premium'),
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
                        tr.tr('secret_souls.gate.action.close'),
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

  @override
  Widget build(BuildContext context) {
    if (_showGate) {
      return _buildGate(context);
    }

    final tr = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E6), // Cream color from reference
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Expanded(
                    child: Center(
                      child: Text(
                        tr.tr('chamber.title'),
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay', // Serif font
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24), // Balance the back button
                ],
              ),
            ),

            // Filter pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterTab(tr.tr('common.all'), 'all'),
                  const SizedBox(width: 8),
                  _buildFilterTab(tr.tr('common.pictures'), 'photo'),
                  const SizedBox(width: 8),
                  _buildFilterTab(tr.tr('common.audio'), 'audio'),
                  const SizedBox(width: 8),
                  _buildFilterTab(tr.tr('common.quote'), 'quote'),
                  const SizedBox(width: 8),
                  _buildFilterTab(tr.tr('common.bio'), 'bio'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Swipe Text
            Text(
              tr.tr('chamber.swipe'),
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE4C687), // Gold/Beige color
              ),
            ),

            const SizedBox(height: 16),

            // Content cards
            Expanded(
              child: _loading && _content.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4B483),
                      ),
                    )
                  : _content.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/nobottles.jpeg',
                                width: 200,
                                opacity: const AlwaysStoppedAnimation(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No content available',
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 18,
                                  color: Color(0xFF5D4037),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : PageView.builder(
                          physics: const BouncingScrollPhysics(),
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                            // Load more when near end
                            if (index >= _content.length - 2) {
                              _loadContent();
                            }
                          },
                          itemCount: _content.length,
                          itemBuilder: (context, index) {
                            final item = _content[index];
                            return _buildContentCard(item);
                          },
                        ),
            ),

            // Send Message Button (Only for Quote and Audio)
            if (_content.isNotEmpty && 
                _content[_currentIndex]['content_type'] != 'photo')
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
              child: GestureDetector(
                onTap: _content.isEmpty ? null : _sendMessage,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _content.isEmpty
                        ? const Color(0xFFE0E0E0)
                        : const Color(0xFFE4C687), // Beige/Gold Button
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tr.tr('chamber.send_message'),
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _content.isEmpty
                          ? const Color(0xFF9E9E9E)
                          : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _changeFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFFE0E0E0), // Keep Cyan for selection or change to Gold? Reference shows Cyan.
            // Reference image shows Cyan buttons "All" etc.
            width: 1,
          ),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Text', // Keep sans serif for tabs? Or match reference? Reference looks like sans serif "All".
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF5D4037), // Keep text color logic
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    final type = content['content_type'] as String;
    
    // Parchment Background Container
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/soulpaper.jpg'),
            fit: BoxFit.fill, // Or cover? Fill might stretch texture. Cover might crop.
          ),
          borderRadius: BorderRadius.circular(4), // Rough edges visual comes from image usually
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Reduced from 40.0 to avoid edges but give more room
            child: type == 'photo'
                ? _buildPhotoCard(content)
                : type == 'audio'
                    ? _buildAudioCard(content)
                    : type == 'bio'
                        ? _buildBioCard(content)
                        : _buildQuoteCard(content),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> content) {
    // Check multiple potential keys for the photo URL
    final photoUrl = (content['photo_url'] ?? content['url'] ?? content['asset_url']) as String?;
    
    final department = content['department'] as String?;
    final city = content['city'] as String?;
    final fullName = content['full_name'] as String?;
    final firstName = fullName?.split(' ').first;
    final age = content['age'];

    String locationInfo = city ?? '';
    if (department != null && department.isNotEmpty) {
      // Extract "06" from "06 - Alpes-Maritimes"
      final deptNum = department.split(' - ').first;
      if (city != null && city.isNotEmpty) {
        locationInfo = '$city ($deptNum)';
      } else {
        locationInfo = department;
      }
    }
    
    String displayInfo = locationInfo;
    if (firstName != null && age != null) {
      if (locationInfo.isNotEmpty) {
        displayInfo = '$firstName, $age - $locationInfo';
      } else {
        displayInfo = '$firstName, $age';
      }
    }
    
    // White card style on top of parchment
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFEFEFEF),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFD4B483)),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error loading secret soul image: $error');
                        return Container(
                          color: const Color(0xFFEFEFEF),
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 200, // Placeholder height
                      color: const Color(0xFFEFEFEF),
                      child: const Center(child: Text('No Image found', style: TextStyle(color: Colors.red))),
                    ),
            ),
          ),
          if (content['city'] != null && (content['city'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF737373)),
                const SizedBox(width: 4),
                Text(
                  displayInfo,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioCard(Map<String, dynamic> content) {
    final audioUrl = content['audio_url'] as String?;
    
    final department = content['department'] as String?;
    final city = content['city'] as String?;
    final fullName = content['full_name'] as String?;
    final firstName = fullName?.split(' ').first;
    final age = content['age'];

    String locationInfo = city ?? '';
    if (department != null && department.isNotEmpty) {
      // Extract "06" from "06 - Alpes-Maritimes"
      final deptNum = department.split(' - ').first;
      if (city != null && city.isNotEmpty) {
        locationInfo = '$city ($deptNum)';
      } else {
        locationInfo = department;
      }
    }
    
    String displayInfo = locationInfo;
    if (firstName != null && age != null) {
      if (locationInfo.isNotEmpty) {
        displayInfo = '$firstName, $age - $locationInfo';
      } else {
        displayInfo = '$firstName, $age';
      }
    }

    return SecretSoulAudioCard(audioUrl: audioUrl, locationInfo: displayInfo);
  }

  Widget _buildBioCard(Map<String, dynamic> content) {
    final bioText = content['bio_text'] as String? ?? '';
    
    final department = content['department'] as String?;
    final city = content['city'] as String?;
    final fullName = content['full_name'] as String?;
    final firstName = fullName?.split(' ').first;
    final age = content['age'];

    String locationInfo = city ?? '';
    if (department != null && department.isNotEmpty) {
      final deptNum = department.split(' - ').first;
      if (city != null && city.isNotEmpty) {
        locationInfo = '$city ($deptNum)';
      } else {
        locationInfo = department;
      }
    }
    
    String displayInfo = locationInfo;
    if (firstName != null && age != null) {
      if (locationInfo.isNotEmpty) {
        displayInfo = '$firstName, $age - $locationInfo';
      } else {
        displayInfo = '$firstName, $age';
      }
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.person_outline,
          size: 40,
          color: Color(0xFFD4B483),
        ),
        const SizedBox(height: 16),
        Text(
          bioText,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: Color(0xFF3E2723),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (displayInfo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 14,
                color: Color(0xFF737373),
              ),
              const SizedBox(width: 4),
              Text(
                displayInfo,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> content) {
    final quoteText = content['quote_text'] as String? ?? '';
    
    final department = content['department'] as String?;
    final city = content['city'] as String?;
    final fullName = content['full_name'] as String?;
    final firstName = fullName?.split(' ').first;
    final age = content['age'];

    String locationInfo = city ?? '';
    if (department != null && department.isNotEmpty) {
      // Extract "06" from "06 - Alpes-Maritimes"
      final deptNum = department.split(' - ').first;
      if (city != null && city.isNotEmpty) {
        locationInfo = '$city ($deptNum)';
      } else {
        locationInfo = department;
      }
    }
    
    String displayInfo = locationInfo;
    if (firstName != null && age != null) {
      if (locationInfo.isNotEmpty) {
        displayInfo = '$firstName, $age - $locationInfo';
      } else {
        displayInfo = '$firstName, $age';
      }
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.format_quote,
            size: 40,
            color: Color(0xFFFFD700), // Yellow quote icon as per reference
          ),
          const SizedBox(height: 16),
          Text(
            quoteText,
            style: const TextStyle(
              fontFamily: 'SF Pro Text', // Or Playfair? Reference quote looks sans-ish/italic? Reference says "Developer and music lover" in italic sans.
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: Color(0xFF3E2723),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // City display
          if (displayInfo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Color(0xFF737373),
                ),
                const SizedBox(width: 4),
                Text(
                  displayInfo,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SecretSoulAudioCard extends StatefulWidget {
  final String? audioUrl;
  final String? locationInfo;
  const SecretSoulAudioCard({super.key, this.audioUrl, this.locationInfo});

  @override
  State<SecretSoulAudioCard> createState() => _SecretSoulAudioCardState();
}

class _SecretSoulAudioCardState extends State<SecretSoulAudioCard> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    
    // Ensure audio plays through the speaker (crucial for mobile)
    _player.setAudioContext(const AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: [AVAudioSessionOptions.defaultToSpeaker],
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    _player.onLog.listen((msg) => debugPrint('AudioPlayer Log: $msg'));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.audioUrl == null) return;
    
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        // Stop ambient music to prevent interference
        await GlobalAudioController.instance.stopAmbient();

        // Check/Force volume
        await _player.setVolume(1.0);

        // Only show loading if we are stopped/completed
        if (_playerState != PlayerState.paused) {
          setState(() => _isLoading = true);
        }
        await _player.play(UrlSource(widget.audioUrl!));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final primaryColor = const Color(0xFF5D4037); // Dark Brown
    final accentColor = const Color(0xFFD4B483); // Gold

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Semi-transparent cream to blend with parchment
        color: const Color(0xCCFFF8E1), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visualizer / Icon Area
          Container(
            height: 60,
            alignment: Alignment.center,
            child: isPlaying
                ? Icon(Icons.graphic_eq, size: 48, color: primaryColor) 
                : Icon(Icons.music_note, size: 48, color: accentColor),
          ),
          
          const SizedBox(height: 16),

          // Progress Bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: accentColor.withValues(alpha: 0.3),
              thumbColor: primaryColor,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: (_position.inMilliseconds.toDouble())
                  .clamp(0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
              min: 0,
              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              onChanged: (value) async {
                final position = Duration(milliseconds: value.toInt());
                await _player.seek(position);
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: TextStyle(color: primaryColor, fontSize: 12)),
                Text(_formatDuration(_duration), style: TextStyle(color: primaryColor, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Controls
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE4C687), // Gold
                    Color(0xFFD4B483), // Darker Gold
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(18.0),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            isPlaying ? 'Listening...' : 'Tap to listen',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: primaryColor,
            ),
            ),

          if (widget.locationInfo != null && widget.locationInfo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 14, color: primaryColor.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                   widget.locationInfo!,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
