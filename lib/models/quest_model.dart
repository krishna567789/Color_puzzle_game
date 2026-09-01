class Quest {
  final String id;
  final String title;
  final String description;
  final int targetValue;
  final int currentProgress;
  final int coinReward;
  final int gemReward;
  final bool isClaimed;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    this.currentProgress = 0,
    required this.coinReward,
    required this.gemReward,
    this.isClaimed = false,
  });

  bool get isCompleted => currentProgress >= targetValue;
  double get progressPercent => (currentProgress / targetValue).clamp(0.0, 1.0);

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    int? targetValue,
    int? currentProgress,
    int? coinReward,
    int? gemReward,
    bool? isClaimed,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetValue: targetValue ?? this.targetValue,
      currentProgress: currentProgress ?? this.currentProgress,
      coinReward: coinReward ?? this.coinReward,
      gemReward: gemReward ?? this.gemReward,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }
}
