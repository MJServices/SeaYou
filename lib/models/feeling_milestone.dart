enum FeelingMilestone {
  feather(25, '🪶', 'Quote Unlocked!', 'See what your match shared about themselves'),
  music(50, '🎵', 'Voice Message Unlocked!', 'Listen to your match\'s secret audio'),
  gift(75, '🎁', 'Intimate Question Unlocked!', 'Answer a naughty question together'),
  heart(100, '❤️', 'Photo Reveal Available!', 'Ready to see who you\'ve been chatting with?');

  final int percentage;
  final String icon;
  final String title;
  final String description;

  const FeelingMilestone(
    this.percentage,
    this.icon,
    this.title,
    this.description,
  );

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
