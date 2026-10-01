/// The vocabulary every content document is parsed with.
///
/// Content is data first and code second: a missing, wrongly typed or
/// out-of-range field is an issue carrying the exact path it came from, never a
/// silent default. A document that reports issues is rejected whole and the
/// repository keeps the last copy it trusted.
library;

import 'dart:ui' show Color;

import '../game/level_design.dart';
import '../game/liquid_patterns.dart';

/// Where each content problem came from, spelled as `document/field`.
class ContentIssues {
  final List<String> _messages = [];

  void add(String path, String message) => _messages.add('$path: $message');

  bool get hasErrors => _messages.isNotEmpty;

  int get length => _messages.length;

  List<String> get messages => List.unmodifiable(_messages);

  @override
  String toString() => hasErrors ? _messages.join('\n') : 'no content issues';
}

/// Reads one JSON object, remembering the path it sits at.
class JsonObject {
  JsonObject(this.path, this.map, this.issues);

  final String path;
  final Map<String, dynamic> map;
  final ContentIssues issues;

  String? string(String key, {String? def}) {
    final value = map[key];
    if (value == null) {
      if (def == null) issues.add('$path.$key', 'required');
      return def;
    }
    if (value is! String || value.isEmpty) {
      issues.add('$path.$key', 'expected a non-empty string, got $value');
      return def;
    }
    return value;
  }

  /// A string a document may leave blank - a store id that has not been
  /// created yet, say. Absent or empty is fine; the wrong type is not.
  String optional(String key) {
    final value = map[key];
    if (value == null) return '';
    if (value is! String) {
      issues.add('$path.$key', 'expected a string, got $value');
      return '';
    }
    return value;
  }

  int? integer(String key, {int? def, int? min, int? max}) {
    final value = map[key];
    if (value == null) {
      if (def == null) issues.add('$path.$key', 'required');
      return def;
    }
    if (value is! int) {
      issues.add('$path.$key', 'expected a whole number, got $value');
      return def;
    }
    if (min != null && value < min) {
      issues.add('$path.$key', 'must be at least $min, got $value');
      return def;
    }
    if (max != null && value > max) {
      issues.add('$path.$key', 'must be at most $max, got $value');
      return def;
    }
    return value;
  }

  /// An ARGB colour spelled as eight hex digits, `FFFF7A00`. The one way a
  /// document may name a colour, so a liquid and a chapter badge cannot drift
  /// into two different notations.
  int argb(String key, {int def = 0xFF000000}) {
    final value = map[key];
    if (value == null) return def;
    if (value is! String) {
      issues.add('$path.$key', 'expected eight hex digits, got $value');
      return def;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (value.length != 8 || parsed == null) {
      issues.add('$path.$key', 'expected 8 hex digits like FFFF2A2A, got "$value"');
      return def;
    }
    return parsed;
  }

  bool boolean(String key, {bool def = false}) {
    final value = map[key];
    if (value == null) return def;
    if (value is! bool) {
      issues.add('$path.$key', 'expected true or false, got $value');
      return def;
    }
    return value;
  }

  /// A list of non-empty strings, which is how ids travel through the set.
  List<String> strings(String key, {bool required = true}) {
    final value = map[key];
    if (value == null) {
      if (required) issues.add('$path.$key', 'required');
      return const [];
    }
    if (value is! List) {
      issues.add('$path.$key', 'expected a list, got $value');
      return const [];
    }
    final out = <String>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! String || item.isEmpty) {
        issues.add('$path.$key[$i]', 'expected a string, got $item');
        continue;
      }
      out.add(item);
    }
    return out;
  }

  /// The tubes of a board: a list of lists of colour ids.
  List<List<String>> tubeLists(String key) {
    final value = map[key];
    if (value == null) {
      issues.add('$path.$key', 'required');
      return const [];
    }
    if (value is! List) {
      issues.add('$path.$key', 'expected a list of tubes, got $value');
      return const [];
    }
    final out = <List<String>>[];
    for (var i = 0; i < value.length; i++) {
      final tube = value[i];
      if (tube is! List) {
        issues.add('$path.$key[$i]', 'expected a list of colour ids');
        continue;
      }
      final layers = <String>[];
      for (var j = 0; j < tube.length; j++) {
        final color = tube[j];
        if (color is! String || color.isEmpty) {
          issues.add(
            '$path.$key[$i][$j]',
            'expected a colour id, got $color',
          );
          continue;
        }
        layers.add(color);
      }
      out.add(layers);
    }
    return out;
  }

  List<int> integers(String key, {List<int> def = const []}) {
    final value = map[key];
    if (value == null) return def;
    if (value is! List) {
      issues.add('$path.$key', 'expected a list, got $value');
      return def;
    }
    final out = <int>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! int || item < 0) {
        issues.add('$path.$key[$i]', 'expected 0 or more, got $item');
        continue;
      }
      out.add(item);
    }
    return out;
  }

  /// A list of ARGB colours, each spelled the way [argb] spells one. This is how
  /// a theme names the gradient it paints with.
  List<int> argbs(String key, {int min = 0, int max = 99}) {
    final value = map[key];
    if (value == null) return const [];
    if (value is! List) {
      issues.add('$path.$key', 'expected a list, got $value');
      return const [];
    }
    if (value.length < min || value.length > max) {
      issues.add('$path.$key', 'expected $min to $max colours, got ${value.length}');
      return const [];
    }
    final out = <int>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! String ||
          item.length != 8 ||
          int.tryParse(item, radix: 16) == null) {
        issues.add(
          '$path.$key[$i]',
          'expected 8 hex digits like FFFF2A2A, got "$item"',
        );
        continue;
      }
      out.add(int.parse(item, radix: 16));
    }
    return out;
  }

  List<JsonObject> objects(String key, {bool required = true}) {
    final value = map[key];
    if (value == null) {
      if (required) issues.add('$path.$key', 'required');
      return const [];
    }
    if (value is! List) {
      issues.add('$path.$key', 'expected a list, got $value');
      return const [];
    }
    final out = <JsonObject>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! Map<String, dynamic>) {
        issues.add('$path.$key[$i]', 'expected an object, got $item');
        continue;
      }
      out.add(JsonObject('$path.$key[$i]', item, issues));
    }
    return out;
  }

  /// A nested object read under its own path, or null when it is absent.
  JsonObject? child(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      issues.add('$path.$key', 'expected an object, got $value');
      return null;
    }
    return JsonObject('$path.$key', value, issues);
  }

  /// A field whose value must be one of a known set of names.
  String nameFrom(String key, List<String> allowed, {String? def}) {
    final value = string(key, def: def);
    if (value == null) return def ?? '';
    if (!allowed.contains(value)) {
      issues.add('$path.$key', 'unknown "$value", expected ${allowed.join(', ')}');
      return def ?? '';
    }
    return value;
  }

  /// Flags a field the schema never heard of, so a typo cannot hide.
  void rejectUnknownKeys(Iterable<String> known) {
    for (final key in map.keys) {
      if (!known.contains(key)) {
        issues.add('$path.$key', 'not a field this schema knows about');
      }
    }
  }

  DateTime date(String key, {DateTime? def}) {
    final raw = string(key);
    if (raw == null) return def ?? DateTime(2026);
    final value = DateTime.tryParse(raw);
    if (value == null) {
      issues.add('$path.$key', 'not an ISO date, got "$raw"');
      return def ?? DateTime(2026);
    }
    return value;
  }
}

/// A liquid colour as data: a stable id, the hue a board paints, and the shape
/// a layer wears in colourblind mode.
class LiquidColorSpec {
  LiquidColorSpec({
    required this.id,
    required this.name,
    required this.argb,
    required this.pattern,
  });

  static const fields = ['id', 'name', 'argb', 'pattern'];

  final String id;
  final String name;
  final int argb;
  final LiquidPattern pattern;

  Color get swatch => Color(argb);

  factory LiquidColorSpec.parse(JsonObject json) => LiquidColorSpec(
    id: json.string('id') ?? '',
    name: json.string('name') ?? '',
    // A missing colour lands on transparent black, which the contract refuses
    // as "a liquid must be opaque" rather than quietly painting something.
    argb: json.argb('argb', def: 0),
    pattern: markFor(json),
  );

  /// The shape this colour wears. An unknown name is an issue the document is
  /// rejected for, so the value returned here never reaches a player.
  static LiquidPattern markFor(JsonObject json) {
    final raw = json.string('pattern');
    if (raw != null) {
      for (final value in LiquidPattern.values) {
        if (value.name == raw) return value;
      }
      json.issues.add('${json.path}.pattern', 'unknown mark "$raw"');
    }
    return LiquidPattern.dots;
  }
}

/// The difficulty numbers behind one board, before it is dealt.
class LevelConfigSpec {
  LevelConfigSpec({
    required this.colorCount,
    required this.capacity,
    required this.freeTubes,
    required this.mysteryTubes,
    required this.mixRounds,
  });

  final int colorCount;
  final int capacity;
  final int freeTubes;
  final int mysteryTubes;
  final int mixRounds;

  LevelConfig toConfig(int level) => LevelConfig(
    level: level,
    colorCount: colorCount,
    capacity: capacity,
    freeTubes: freeTubes,
    mysteryTubes: mysteryTubes,
    mixRounds: mixRounds,
  );
}

/// A difficulty curve as data. The shape of the climb stays in Dart; every
/// number a balancing decision moves lives in the document.
class CurveSpec {
  CurveSpec({
    required this.startingColors,
    required this.levelsPerColor,
    required this.maxColorCount,
    required this.wideFreeTubes,
    required this.tightFreeTubes,
    required this.wideColorThreshold,
    required this.deepFromLevel,
    required this.baseCapacity,
    required this.deepCapacity,
    required this.mysteryFromLevel,
    required this.levelsPerMysteryTube,
    required this.maxMysteryTubes,
    required this.mixPerCapacityStep,
    required this.mixPerTenLevels,
    required this.maxTubeCount,
    required this.maxBoardTubes,
  });

  static const fields = [
    'startingColors',
    'levelsPerColor',
    'maxColorCount',
    'wideFreeTubes',
    'tightFreeTubes',
    'wideColorThreshold',
    'deepFromLevel',
    'baseCapacity',
    'deepCapacity',
    'mysteryFromLevel',
    'levelsPerMysteryTube',
    'maxMysteryTubes',
    'mixPerCapacityStep',
    'mixPerTenLevels',
    'maxTubeCount',
    'maxBoardTubes',
  ];

  final int startingColors;
  final int levelsPerColor;
  final int maxColorCount;
  final int wideFreeTubes;
  final int tightFreeTubes;
  final int wideColorThreshold;
  final int deepFromLevel;
  final int baseCapacity;
  final int deepCapacity;
  final int mysteryFromLevel;
  final int levelsPerMysteryTube;
  final int maxMysteryTubes;
  final int mixPerCapacityStep;
  final int mixPerTenLevels;
  final int maxTubeCount;

  /// The most bottles a board may hold. [maxTubeCount] caps what the curve asks
  /// a *generated* board for; this caps any board, authored ones included,
  /// because past this many the grid stops fitting the screen no matter how the
  /// keys are built.
  final int maxBoardTubes;

  /// Parsed with the current curve's numbers as the defaults, so a document
  /// that leaves a knob out keeps the shipped behaviour rather than a zero.
  factory CurveSpec.parse(JsonObject json) => CurveSpec(
    startingColors: json.integer('startingColors', def: 3, min: 2) ?? 3,
    levelsPerColor: json.integer('levelsPerColor', def: 6, min: 1) ?? 6,
    maxColorCount: json.integer('maxColorCount', def: 12, min: 2) ?? 12,
    wideFreeTubes: json.integer('wideFreeTubes', def: 3, min: 1) ?? 3,
    tightFreeTubes: json.integer('tightFreeTubes', def: 2, min: 1) ?? 2,
    wideColorThreshold:
        json.integer('wideColorThreshold', def: 6, min: 1) ?? 6,
    deepFromLevel: json.integer('deepFromLevel', def: 121, min: 1) ?? 121,
    baseCapacity: json.integer('baseCapacity', def: 4, min: 3) ?? 4,
    deepCapacity: json.integer('deepCapacity', def: 5, min: 3) ?? 5,
    mysteryFromLevel:
        json.integer('mysteryFromLevel', def: 10, min: 1) ?? 10,
    levelsPerMysteryTube:
        json.integer('levelsPerMysteryTube', def: 12, min: 1) ?? 12,
    maxMysteryTubes: json.integer('maxMysteryTubes', def: 3, min: 0) ?? 3,
    mixPerCapacityStep:
        json.integer('mixPerCapacityStep', def: 2, min: 1) ?? 2,
    mixPerTenLevels: json.integer('mixPerTenLevels', def: 1, min: 0) ?? 1,
    maxTubeCount: json.integer('maxTubeCount', def: 14, min: 4) ?? 14,
    maxBoardTubes: json.integer('maxBoardTubes', def: 20, min: 4) ?? 20,
  );

  /// The shipped curve, for a build whose content set failed to load.
  static CurveSpec defaults() => CurveSpec.parse(
    JsonObject('_defaults.curve', <String, dynamic>{}, ContentIssues()),
  );

  LevelConfigSpec configFor(int level) {
    final clamped = level < 1 ? 1 : level;
    final colorCount =
        startingColors - 1 + (clamped + levelsPerColor - 1) ~/ levelsPerColor;
    final bounded = colorCount > maxColorCount ? maxColorCount : colorCount;
    final capacity = clamped >= deepFromLevel ? deepCapacity : baseCapacity;
    return LevelConfigSpec(
      colorCount: bounded,
      capacity: capacity,
      freeTubes:
          bounded <= wideColorThreshold ? wideFreeTubes : tightFreeTubes,
      mysteryTubes: ((clamped - mysteryFromLevel) ~/ levelsPerMysteryTube)
          .clamp(0, maxMysteryTubes),
      mixRounds:
          bounded * (capacity + mixPerCapacityStep) +
          clamped ~/ 10 * mixPerTenLevels,
    );
  }
}

/// A named block of levels, with the look and the payoff that make it feel like
/// somewhere rather than a number.
class ChapterSpec {
  ChapterSpec({
    required this.id,
    required this.name,
    required this.startsAtLevel,
    required this.blurb,
    required this.image,
    required this.tint,
    required this.accent,
    required this.palette,
    required this.rewardCoins,
    required this.rewardGems,
  });

  static const fields = [
    'id',
    'name',
    'startsAtLevel',
    'blurb',
    'image',
    'tint',
    'accent',
    'palette',
    'rewardCoins',
    'rewardGems',
  ];

  /// The room every chapter starts from until its own document names another.
  static const kDefaultImage = 'assets/images/wizard_room_bg.jpg';

  final String id;
  final String name;
  final int startsAtLevel;

  /// One line on the chapter card: what this block asks of the player.
  final String blurb;

  /// The art behind the map while this chapter is on screen.
  final String image;

  /// A colour grade over that art, so one room can read as five places.
  final int tint;

  /// The badge, the path and the node ring.
  final int accent;

  /// The colours this chapter's boards are dealt from, empty meaning the whole
  /// palette. The generator is the only reader: it lets the first chapters open
  /// with hues nobody can confuse, and holds them back until the player has
  /// learned the rest of the shelf.
  final List<String> palette;

  /// Paid once, when the chapter's last board is cleared.
  final int rewardCoins;
  final int rewardGems;

  Color get tintColor => Color(tint);
  Color get accentColor => Color(accent);

  factory ChapterSpec.parse(JsonObject json) => ChapterSpec(
    id: json.string('id') ?? '',
    name: json.string('name') ?? '',
    startsAtLevel: json.integer('startsAtLevel', min: 1) ?? 1,
    blurb: json.optional('blurb'),
    image: json.string('image', def: kDefaultImage) ?? kDefaultImage,
    // No tint and a visible accent are the defaults; a chapter that names
    // neither still looks like the room it is standing in.
    tint: json.argb('tint', def: 0x00000000),
    accent: json.argb('accent', def: 0xFF39C7FF),
    palette: json.strings('palette', required: false),
    rewardCoins: json.integer('rewardCoins', min: 0, def: 0) ?? 0,
    rewardGems: json.integer('rewardGems', min: 0, def: 0) ?? 0,
  );
}

/// The modes that play a ladder of their own rather than the campaign's.
///
/// These are the names of [GameController]'s `GameMode` values, minus classic
/// and daily, and they double as the key every per-mode record is stored under.
/// A test keeps the two lists in step, the same way `kPowerUpCostKeys` does.
const List<String> kSideModeIds = ['challenge', 'timeAttack'];

/// A side mode: its own finite ladder, its own room and its own name.
///
/// A side mode used to read the campaign's progress to decide how hard its
/// boards were, so a player's Challenge run was a different shape on every
/// device and nobody could say which stage they were on. The ladder is the
/// fix: [stages] is the list of boards, in order, and its length is where the
/// mode ends.
class ModeSpec {
  ModeSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.image,
    required this.tint,
    required this.accent,
    required this.stages,
  });

  static const fields = [
    'id',
    'name',
    'blurb',
    'image',
    'tint',
    'accent',
    'stages',
  ];

  /// One of [kSideModeIds], and the key every per-mode record is stored under.
  final String id;
  final String name;
  final String blurb;

  /// The room this mode's map is standing in, the same way a chapter names one.
  final String image;

  /// A colour grade over that room.
  final int tint;

  /// The nodes, the path and the header.
  final int accent;

  /// Which point on the difficulty curve each stage sits at, in order, 1-based
  /// by position. The boards themselves are still dealt from that shape, so a
  /// stage is defined by its difficulty rather than by hand.
  final List<int> stages;

  Color get tintColor => Color(tint);
  Color get accentColor => Color(accent);

  int get stageCount => stages.length;

  /// The curve position of [stage], counted from 1, or null past the ladder.
  int? anchorFor(int stage) =>
      stage >= 1 && stage <= stages.length ? stages[stage - 1] : null;

  factory ModeSpec.parse(JsonObject json) => ModeSpec(
    id: json.string('id') ?? '',
    name: json.string('name') ?? '',
    blurb: json.optional('blurb'),
    image: json.string('image', def: ChapterSpec.kDefaultImage)
        ?? ChapterSpec.kDefaultImage,
    tint: json.argb('tint', def: 0x00000000),
    accent: json.argb('accent', def: 0xFF39C7FF),
    stages: json.integers('stages'),
  );
}

/// A finished board, exactly as a player meets it.
///
/// The tubes are spelled out in colour ids rather than as a seed, so a level can
/// be read, diffed and edited without running a generator, and so a change to
/// the dealing code can never quietly re-roll a board someone has already beat.
class LevelSpec {
  LevelSpec({
    required this.id,
    required this.level,
    required this.chapter,
    required this.capacity,
    required this.colors,
    required this.tubes,
    required this.hidden,
    required this.parMoves,
  });

  static const fields = [
    'id',
    'level',
    'chapter',
    'capacity',
    'colors',
    'tubes',
    'hidden',
    'parMoves',
  ];

  final String id;
  final int level;
  final String chapter;
  final int capacity;

  /// The colours in play, each appearing exactly [capacity] times.
  final List<String> colors;
  final List<List<String>> tubes;

  /// How many layers of each tube start face-down.
  final List<int> hidden;

  /// The shortest solution the solver proved for this exact board.
  final int parMoves;

  factory LevelSpec.parse(JsonObject json) => LevelSpec(
    id: json.string('id') ?? '',
    level: json.integer('level', min: 1) ?? 0,
    chapter: json.string('chapter') ?? '',
    capacity: json.integer('capacity', min: 1, max: 9) ?? 0,
    colors: json.strings('colors'),
    tubes: json.tubeLists('tubes'),
    hidden: json.integers('hidden'),
    parMoves: json.integer('parMoves', min: 1) ?? 0,
  );
}

/// A day's task, and the counter its progress is read from.
class QuestSpec {
  QuestSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.stat,
    required this.target,
    required this.coins,
    required this.gems,
  });

  static const fields = [
    'id',
    'title',
    'description',
    'stat',
    'target',
    'coins',
    'gems',
  ];

  final String id;
  final String title;
  final String description;
  final String stat;
  final int target;
  final int coins;
  final int gems;

  factory QuestSpec.parse(JsonObject json) => QuestSpec(
    id: json.string('id') ?? '',
    title: json.string('title') ?? '',
    description: json.string('description') ?? '',
    stat: json.string('stat') ?? '',
    target: json.integer('target', min: 1) ?? 1,
    coins: json.integer('coins', min: 0, def: 0) ?? 0,
    gems: json.integer('gems', min: 0, def: 0) ?? 0,
  );
}

/// A repeating live-ops run.
class EventSpec {
  EventSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerImage,
    required this.metric,
    required this.goal,
    required this.rewardCoins,
    required this.rewardGems,
    required this.cycleDays,
    required this.openForDays,
    required this.epoch,
  });

  static const fields = [
    'id',
    'title',
    'description',
    'bannerImage',
    'metric',
    'goal',
    'rewardCoins',
    'rewardGems',
    'cycleDays',
    'openForDays',
    'epoch',
  ];

  final String id;
  final String title;
  final String description;
  final String bannerImage;

  /// One of the counters an event may feed; see [EventMetric].
  final String metric;
  final int goal;
  final int rewardCoins;
  final int rewardGems;

  /// How often the event returns, and how long each run stays open.
  final int cycleDays;
  final int openForDays;

  /// Start of run zero, which also aligns the run to a weekday.
  final DateTime epoch;

  Duration get cycle => Duration(days: cycleDays);
  Duration get openFor => Duration(days: openForDays);

  factory EventSpec.parse(JsonObject json) => EventSpec(
    id: json.string('id') ?? '',
    title: json.string('title') ?? '',
    description: json.string('description') ?? '',
    bannerImage: json.string('bannerImage') ?? '',
    metric: json.string('metric') ?? '',
    goal: json.integer('goal', min: 1) ?? 1,
    rewardCoins: json.integer('rewardCoins', min: 0, def: 0) ?? 0,
    rewardGems: json.integer('rewardGems', min: 0, def: 0) ?? 0,
    cycleDays: json.integer('cycleDays', min: 1) ?? 7,
    openForDays: json.integer('openForDays', min: 1) ?? 7,
    epoch: json.date('epoch'),
  );
}

/// A long-run goal and what claiming it pays.
class AchievementSpec {
  AchievementSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.stat,
    required this.goal,
    required this.rewardCoins,
    required this.rewardGems,
    required this.playGamesId,
  });

  static const fields = [
    'id',
    'title',
    'description',
    'stat',
    'goal',
    'rewardCoins',
    'rewardGems',
    'playGamesId',
  ];

  final String id;
  final String title;
  final String description;

  /// Which stored counter this goal is measured against.
  final String stat;
  final int goal;
  final int rewardCoins;
  final int rewardGems;

  /// The Play Games achievement this mirrors, once one has been created.
  final String playGamesId;

  factory AchievementSpec.parse(JsonObject json) => AchievementSpec(
    id: json.string('id') ?? '',
    title: json.string('title') ?? '',
    description: json.string('description') ?? '',
    stat: json.string('stat') ?? '',
    goal: json.integer('goal', min: 1) ?? 1,
    rewardCoins: json.integer('rewardCoins', min: 0, def: 0) ?? 0,
    rewardGems: json.integer('rewardGems', min: 0, def: 0) ?? 0,
    playGamesId: json.optional('playGamesId'),
  );
}

/// One row of the shop.
/// The pre-rendered glass a skin draws in play. One formula, so the contract
/// can refuse a listing whose art was never shipped.
String skinGlassPath(String skinId) => 'assets/skins/$skinId.png';

/// The three-quarter render the shop sells a skin with.
String bottleHeroPath(String skinId) => 'assets/skins/hero_$skinId.png';

class ShopSpec {
  ShopSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.coins,
    required this.gems,
    required this.iapProductId,
    required this.free,
    required this.grantCoins,
    required this.entitlement,
    required this.image,
    required this.gradient,
  });

  static const fields = [
    'id',
    'name',
    'description',
    'type',
    'coins',
    'gems',
    'iapProductId',
    'free',
    'grantCoins',
    'entitlement',
    'image',
    'gradient',
  ];

  static const types = ['tubeSkin', 'theme', 'powerUp', 'iap'];

  /// The one entitlement the game knows how to switch on. A paid row that names
  /// anything else is refused by the contract, so a typo cannot sell a promise
  /// nothing keeps.
  static const kRemoveAds = 'removeAds';

  final String id;
  final String name;
  final String description;
  final String type;
  final int coins;
  final int gems;

  /// The store product id of a paid row. No money text is ever stored: the
  /// price a player sees comes from the store, in their own currency.
  final String iapProductId;

  /// The row every player already owns, such as the starting bottle.
  final bool free;

  /// Wallet coins a paid row credits on delivery. What the till hands out is
  /// decided here, not by a branch in the purchase listener.
  final int grantCoins;

  /// What a paid row unlocks forever, or empty when it just credits a wallet.
  final String entitlement;

  /// A theme's backdrop art. Empty means the theme paints its [gradient] and
  /// nothing else, which is how a look ships without a new JPEG.
  final String image;

  /// A theme's colours, top of the room down. The card preview and the glow are
  /// painted from these, so a theme cannot advertise one look and wear another.
  final List<int> gradient;

  bool get isIap => type == 'iap';
  bool get costsGems => gems > 0;
  int get cost => costsGems ? gems : coins;

  /// The in-play bottle glass this row unlocks.
  String get glassImage => skinGlassPath(id);

  /// The three-quarter render the shop sells it with.
  String get heroImage => bottleHeroPath(id);

  /// The room's colours, top down, ready to paint with.
  List<Color> get gradientColors => [for (final argb in gradient) Color(argb)];

  /// The colour a theme glows with: the one in the middle of its own gradient,
  /// so nothing in the shop has to know which id is which.
  Color get glowColor =>
      Color(gradient.isEmpty ? 0xFF39C7FF : gradient[gradient.length ~/ 2]);

  /// A non-consumable: the store may be asked to hand it back after a reinstall,
  /// so it is the only kind of row a restore may re-grant.
  bool get isEntitlement => entitlement.isNotEmpty;

  factory ShopSpec.parse(JsonObject json) => ShopSpec(
    id: json.string('id') ?? '',
    name: json.string('name') ?? '',
    description: json.string('description') ?? '',
    type: json.nameFrom('type', types),
    coins: json.integer('coins', min: 0, def: 0) ?? 0,
    gems: json.integer('gems', min: 0, def: 0) ?? 0,
    iapProductId: json.optional('iapProductId'),
    free: json.boolean('free'),
    grantCoins: json.integer('grantCoins', min: 0, def: 0) ?? 0,
    entitlement: json.optional('entitlement'),
    image: json.optional('image'),
    gradient: json.argbs('gradient', min: 2, max: 4),
  );
}

/// One wedge of the lucky wheel.
///
/// The wheel used to be a list built inside its own screen, so a prize could be
/// retuned only with a build and nothing checked what the dial paid out. As
/// content, the same validator that refuses a shop row that delivers nothing can
/// refuse a wheel that mints coins.
class WheelSegmentSpec {
  WheelSegmentSpec({
    required this.id,
    required this.kind,
    required this.amount,
  });

  static const fields = ['id', 'kind', 'amount'];

  /// What a wedge can hold. `nothing` is the dud the wheel has to have at least
  /// one of, or every spin is a payout.
  static const kinds = ['coins', 'gems', 'nothing'];

  final String id;

  /// One of [kinds].
  final String kind;

  /// How many coins or gems the wedge pays; zero for a dud.
  final int amount;

  bool get paysCoins => kind == 'coins' && amount > 0;
  bool get paysGems => kind == 'gems' && amount > 0;

  /// The words under the prize on the dial and in the dialog it wins.
  String get label => switch (kind) {
    'gems' => '$amount Gems',
    'nothing' => 'Try Again',
    _ => '$amount Coins',
  };

  factory WheelSegmentSpec.parse(JsonObject json) => WheelSegmentSpec(
    id: json.string('id') ?? '',
    kind: json.nameFrom('kind', kinds),
    amount: json.integer('amount', min: 0, def: 0) ?? 0,
  );
}

/// The economy's numbers. The formulas stay in Dart; these are the values a
/// balancing decision changes.
class RewardTuning {
  RewardTuning({
    required this.coinBase,
    required this.coinPerLevels,
    required this.sideModePercent,
    required this.xpForThreeStars,
    required this.firstThreeStarGems,
    required this.twoStarSlack,
    required this.levelXpBase,
    required this.levelXpStep,
    required this.streakCycle,
    required this.streakCoins,
    required this.streakGems,
    required this.extraSpinsPerDay,
    required this.extraSpinGems,
    required this.powerUpCosts,
    required this.extraChanceCost,
    required this.maxExtraChances,
    required this.powerUpInflationLevels,
    required this.powerUpInflationStep,
    required this.powerUpInflationCap,
  });

  /// Coins a win starts from, before stars.
  final int coinBase;

  /// A level adds one coin step every this many levels.
  final int coinPerLevels;

  /// Side modes pay this percent of a classic win.
  final int sideModePercent;
  final int xpForThreeStars;
  final int firstThreeStarGems;

  /// How far past par a run may drift and still take two stars.
  final int twoStarSlack;
  final int levelXpBase;
  final int levelXpStep;
  final int streakCycle;
  final int streakCoins;
  final int streakGems;
  final int extraSpinsPerDay;
  final int extraSpinGems;

  /// Base cost of each power-up, keyed by [PowerUp] name.
  final Map<String, int> powerUpCosts;
  final int extraChanceCost;
  final int maxExtraChances;

  /// Every this many levels, a power-up costs [powerUpInflationStep] more.
  final int powerUpInflationLevels;
  final int powerUpInflationStep;
  final int powerUpInflationCap;

  int costOf(String powerUp, int level) {
    final base = powerUpCosts[powerUp] ?? 0;
    final steps = (level ~/ powerUpInflationLevels).clamp(
      0,
      powerUpInflationCap,
    );
    return base + steps * powerUpInflationStep;
  }

  factory RewardTuning.parse(JsonObject json) {
    final levels = json.child('levels');
    final player = json.child('player');
    final streak = json.child('streak');
    final spin = json.child('spin');
    final tools = json.child('powerUps');

    final costs = <String, int>{};
    final costsNode = tools?.map['costs'];
    if (costsNode is Map<String, dynamic>) {
      costsNode.forEach((key, value) {
        if (value is! int) {
          json.issues.add('${tools!.path}.costs.$key', 'expected a number');
          return;
        }
        costs[key] = value;
      });
    }

    return RewardTuning(
      coinBase: levels?.integer('coinBase', def: 12, min: 0) ?? 12,
      coinPerLevels: levels?.integer('coinPerLevels', def: 4, min: 1) ?? 4,
      sideModePercent:
          levels?.integer('sideModePercent', def: 150, min: 100) ?? 150,
      xpForThreeStars: levels?.integer('xpForThreeStars', def: 40, min: 1) ?? 40,
      firstThreeStarGems:
          levels?.integer('firstThreeStarGems', def: 1, min: 0) ?? 1,
      twoStarSlack: levels?.integer('twoStarSlack', def: 4, min: 0) ?? 4,
      levelXpBase: player?.integer('xpBase', def: 40, min: 1) ?? 40,
      levelXpStep: player?.integer('xpStep', def: 40, min: 1) ?? 40,
      streakCycle: streak?.integer('cycleDays', def: 7, min: 1) ?? 7,
      streakCoins: streak?.integer('coinsPerDay', def: 50, min: 0) ?? 50,
      streakGems: streak?.integer('gemsOnLastDay', def: 5, min: 0) ?? 5,
      extraSpinsPerDay:
          spin?.integer('extraSpinsPerDay', def: 2, min: 0) ?? 2,
      extraSpinGems: spin?.integer('extraSpinGems', def: 3, min: 1) ?? 3,
      powerUpCosts: costs,
      extraChanceCost:
          tools?.integer('extraChanceCost', def: 50, min: 0) ?? 50,
      maxExtraChances: tools?.integer('maxExtraChances', def: 3, min: 0) ?? 3,
      powerUpInflationLevels:
          tools?.integer('inflationLevels', def: 10, min: 1) ?? 10,
      powerUpInflationStep:
          tools?.integer('inflationStep', def: 5, min: 0) ?? 5,
      powerUpInflationCap: tools?.integer('inflationCap', def: 10, min: 0) ?? 10,
    );
  }

  /// Every knob left at the number this build was balanced on.
  static RewardTuning defaults() => RewardTuning.parse(
    JsonObject('_defaults', <String, dynamic>{}, ContentIssues()),
  );
}

/// Everything the shipped content set says, in one immutable bundle.
class GameContent {
  GameContent({
    required this.contentVersion,
    required this.colors,
    required this.levelsPerChapter,
    required this.chapters,
    required this.curve,
    required this.levels,
    required this.modes,
    required this.quests,
    required this.events,
    required this.achievements,
    required this.shop,
    required this.wheel,
    required this.rewards,
  });

  static const int supportedSchemaVersion = 1;

  /// Only reachable when the generator and the shipped JSON disagree, which is
  /// a build bug rather than something a player can cause. The game still
  /// opens, and [ContentRepository.source] says why the set is empty.
  factory GameContent.notLoaded() => GameContent(
    contentVersion: 'not-loaded',
    colors: const [],
    levelsPerChapter: 20,
    chapters: const [],
    curve: CurveSpec.defaults(),
    levels: const {},
    modes: const [],
    quests: const [],
    events: const [],
    achievements: const [],
    shop: const [],
    wheel: const [],
    rewards: RewardTuning.defaults(),
  );

  final String contentVersion;
  final List<LiquidColorSpec> colors;
  final int levelsPerChapter;
  final List<ChapterSpec> chapters;
  final CurveSpec curve;

  /// Authored boards, keyed by level number.
  final Map<int, LevelSpec> levels;

  /// The side modes this set gives a ladder of their own, in document order.
  final List<ModeSpec> modes;
  final List<QuestSpec> quests;
  final List<EventSpec> events;
  final List<AchievementSpec> achievements;
  final List<ShopSpec> shop;

  /// The wedges of the lucky wheel, in the order the dial paints them.
  final List<WheelSegmentSpec> wheel;
  final RewardTuning rewards;

  LevelSpec? levelFor(int level) => levels[level];

  Map<String, ModeSpec>? _modeById;

  ModeSpec? modeFor(String id) => (_modeById ??= {
    for (final mode in modes) mode.id: mode,
  })[id];

  /// How many stages [id] has. A mode the set gives no ladder to has none,
  /// which the launch contract refuses, so this only answers 0 for a bundle
  /// that never reached a player.
  int stageCountOf(String id) => modeFor(id)?.stageCount ?? 0;

  /// Which point on the difficulty curve [id]'s [stage] sits at, or null when
  /// there is no such stage.
  int? stageAnchor(String id, int stage) => modeFor(id)?.anchorFor(stage);

  Map<String, ShopSpec>? _shopByProduct;

  /// The catalogue row a store product id belongs to, so delivery reads what
  /// the listing promises instead of keeping its own list of paid items.
  ShopSpec? shopForProduct(String productId) {
    final index = _shopByProduct ??= {
      for (final item in shop)
        if (item.isIap && item.iapProductId.isNotEmpty)
          item.iapProductId: item,
    };
    return index[productId];
  }

  Set<String>? _skinIds;

  /// The glass a skin id wears, or null when this set sells no such skin. An
  /// unknown id falls back to the vector bottle rather than to art nobody
  /// rendered, which is why this answers null instead of a path.
  String? glassFor(String skinId) {
    final known = _skinIds ??= {
      for (final item in shop)
        if (item.type == 'tubeSkin') item.id,
    };
    return known.contains(skinId) ? skinGlassPath(skinId) : null;
  }

  Map<String, ShopSpec>? _themes;

  /// The room a theme id paints, or null when this set has no such theme. A save
  /// written against a theme this build does not sell reads as no theme at all,
  /// and the screen keeps its own default.
  ShopSpec? themeFor(String themeId) {
    final index = _themes ??= {
      for (final item in shop)
        if (item.type == 'theme') item.id: item,
    };
    return index[themeId];
  }

  /// The ids a deal draws its colours from, in the order the document lists.
  List<String> get paletteIds => [for (final color in colors) color.id];

  /// The palette in the order a deal draws from it.
  List<Color> get swatches => [for (final color in colors) color.swatch];

  Map<String, Color>? _byId;
  Map<int, String>? _idByArgb;
  Map<int, LiquidPattern>? _markByArgb;

  Color colorById(String id) {
    final swatch = (_byId ??= {
      for (final color in colors) color.id: color.swatch,
    })[id];
    if (swatch == null) throw StateError('Colour "$id" is not in the palette');
    return swatch;
  }

  String? idForSwatch(Color swatch) => (_idByArgb ??= {
    for (final color in colors) color.argb: color.id,
  })[swatch.toARGB32()];

  /// The mark a layer of [swatch] wears in colourblind mode. The tube painter
  /// asks for every layer on screen each frame, so the palette is indexed once
  /// rather than searched.
  LiquidPattern patternFor(Color swatch) {
    final mark = (_markByArgb ??= {
      for (final color in colors) color.argb: color.pattern,
    })[swatch.toARGB32()];
    if (mark != null) return mark;
    // A colour outside the palette - a preview, a test fixture - still gets a
    // stable mark, so the same colour never wears two shapes.
    return LiquidPattern
        .values[swatch.toARGB32() % LiquidPattern.values.length];
  }

  ChapterSpec? chapterFor(int level) {
    ChapterSpec? found;
    for (final chapter in chapters) {
      if (chapter.startsAtLevel <= level &&
          (found == null || chapter.startsAtLevel > found.startsAtLevel)) {
        found = chapter;
      }
    }
    return found;
  }

  /// The last level that belongs to [chapter] - the board that pays it out.
  int lastLevelOf(ChapterSpec chapter) =>
      chapter.startsAtLevel + levelsPerChapter - 1;

  /// The colours to deal [chapter]'s boards from: its own list when it names
  /// one, the whole palette when it does not.
  List<String> paletteFor(ChapterSpec chapter) =>
      chapter.palette.isEmpty ? paletteIds : chapter.palette;
}
