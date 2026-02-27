import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';

enum FeelingMilestone {
  feather(25, '🖋️'),
  music(50, '🎙️'),
  gift(75, '🎁'),
  heart(100, '❤️');

  final int percentage;
  final String icon;

  const FeelingMilestone(
    this.percentage,
    this.icon,
  );

  String getTitle(BuildContext context) {
    return AppLocalizations.of(context).tr('chat.milestone_title_$percentage');
  }

  String getDescription(BuildContext context) {
    return AppLocalizations.of(context).tr('chat.milestone_desc_$percentage');
  }

  static FeelingMilestone? fromPercentage(int percent) {
    if (percent >= 100) return heart;
    if (percent >= 75) return gift;
    if (percent >= 50) return music;
    if (percent >= 25) return feather;
    return null;
  }

  static List<FeelingMilestone> getUnlockedMilestones(int percent) {
    return FeelingMilestone.values
        .where((m) => percent >= m.percentage)
        .toList();
  }

  static FeelingMilestone? getNextMilestone(int percent) {
    for (var milestone in FeelingMilestone.values) {
      if (percent < milestone.percentage) {
        return milestone;
      }
    }
    return null; // Already at 100%
  }

  static int getProgressToNext(int percent) {
    final next = getNextMilestone(percent);
    if (next == null) return 0;
    
    final previous = FeelingMilestone.values
        .where((m) => m.percentage < next.percentage)
        .lastOrNull;
    
    final previousPercent = previous?.percentage ?? 0;
    final range = next.percentage - previousPercent;
    final progress = percent - previousPercent;
    
    return ((progress / range) * 100).round();
  }
}
