import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../models/feeling_milestone.dart';
import '../widgets/custom_button.dart';
import 'package:audioplayers/audioplayers.dart';
import '../i18n/app_localizations.dart';

class MilestoneUnlockModal extends StatefulWidget {
  final FeelingMilestone milestone;
  final String? partnerBio;
  final String? partnerSecretAudioUrl;
  final bool isPremium;
  final String? userGender;
  final VoidCallback onPremiumRequested;
  final VoidCallback onContinue;

  const MilestoneUnlockModal({
    super.key,
    required this.milestone,
    this.partnerBio,
    this.partnerSecretAudioUrl,
    required this.isPremium,
    this.userGender,
    required this.onPremiumRequested,
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
              if (widget.milestone.percentage != 75) ...[
                Text(
                  widget.milestone.getTitle(context),
                  style: AppTextStyles.displayText.copyWith(
                    color: AppColors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],

              // Description
              Text(
                widget.milestone.getDescription(context),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Content based on milestone
              _buildMilestoneContent(),

              const SizedBox(height: 24),

              // Continue or Premium Button
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (widget.milestone.percentage != 75) {
      return CustomButton(
        text: AppLocalizations.of(context).tr('chat.milestone_continue'),
        onPressed: widget.onContinue,
        isActive: true,
      );
    }

    final gender = widget.userGender?.toLowerCase();
    final isFemale =
        gender == 'female' || gender == 'woman' || gender == 'femme';

    if (isFemale || widget.isPremium) {
      // Premium male or female → can answer naughty questions
      return CustomButton(
        text:
            AppLocalizations.of(context).tr('chat.milestone_75_button_naughty'),
        onPressed: widget.onContinue,
        isActive: true,
      );
    } else {
      // Non-premium male → paywall only, no access to naughty questions
      return CustomButton(
        text:
            AppLocalizations.of(context).tr('chat.milestone_75_button_unlock'),
        onPressed: widget.onPremiumRequested,
        isActive: true,
      );
    }
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
            widget.partnerBio ??
                AppLocalizations.of(context).tr('chat.milestone_no_bio'),
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
              _isPlaying
                  ? AppLocalizations.of(context).tr('chat.milestone_playing')
                  : AppLocalizations.of(context).tr('chat.milestone_tap_play'),
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
                AppLocalizations.of(context).tr('chat.milestone_75_congrats'),
                style: AppTextStyles.displayText.copyWith(
                  color: AppColors.white,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _getGiftMilestoneDescription(context),
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
                AppLocalizations.of(context).tr('chat.milestone_100_reveal'),
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

  String _getGiftMilestoneDescription(BuildContext context) {
    final gender = widget.userGender?.toLowerCase();
    final isFemale =
        gender == 'female' || gender == 'woman' || gender == 'femme';

    if (isFemale || widget.isPremium) {
      return AppLocalizations.of(context).tr('chat.milestone_75_desc_naughty');
    } else {
      return AppLocalizations.of(context).tr('chat.milestone_75_desc_premium');
    }
  }
}
