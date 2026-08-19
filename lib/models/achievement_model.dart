class Achievement {
  final String id;
  final String title;
  final String description;
  final int goal;
  final int rewardCoins;
  final int rewardGems;
  int currentProgress;
  bool isClaimed;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    this.rewardCoins = 0,
    this.rewardGems = 0,
    this.currentProgress = 0,
    this.isClaimed = false,
  });

  bool get isCompleted => currentProgress >= goal;

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      goal: map['goal'],
      rewardCoins: map['rewardCoins'] ?? 0,
      rewardGems: map['rewardGems'] ?? 0,
      currentProgress: map['currentProgress'] ?? 0,
      isClaimed: map['isClaimed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'goal': goal,
      'rewardCoins': rewardCoins,
      'rewardGems': rewardGems,
      'currentProgress': currentProgress,
      'isClaimed': isClaimed,
    };
  }
}
