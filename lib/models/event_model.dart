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

  /// Which counter feeds this event, so the win handler knows what to add.
  final String metric;

  /// False while the event is still a preview of its next run.
  final bool isOpen;

  /// The moment the schedule was read. Judging a window against the wall clock
  /// inside the model would leave no way to ask what the board looked like ten
  /// seconds ago, which is exactly what a claim has to check.
  final DateTime checkedAt;
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
    this.metric = '',
    this.isOpen = true,
    DateTime? checkedAt,
    this.rewardCoins = 0,
    this.rewardGems = 0,
    this.currentProgress = 0,
    this.isClaimed = false,
  }) : checkedAt = checkedAt ?? DateTime.now();

  bool get isActive {
    return isOpen &&
        !checkedAt.isBefore(startDate) &&
        checkedAt.isBefore(endDate);
  }

  bool get isCompleted => currentProgress >= goal;

  bool get canClaim => isActive && isCompleted && !isClaimed;

  double get progressPercentage => (currentProgress / goal).clamp(0.0, 1.0);

  int get daysRemaining {
    final diff = endDate.difference(checkedAt).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Only meaningful when [isOpen] is false.
  int get daysUntilStart {
    final diff = startDate.difference(checkedAt).inDays;
    return diff < 0 ? 0 : diff;
  }
}
