import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../models/user_profile.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/voice_player.dart';

/// Chat Profile Screen - Dynamic profile viewer with conditional content
class ChatProfileScreen extends StatefulWidget {
  final String conversationId;
  final String partnerId;
  final int feelingPercent;
  final String contactName;
  final String? mood;

  const ChatProfileScreen({
    super.key,
    required this.conversationId,
    required this.partnerId,
    required this.feelingPercent,
    required this.contactName,
    this.mood,
  });

  @override
  State<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends State<ChatProfileScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _partnerProfile;
  String? _naughtyAnswer;
  bool _reportToSeaYou = false;

  @override
  void initState() {
    super.initState();
    _loadPartnerProfile();
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // Fetch partner profile
      final profile = await _db.getProfile(widget.partnerId);
      
      // Fetch naughty answer if feeling >= 75%
      String? naughtyAnswer;
      if (widget.feelingPercent >= 75) {
        final convData = await Supabase.instance.client
            .from('conversations')
            .select('user_a_id, user1_naughty_answer, user2_naughty_answer')
            .eq('id', widget.conversationId)
            .single();
        
        final currentUserId = AuthService().currentUser?.id;
        final isUserA = convData['user_a_id'] == currentUserId;
        // Get partner's answer (opposite of current user)
        naughtyAnswer = isUserA 
            ? convData['user2_naughty_answer']
            : convData['user1_naughty_answer'];
      }

      if (mounted) {
        setState(() {
          _partnerProfile = profile;
          _naughtyAnswer = naughtyAnswer;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading partner profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProfileContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                size: 24, color: Color(0xFF151515)),
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_partnerProfile == null) {
      return const Center(child: Text('Profile not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          if (widget.feelingPercent >= 25) ...[
            _buildBioSection(),
            const SizedBox(height: 24),
          ],
          if (widget.feelingPercent >= 50) ...[
            _buildAudioSection(),
            const SizedBox(height: 24),
          ],
          if (widget.feelingPercent >= 75 && _naughtyAnswer != null) ...[
            _buildNaughtyAnswerSection(),
            const SizedBox(height: 24),
          ],
          if (widget.feelingPercent >= 100) ...[
            _buildPhotoRevealButton(),
            const SizedBox(height: 24),
          ],
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final showPhoto = widget.feelingPercent >= 100;
    
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: showPhoto ? null : _getMoodGradient(widget.mood),
            image: showPhoto && _partnerProfile?['avatar_url'] != null
                ? DecorationImage(
                    image: NetworkImage(_partnerProfile!['avatar_url'] as String),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !showPhoto
              ? const Icon(Icons.lock, size: 48, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          widget.contactName,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF151515),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Feeling Level: ${widget.feelingPercent}%',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF737373),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF0AC5C5), size: 20),
              SizedBox(width: 8),
              Text(
                'Bio Unlocked (25%)',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0AC5C5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _partnerProfile?['about'] as String? ?? 'No bio available',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF363636),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF0AC5C5), size: 20),
              SizedBox(width: 8),
              Text(
                'Secret Audio Unlocked (50%)',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0AC5C5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_partnerProfile?['secret_audio_url'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0AC5C5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: VoicePlayer(
                audioUrl: _partnerProfile!['secret_audio_url'],
                color: const Color(0xFF0AC5C5),
              ),
            )
          else
            const Row(
              children: [
                Icon(Icons.play_circle_filled, color: Colors.grey, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No audio available',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF737373),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNaughtyAnswerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF0AC5C5), size: 20),
              SizedBox(width: 8),
              Text(
                'Intimate Answer Unlocked (75%)',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0AC5C5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _naughtyAnswer!,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF363636),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRevealButton() {
    return GestureDetector(
      onTap: () {
        // TODO: Show photo reveal modal
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6EC7), Color(0xFFFFB347)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Reveal Photo (100%)',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // Archive chat functionality
          },
          child: const Text(
            'Archive Chat',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF363636),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            _showBlockModal();
          },
          child: Text(
            'Block ${widget.contactName}',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFFB3748),
            ),
          ),
        ),
      ],
    );
  }

  void _showBlockModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _getMoodGradient(widget.mood),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Block ${widget.contactName}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This person won\'t be able to message you. They won\'t know you blocked or reported them',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setModalState(() {
                      _reportToSeaYou = !_reportToSeaYou;
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF363636), width: 1.5),
                          borderRadius: BorderRadius.circular(1),
                          color: _reportToSeaYou
                              ? const Color(0xFF0AC5C5)
                              : Colors.transparent,
                        ),
                        child: _reportToSeaYou
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Report to SeaYou',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF363636),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFAFA),
                            border: Border.all(
                                color: const Color(0xFF0AC5C5), width: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Cancel',
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                          // Block functionality
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0AC5C5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Block',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
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
      ),
    );
  }

  LinearGradient _getMoodGradient(String? mood) {
    switch (mood) {
      case 'Curious':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC700), Color(0xFFD89736)],
        );
      case 'Playful':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)],
        );
      case 'Dreamy':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
      case 'Calm':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9ECFD4), Color(0xFF65ADA9)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF0AC5C5), Color(0xFF0AC5C5)],
        );
    }
  }
}
