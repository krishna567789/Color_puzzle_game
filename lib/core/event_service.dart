import '../content/content_types.dart';
import '../game/events.dart';
import '../models/event_model.dart';
import 'analytics_service.dart';
import 'progress_service.dart';
import 'storage_service.dart';

/// The live-ops calendar: which event runs when, how far it has got, and what
/// claiming it pays.
///
/// Progress is stored per window, so when a season rolls over the new one starts
/// at zero on its own and no code has to remember to reset it.
class EventService {
  static String _windowKey(DateTime start) => StorageService.dateKey(start);

  /// Every run the events screen shows: the live ones first, then the previews.
  static Future<List<GameEvent>> schedule({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final events = <GameEvent>[];
    for (final event in EventCatalog.all) {
      final window = event.windowAt(at);
      final state = await StorageService.getEventRun(
        event.id,
        _windowKey(window.start),
      );
      events.add(
        _build(
          event,
          window,
          checkedAt: at,
          progress: state.progress,
          claimed: state.claimed,
        ),
      );
    }
    events.sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return a.startDate.compareTo(b.startDate);
    });
    return events;
  }

  /// A closed run's card never shows the counter of the run it replaced.
  static GameEvent _build(
    EventSpec event,
    EventWindow window, {
    required DateTime checkedAt,
    required int progress,
    required bool claimed,
  }) {
    return GameEvent(
      id: event.id,
      title: event.title,
      description: event.description,
      bannerImage: event.bannerImage,
      startDate: window.start,
      endDate: window.end,
      goal: event.goal,
      rewardCoins: event.rewardCoins,
      rewardGems: event.rewardGems,
      metric: event.metricKind.storageKey,
      isOpen: window.isOpen,
      checkedAt: checkedAt,
      currentProgress: window.isOpen ? progress : 0,
      isClaimed: window.isOpen && claimed,
    );
  }

  /// One finished board feeds every open event that counts it.
  static Future<void> recordWin({required int stars, DateTime? now}) async {
    final at = now ?? DateTime.now();
    for (final event in EventCatalog.all) {
      final window = event.windowAt(at);
      if (!window.isOpen) continue;
      final delta = event.metricKind.deltaForWin(stars: stars);
      if (delta <= 0) continue;
      final total = await StorageService.bumpEventProgress(
        event.id,
        _windowKey(window.start),
        delta,
      );
      if (total >= event.goal && total - delta < event.goal) {
        AnalyticsService.logEvent(
          'event_goal_reached',
          parameters: {'event_id': event.id},
        );
      }
    }
  }

  /// Pays an event exactly once per run, from what storage says rather than
  /// from the card that was tapped: a screen left open across a rollover must
  /// not collect the run that just closed with a counter it no longer owns.
  static Future<GameEvent?> claim(String eventId, {DateTime? now}) async {
    final event = EventCatalog.byId(eventId);
    if (event == null) return null;
    final at = now ?? DateTime.now();
    final window = event.windowAt(at);
    if (!window.isOpen) return null;
    final key = _windowKey(window.start);
    final state = await StorageService.getEventRun(eventId, key);
    if (state.progress < event.goal || state.claimed) return null;
    if (!await StorageService.claimEventRun(eventId, key)) return null;

    await ProgressService.grant(
      coins: event.rewardCoins,
      gems: event.rewardGems,
    );
    AnalyticsService.logEvent(
      'event_reward_claimed',
      parameters: {
        'event_id': eventId,
        'coins': event.rewardCoins,
        'gems': event.rewardGems,
      },
    );
    return _build(
      event,
      window,
      checkedAt: at,
      progress: state.progress,
      claimed: true,
    );
  }
}
