import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'voice_player.dart';
import '../i18n/app_localizations.dart';

class PreviewModal extends StatefulWidget {
  final String content;
  final String mood;
  final String type;
  final String? imagePath;
  final String? audioPath;
  final Future<void> Function() onSend;
  final bool isLoading; // Kept for external control if needed

  const PreviewModal({
    super.key,
    required this.content,
    required this.mood,
    this.type = 'Text',
    this.imagePath,
    this.audioPath,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<PreviewModal> createState() => _PreviewModalState();
}

class _PreviewModalState extends State<PreviewModal> {
  bool _localIsLoading = false;

  @override
  void initState() {
    super.initState();
    _localIsLoading = widget.isLoading;
  }

  @override
  void didUpdateWidget(PreviewModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      setState(() {
        _localIsLoading = widget.isLoading;
      });
    }
  }

  Future<void> _handleSend() async {
    if (_localIsLoading) return;
    
    setState(() {
      _localIsLoading = true;
    });

    try {
      await widget.onSend();
      // If we reach here, onSend completed. If the modal is still open, stop the spinner.
      if (mounted) {
        setState(() {
          _localIsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localIsLoading = false;
        });
      }
      // Re-throw if it wasn't a silent error (like limit reached)
      // but for now, we just reset loading so they can click again if needed.
      debugPrint('Error in PreviewModal send: $e');
    }
  }

  List<Color> _getMoodGradientColors(String mood) {
    switch (mood.toLowerCase()) {
      case 'dreamy':
      case 'romantique':
        return [
          const Color(0xFFC7CEEA), // Start: lighter color at top
          const Color(0xFF9B98E6), // End: darker color at bottom
        ];
      case 'curious':
      case 'curieux':
        return [
          const Color(0xFFFFC700),
          const Color(0xFFD89736),
        ];
      case 'calm':
      case 'joyeux':
        return [
          const Color(0xFF9ECFD4),
          const Color(0xFF65ADA9),
        ];
      case 'playful':
      case 'taquin':
        return [
          const Color(0xFFFF9F9B),
          const Color(0xFFFF6D68),
        ];
      default:
        return [
          const Color(0xFFC7CEEA),
          const Color(0xFF9B98E6),
        ];
    }
  }

  Color _getMoodTextColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'dreamy':
      case 'romantique':
        return const Color(0xFF3B0143);
      case 'curious':
      case 'curieux':
        return const Color(0xFF3A2C02);
      case 'calm':
      case 'joyeux':
      case 'playful':
      case 'taquin':
        return const Color(0xFF151515);
      default:
        return const Color(0xFF3B0143);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).tr('common.preview'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SvgPicture.asset(
                    'assets/icons/xmark.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF151515),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Upload status
            if (_localIsLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0AC5C5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0AC5C5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).tr('common.uploading_sending'),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF0AC5C5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (_localIsLoading) const SizedBox(height: 12),

            // Message Preview
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 342),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _getMoodGradientColors(widget.mood),
                  stops: const [0.0, 0.56],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: widget.type == 'Picture' && widget.imagePath != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 231,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: FileImage(File(widget.imagePath!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (widget.content.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.content,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _getMoodTextColor(widget.mood),
                            ),
                          ),
                        ],
                      ],
                    )
                  : widget.type == 'Voice Chat'
                      ? VoicePlayer(
                          audioPath: widget.audioPath,
                          color: _getMoodTextColor(widget.mood),
                        )
                      : SingleChildScrollView(
                          child: Text(
                            widget.content,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _getMoodTextColor(widget.mood),
                              height: 1.5,
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _localIsLoading ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0AC5C5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFF0AC5C5).withValues(alpha: 0.6),
                ),
                child: _localIsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context).tr('common.send'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

