import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../models/feeling_milestone.dart';
import '../widgets/custom_button.dart';
import 'package:audioplayers/audioplayers.dart';

class MilestoneUnlockModal extends StatefulWidget {
  final FeelingMilestone milestone;
  final String? partnerBio;
  final String? partnerSecretAudioUrl;
  final VoidCallback onContinue;

  const MilestoneUnlockModal({
    super.key,
    required this.milestone,
    this.partnerBio,
    this.partnerSecretAudioUrl,
    required this.onContinue,
  });

  @override
  State<MilestoneUnlockModal> createState() => _MilestoneUnlockModalState();
}

class _MilestoneUnlockModalState extends State<MilestoneUnlockModal> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (widget.partnerSecretAudioUrl != null) {
        await _audioPlayer.play(UrlSource(widget.partnerSecretAudioUrl!));
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0AC5C5),
              Color(0xFF08A8A8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Milestone Icon
              Text(
                widget.milestone.icon,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                widget.milestone.title,
                style: AppTextStyles.displayText.copyWith(
                  color: AppColors.white,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                widget.milestone.description,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Content based on milestone
              _buildMilestoneContent(),
              
              const SizedBox(height: 24),
              
              // Continue Button
              CustomButton(
                text: 'Continue',
                onPressed: widget.onContinue,
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneContent() {
    switch (widget.milestone) {
      case FeelingMilestone.feather:
        // 25% - Show partner's bio/quote
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.partnerBio ?? 'No bio available',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.white,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        );

      case FeelingMilestone.music:
        // 50% - Play partner's secret audio
        return Column(
          children: [
            GestureDetector(
              onTap: _toggleAudio,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.3),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isPlaying ? 'Playing...' : 'Tap to play',
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.white,
              ),
            ),
          ],
        );

      case FeelingMilestone.gift:
        // 75% - Show premium paywall message
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Congratulations 🎉',
                style: AppTextStyles.displayText.copyWith(
                  color: AppColors.white,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your intuition is almost 100%!\n\nYou\'re about to discover the person you\'re chatting with 👀\n\nThe free version of SeaYou ends here 😟\n\nUpgrade to SeaYou Premium to continue the adventure and unravel the mystery ✨',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case FeelingMilestone.heart:
        // 100% - Photo reveal available
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.photo_camera,
                color: AppColors.white,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'You can now reveal your match\'s photo!',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }
}
