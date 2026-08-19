class GameEvent {
  final String id;
  final String title;
  final String description;
  final String bannerImage;
  final DateTime startDate;
  final DateTime endDate;
  final int goal;
  final int rewardCoins;
  final int rewardGems;
  int currentProgress;
  bool isClaimed;

  GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerImage,
    required this.startDate,
    required this.endDate,
    required this.goal,
    this.rewardCoins = 0,
    this.rewardGems = 0,
    this.currentProgress = 0,
    this.isClaimed = false,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isCompleted => currentProgress >= goal;

  double get progressPercentage => (currentProgress / goal).clamp(0.0, 1.0);

  int get daysRemaining {
    final diff = endDate.difference(DateTime.now());
    return diff.inDays;
  }
}
