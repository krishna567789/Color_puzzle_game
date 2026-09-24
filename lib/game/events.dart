/// What a live-ops event counts toward its goal.
enum EventMetric {
  levelsWon('levels_won'),
  starsEarned('stars_earned');

  const EventMetric(this.storageKey);

  final String storageKey;

  /// What one finished board adds. A zero keeps an event out of a win that
  /// should not feed it, so no rule is hidden in the caller.
  int deltaForWin({required int stars}) => switch (this) {
    EventMetric.levelsWon => 1,
    EventMetric.starsEarned => stars,
  };
}

/// One repeating run of an event.
class EventWindow {
  const EventWindow({
    required this.start,
    required this.end,
    required this.isOpen,
  });

  final DateTime start;
  final DateTime end;
  final bool isOpen;
}

/// A calendar entry rather than a hard-coded date range: each event repeats on
/// its own cycle from a shared anchor, so a season can never ship already
/// expired the way a written-out `DateTime(2026, 8, 31)` did.
class EventTemplate {
  const EventTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerImage,
    required this.metric,
    required this.goal,
    required this.rewardCoins,
    required this.rewardGems,
    required this.cycle,
    required this.openFor,
    required this.epoch,
  });

  final String id;
  final String title;
  final String description;
  final String bannerImage;
  final EventMetric metric;

  /// Whole number of wins or stars a single run asks for.
  final int goal;
  final int rewardCoins;
  final int rewardGems;

  /// How often the event returns.
  final Duration cycle;

  /// How long each run stays open, always no longer than [cycle].
  final Duration openFor;

  /// Start of run #0, which also aligns the run to a weekday or a month edge.
  final DateTime epoch;

  /// Which run is current, or the last one to have begun.
  int _runIndex(DateTime now) =>
      now.difference(epoch).inSeconds ~/ cycle.inSeconds;

  /// The run a player sees at [now]: the open one, or the next one to come if
  /// the current run's window has already shut.
  EventWindow windowAt(DateTime now) {
    if (now.isBefore(epoch)) {
      return EventWindow(start: epoch, end: epoch.add(openFor), isOpen: false);
    }
    final current = epoch.add(cycle * _runIndex(now));
    final open = !now.isBefore(current) && now.isBefore(current.add(openFor));
    final start = open ? current : current.add(cycle);
    return EventWindow(
      start: start,
      end: start.add(openFor),
      isOpen: open,
    );
  }
}

/// The shipping calendar. Rewards are deliberately the same order of magnitude
/// as a month of playing (a win pays 13-40 coins), so an event tops up the
/// economy instead of replacing it.
class EventCatalog {
  /// Every run is derived from this anchor, so the calendar repeats by itself
  /// instead of shipping with a written-out expiry that quietly passes.
  static final DateTime _calendarStart = DateTime(2026, 1, 1);

  static final List<EventTemplate> all = [
    EventTemplate(
      id: 'season',
      title: 'SEASON OF SPLASH',
      description: 'Clear 25 boards this season for a full wallet refill.',
      bannerImage: 'assets/images/onboarding2.png',
      metric: EventMetric.levelsWon,
      goal: 25,
      rewardCoins: 500,
      rewardGems: 5,
      cycle: const Duration(days: 28),
      openFor: const Duration(days: 28),
      epoch: _calendarStart,
    ),
    EventTemplate(
      id: 'star_hunt',
      title: 'STAR HUNT',
      description: 'Collect 30 stars before the run closes.',
      bannerImage: 'assets/images/onboarding1.png',
      metric: EventMetric.starsEarned,
      goal: 30,
      rewardCoins: 300,
      rewardGems: 3,
      cycle: const Duration(days: 14),
      openFor: const Duration(days: 14),
      // Fridays, so the last days of a run fall on a weekend.
      epoch: DateTime(2026, 1, 2),
    ),
    EventTemplate(
      id: 'weekend',
      title: 'WEEKEND WARRIOR',
      description: 'Five boards between Saturday and Monday.',
      bannerImage: 'assets/images/splash.png',
      metric: EventMetric.levelsWon,
      goal: 5,
      rewardCoins: 200,
      rewardGems: 1,
      cycle: const Duration(days: 7),
      openFor: const Duration(days: 3),
      // Saturday.
      epoch: DateTime(2026, 1, 3),
    ),
  ];

  static EventTemplate? byId(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }
}
