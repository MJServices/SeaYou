import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/warm_gradient_background.dart';
import '../services/database_service.dart';
import '../models/bottle.dart';
import '../widgets/voice_chat_modal.dart';
import '../widgets/photo_stamp_modal.dart';
import 'received_bottles_screen.dart';
import '../i18n/app_localizations.dart';

/// All Bottles Screen - Shows all sent or received bottles
class AllBottlesScreen extends StatefulWidget {
  final bool isSent;

  const AllBottlesScreen({
    super.key,
    this.isSent = false,
  });

  @override
  State<AllBottlesScreen> createState() => _AllBottlesScreenState();
}

class _AllBottlesScreenState extends State<AllBottlesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Bottle> _bottles = [];

  @override
  void initState() {
    super.initState();
    _loadBottles();
  }

  Future<void> _loadBottles() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (widget.isSent) {
        final sent = await _databaseService.getAllSentBottles(userId);
        setState(() => _bottles = sent);
      } else {
        final received = await _databaseService.getAllReceivedBottles(userId);
        setState(() => _bottles = received);
      }
    } catch (e) {
      debugPrint('Error loading bottles: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(
                          'assets/icons/arrow_left.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF151515),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isSent ? 'Sent Bottles' : 'Received Bottles',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF151515),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Note
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Note: Bottles disappears into the sea 30 days after connection has not been established.',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF737373),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottles grid
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF0AC5C5)))
                    : _bottles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/empty-bottle.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isSent
                                      ? 'No sent bottles yet'
                                      : 'No received bottles yet',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _bottles.length,
                              itemBuilder: (context, index) {
                                return _buildBottleCard(_bottles[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottleCard(Bottle bottle) {
    Color cardColor;
    String iconPath;
    String title;

    // Determine type
    switch (bottle.contentType) {
      case 'voice':
        cardColor = Colors.white;
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

    // Determine status (mostly relevant for sent bottles)
    String? statusText;
    Color? statusColor;

    if (bottle is SentBottle) {
      final sent = bottle;
      // Priority: Read/Replied > Matched > Delivered > Floating
      if (sent.hasReply) {
        statusText = '↩ Replied';
        statusColor = const Color(0xFF9B98E6);
      } else if (sent.isMatched) {
        statusText = '✓ Matched';
        statusColor = const Color(0xFF65ADA9);
      } else if (sent.status == 'delivered') {
        statusText = '📬 Delivered';
        statusColor = const Color(0xFFD89736);
      } else {
        statusText = '🌊 Floating';
        statusColor = const Color(0xFF0AC5C5);
      }
    }

    return GestureDetector(
      onTap: () {
        if (bottle.contentType == 'voice') {
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => VoiceChatModal(
              isReceived: !widget.isSent,
              onReply: () => Navigator.pop(context),
            ),
          );
        } else if (bottle.contentType == 'photo') {
          showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => PhotoStampModal(
              imageUrl: bottle.photoUrl ?? 'assets/images/photo_stamp.png',
              caption: bottle.caption ?? 'Photo',
              isReceived: !widget.isSent,
              onReply: () => Navigator.pop(context),
              onPrevious: () {},
              onNext: () {},
            ),
          );
        } else {
          if (!widget.isSent) {
            // RECEIVED: Open the swipeable ReceivedBottlesScreen starting with this bottle
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceivedBottlesScreen(
                  initialBottle: bottle as ReceivedBottle,
                ),
              ),
            );
          } else {
            // SENT: For now, we can just show a read-only modal or snackbar
            // Since the user wants to remove BottleDetailScreen, we avoid using it.
            _showSentBottlePreview(context, bottle as SentBottle);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
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
            Row(
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF151515),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (statusText != null && statusColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
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
            const SizedBox(height: 8),
            if (bottle.contentType == 'voice') ...[
              const SizedBox(height: 8),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                // TODO: Add waveform
              ),
            ] else if (bottle.contentType == 'photo') ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    image: DecorationImage(
                      image: bottle.photoUrl != null
                          ? NetworkImage(bottle.photoUrl!)
                          : const AssetImage('assets/images/photo_stamp.png')
                              as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  _getTranslatedMessage(context, bottle.message),
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
      ),
    );
  }

  void _showSentBottlePreview(BuildContext context, SentBottle bottle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sent Bottle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTranslatedMessage(context, bottle.message),
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${bottle.status}',
              style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
