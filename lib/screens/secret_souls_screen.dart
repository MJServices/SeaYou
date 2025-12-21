import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../i18n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroDialog();
    });
  }

  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Mandatory interaction
      builder: (context) {
        final tr = AppLocalizations.of(context);
        return Dialog(
          backgroundColor: const Color(0xFFFFF7E6), // Cream background
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr.tr('secret_souls.popup.title'),
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E2723),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  tr.tr('secret_souls.popup.description'),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF5D4037),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE4C687), // Gold
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Enter',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                    ),
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
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (_loading) return;
    
    setState(() => _loading = true);
    
    final contentType = _selectedFilter == 'all' ? null : _selectedFilter;
    final newContent = await _db.getSecretSoulsContent(
      contentType: contentType,
      page: _page,
    );
    
    setState(() {
      _content.addAll(newContent);
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
    
    // Check limits (Max 3 per week)
    final canSend = await _db.canSendMessageThisWeek(user.id);
    if (!canSend) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limit Reached', style: TextStyle(fontFamily: 'PlayfairDisplay')),
          content: const Text(
            'You have reached the maximum number of messages allowed this week.\n\nDiscover our message packs (Coming Soon).',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

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
                  fontFamily: 'SF Pro Text',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You will start an anonymous conversation. The owner will see it in their messages.',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
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
                          fontFamily: 'SF Pro Text',
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
                          fontFamily: 'SF Pro Text',
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
      final convId = await _db.startSecretSoulsConversation(
        contentId: content['id'] as String,
        requesterId: user.id,
        ownerId: content['user_id'] as String,
      );
      
      if (convId != null) {
        // Increment usage
        await _db.incrementWeeklyMessages(user.id);
      }

      if (mounted) {
        if (convId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation started! Check your messages.'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
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
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Swipe Text
            Text(
              'Swipe !', // Check if localization key exists, otherwise hardcode or use chamber.swipe
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
                          child: Text(
                            'No content available',
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 18,
                              color: Color(0xFF5D4037),
                            ),
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
            padding: const EdgeInsets.all(40.0), // Padding inside parchment to avoid edges
            child: type == 'photo'
                ? _buildPhotoCard(content)
                : type == 'audio'
                    ? _buildAudioCard(content)
                    : _buildQuoteCard(content),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> content) {
    // Check multiple potential keys for the photo URL
    final photoUrl = (content['photo_url'] ?? content['url'] ?? content['asset_url']) as String?;
    
    // White card style on top of parchment
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
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
                color: const Color(0xFFEFEFEF),
                child: const Center(child: Text('No Image found', style: TextStyle(color: Colors.red))),
              ),
      ),
    );
  }

  Widget _buildAudioCard(Map<String, dynamic> content) {
    final audioUrl = content['audio_url'] as String?;
    return SecretSoulAudioCard(audioUrl: audioUrl);
  }

  Widget _buildQuoteCard(Map<String, dynamic> content) {
    final quoteText = content['quote_text'] as String? ?? '';
    
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
        ],
      ),
    );
  }
}

class SecretSoulAudioCard extends StatefulWidget {
  final String? audioUrl;
  const SecretSoulAudioCard({super.key, this.audioUrl});

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
        ],
      ),
    );
  }
}
