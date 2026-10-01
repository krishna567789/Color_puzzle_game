import '../content/content_repository.dart';
import '../content/content_types.dart';
import 'rewards.dart';

/// What a live-ops event counts toward its goal.
enum EventMetric {
  levelsWon('levels_won'),
  starsEarned('stars_earned'),
  perfectWins('perfect_wins');

  const EventMetric(this.storageKey);

  final String storageKey;

  /// The metric a document names, or null when it names nothing. The content
  /// validator asks this rather than reading [values] itself, so an event that
  /// would crash on `metricKind` is caught before it reaches a screen.
  static EventMetric? tryParse(String name) {
    for (final metric in values) {
      if (metric.name == name) return metric;
    }
    return null;
  }

  /// The most one day of play can add. A run's goal is checked against this
  /// multiplied by how long it stays open, which is what stops a season asking
  /// for boards nobody could finish in a month.
  int get dailyCeiling => switch (this) {
    EventMetric.levelsWon => DailyStat.boardsPerDay,
    EventMetric.starsEarned => DailyStat.boardsPerDay * 3,
    EventMetric.perfectWins => DailyStat.boardsPerDay,
  };

  /// What one finished board adds. A zero keeps an event out of a win that
  /// should not feed it, so no rule is hidden in the caller.
  int deltaForWin({required int stars}) => switch (this) {
    EventMetric.levelsWon => 1,
    EventMetric.starsEarned => stars,
    EventMetric.perfectWins => stars == 3 ? 1 : 0,
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

/// The calendar maths an event document needs.
///
/// A window is derived from the event's own epoch and cycle rather than written
/// out as a date range, so a season can never ship already expired.
extension EventCalendar on EventSpec {
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
    return EventWindow(start: start, end: start.add(openFor), isOpen: open);
  }

  /// What a win adds to this event. The document's name is checked by the
  /// content validator, so this never has to guess.
  EventMetric get metricKind =>
      EventMetric.values.firstWhere((value) => value.name == metric);
}

/// The shipping calendar. Rewards are deliberately the same order of magnitude
/// as a month of playing (a win pays 13-40 coins), so an event tops up the
/// economy instead of replacing it.
class EventCatalog {
  static List<EventSpec> get all => ContentRepository.content.events;

  static EventSpec? byId(String id) {
    for (final event in all) {
      if (event.id == id) return event;
    }
    return null;
  }
}
