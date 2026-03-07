import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/voice_player.dart';
import '../../i18n/app_localizations.dart';

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
          Expanded(
            child: Text(
              AppLocalizations.of(context).tr('chat_profile.title'),
              style: const TextStyle(
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
      return const Center(child: Text(''));
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
        GestureDetector(
          onTap: () {
            if (showPhoto && _partnerProfile?['avatar_url'] != null) {
              _showFullScreenImage(_partnerProfile!['avatar_url'] as String);
            }
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: showPhoto ? null : _getMoodGradient(widget.mood),
              image: showPhoto && _partnerProfile?['avatar_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(
                          _partnerProfile!['avatar_url'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !showPhoto
                ? const Icon(Icons.lock, size: 48, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          (widget.feelingPercent >= 100 && _partnerProfile?['username'] != null)
              ? _partnerProfile!['username'] as String
              : widget.contactName,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF151515),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).tr('chat_profile.feeling_level',
              params: {'percent': widget.feelingPercent.toString()}),
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

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
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
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF0AC5C5), size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)
                    .tr('chat_profile.bio_unlocked', params: {'percent': '25'}),
                style: const TextStyle(
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
            _partnerProfile?['about'] as String? ??
                AppLocalizations.of(context).tr('chat_profile.no_bio'),
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
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF0AC5C5), size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).tr('chat_profile.audio_unlocked',
                    params: {'percent': '50'}),
                style: const TextStyle(
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
            Row(
              children: [
                const Icon(Icons.play_circle_filled,
                    color: Colors.grey, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).tr('chat_profile.no_audio'),
                    style: const TextStyle(
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
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF0AC5C5), size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).tr(
                    'chat_profile.intimate_unlocked',
                    params: {'percent': '75'}),
                style: const TextStyle(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)
                  .tr('chat_profile.reveal_photo', params: {'percent': '100'}),
              style: const TextStyle(
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
    return GestureDetector(
      onTap: () {
        _showBlockModal();
      },
      child: Text(
        AppLocalizations.of(context).tr('chat_profile.block_user', params: {
          'name': (widget.feelingPercent >= 100 &&
                  _partnerProfile?['username'] != null)
              ? _partnerProfile!['username']
              : widget.contactName
        }),
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFFB3748),
        ),
      ),
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
                  AppLocalizations.of(context)
                      .tr('chat_profile.block_user', params: {
                    'name': (widget.feelingPercent >= 100 &&
                            _partnerProfile?['username'] != null)
                        ? _partnerProfile!['username']
                        : widget.contactName
                  }),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).tr('chat_profile.block_warning'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
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
                          child: Text(
                            AppLocalizations.of(context).tr('dialogs.cancel'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                        onTap: () async {
                          final currentUserId = AuthService().currentUser?.id;
                          if (currentUserId == null) return;

                          try {
                            // Block the user
                            await _db.blockUser(
                              blockerId: currentUserId,
                              blockedId: widget.partnerId,
                            );

                            if (!mounted) return;

                            // Close modal
                            Navigator.pop(dialogContext);
                            // Go back to chat list
                            Navigator.pop(context);

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context).tr(
                                    'chat_profile.has_been_blocked',
                                    params: {
                                      'name': (widget.feelingPercent >= 100 &&
                                              _partnerProfile?['username'] !=
                                                  null)
                                          ? _partnerProfile!['username']
                                              as String
                                          : widget.contactName
                                    })),
                                backgroundColor: const Color(0xFF0AC5C5),
                              ),
                            );
                          } catch (e) {
                            debugPrint('Error blocking user: $e');
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)
                                    .tr('errors.block_user_failed')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0AC5C5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)
                                .tr('chat_profile.confirm_block'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
