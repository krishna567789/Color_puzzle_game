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
    for (final template in EventCatalog.all) {
      final window = template.windowAt(at);
      final state = await StorageService.getEventRun(
        template.id,
        _windowKey(window.start),
      );
      events.add(
        _build(
          template,
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
    EventTemplate template,
    EventWindow window, {
    required DateTime checkedAt,
    required int progress,
    required bool claimed,
  }) {
    return GameEvent(
      id: template.id,
      title: template.title,
      description: template.description,
      bannerImage: template.bannerImage,
      startDate: window.start,
      endDate: window.end,
      goal: template.goal,
      rewardCoins: template.rewardCoins,
      rewardGems: template.rewardGems,
      metric: template.metric.storageKey,
      isOpen: window.isOpen,
      checkedAt: checkedAt,
      currentProgress: window.isOpen ? progress : 0,
      isClaimed: window.isOpen && claimed,
    );
  }

  /// One finished board feeds every open event that counts it.
  static Future<void> recordWin({required int stars, DateTime? now}) async {
    final at = now ?? DateTime.now();
    for (final template in EventCatalog.all) {
      final window = template.windowAt(at);
      if (!window.isOpen) continue;
      final delta = template.metric.deltaForWin(stars: stars);
      if (delta <= 0) continue;
      final total = await StorageService.bumpEventProgress(
        template.id,
        _windowKey(window.start),
        delta,
      );
      if (total >= template.goal && total - delta < template.goal) {
        AnalyticsService.logEvent(
          'event_goal_reached',
          parameters: {'event_id': template.id},
        );
      }
    }
  }

  /// Pays an event exactly once per run, from what storage says rather than
  /// from the card that was tapped: a screen left open across a rollover must
  /// not collect the run that just closed with a counter it no longer owns.
  static Future<GameEvent?> claim(String eventId, {DateTime? now}) async {
    final template = EventCatalog.byId(eventId);
    if (template == null) return null;
    final at = now ?? DateTime.now();
    final window = template.windowAt(at);
    if (!window.isOpen) return null;
    final key = _windowKey(window.start);
    final state = await StorageService.getEventRun(eventId, key);
    if (state.progress < template.goal || state.claimed) return null;
    if (!await StorageService.claimEventRun(eventId, key)) return null;

    await ProgressService.grant(
      coins: template.rewardCoins,
      gems: template.rewardGems,
    );
    AnalyticsService.logEvent(
      'event_reward_claimed',
      parameters: {
        'event_id': eventId,
        'coins': template.rewardCoins,
        'gems': template.rewardGems,
      },
    );
    return _build(
      template,
      window,
      checkedAt: at,
      progress: state.progress,
      claimed: true,
    );
  }
}
