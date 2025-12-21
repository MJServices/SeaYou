import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'voice_player.dart';

class PreviewModal extends StatelessWidget {
  final String content;
  final String mood;
  final String type;
  final String? imagePath;
  final String? audioPath;
  final VoidCallback onSend;
  final VoidCallback onSaveDraft;
  final bool isLoading;

  const PreviewModal({
    super.key,
    required this.content,
    required this.mood,
    this.type = 'Text',
    this.imagePath,
    this.audioPath,
    required this.onSend,
    required this.onSaveDraft,
    this.isLoading = false,
  });

  List<Color> _getMoodGradientColors(String mood) {
    switch (mood.toLowerCase()) {
      case 'dreamy':
        return [
          const Color(0xFFC7CEEA), // Start: lighter color at top
          const Color(0xFF9B98E6), // End: darker color at bottom
        ];
      case 'curious':
        return [
          const Color(0xFFFFC700),
          const Color(0xFFD89736),
        ];
      case 'calm':
        return [
          const Color(0xFF9ECFD4),
          const Color(0xFF65ADA9),
        ];
      case 'playful':
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
        return const Color(0xFF3B0143);
      case 'curious':
        return const Color(0xFF3A2C02);
      case 'calm':
      case 'playful':
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
                const Text(
                  'Preview',
                  style: TextStyle(
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
            if (isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0AC5C5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0AC5C5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Uploading and sending...',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF0AC5C5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (isLoading) const SizedBox(height: 12),

            // Message Preview
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 342),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _getMoodGradientColors(mood),
                  stops: const [0.0, 0.56],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: type == 'Picture' && imagePath != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 231,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: FileImage(File(imagePath!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            content,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _getMoodTextColor(mood),
                            ),
                          ),
                        ],
                      ],
                    )
                  : type == 'Voice Chat'
                      ? VoicePlayer(
                          audioPath: audioPath,
                          color: _getMoodTextColor(mood),
                        )
                      : SingleChildScrollView(
                          child: Text(
                            content,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _getMoodTextColor(mood),
                              height: 1.5,
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onSaveDraft,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF0AC5C5),
                          width: 0.8,
                        ),
                        backgroundColor: const Color(0xFFECFAFA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save as Drafts',
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
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onSend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0AC5C5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFF0AC5C5).withValues(alpha: 0.6),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send',
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
    );
  }
}

