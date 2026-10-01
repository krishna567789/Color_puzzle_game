/// The layout of the content set: which documents exist, what each one holds,
/// and the envelope every one of them has to carry.
library;

import 'content_types.dart';

/// Asset path of the document that lists the others.
const String kManifestPath = 'assets/content/manifest.json';

/// The two fields every document repeats, so a file can never be mistaken for a
/// different schema's output no matter which folder it lands in.
const List<String> kEnvelopeFields = ['schemaVersion', 'contentVersion'];

enum _DocKind {
  colors('assets/content/colors.json'),
  chapters('assets/content/chapters.json'),
  curve('assets/content/levels/curve.json'),
  levelPack(''),
  modes('assets/content/modes.json'),
  quests('assets/content/quests.json'),
  events('assets/content/events.json'),
  achievements('assets/content/achievements.json'),
  shop('assets/content/shop.json'),
  wheel('assets/content/wheel.json'),
  rewards('assets/content/rewards.json'),
  unknown('');

  const _DocKind(this.path);

  final String path;

  static _DocKind of(String path) {
    for (final kind in values) {
      if (kind.path == path && kind != _DocKind.unknown) return kind;
    }
    if (path.startsWith('assets/content/levels/')) return _DocKind.levelPack;
    return _DocKind.unknown;
  }
}

/// Decodes the whole content set. Returns null when anything failed, so the
/// caller keeps the bundle it already trusts instead of a half-applied one.
GameContent? parseContentDocuments(
  Map<String, Map<String, dynamic>> documents,
  ContentIssues issues,
) {
  final manifestRaw = documents[kManifestPath];
  if (manifestRaw == null) {
    issues.add(kManifestPath, 'missing');
    return null;
  }
  final manifest = JsonObject(kManifestPath, manifestRaw, issues);
  if (manifest.integer('schemaVersion') !=
      GameContent.supportedSchemaVersion) {
    issues.add(
      '$kManifestPath.schemaVersion',
      'this build speaks schema ${GameContent.supportedSchemaVersion}',
    );
    return null;
  }
  final version = manifest.string('contentVersion') ?? '';
  final listed = manifest.strings('documents');
  manifest.rejectUnknownKeys([...kEnvelopeFields, 'documents']);
  for (final path in listed) {
    if (!documents.containsKey(path)) {
      issues.add('$kManifestPath.documents', '$path is listed but absent');
    }
  }
  for (final path in documents.keys) {
    if (path != kManifestPath && !listed.contains(path)) {
      issues.add(path, 'present but the manifest does not list it');
    }
  }

  final colors = <LiquidColorSpec>[];
  final chapters = <ChapterSpec>[];
  final levels = <int, LevelSpec>{};
  final modes = <ModeSpec>[];
  final quests = <QuestSpec>[];
  final events = <EventSpec>[];
  final achievements = <AchievementSpec>[];
  final shop = <ShopSpec>[];
  final wheel = <WheelSegmentSpec>[];
  CurveSpec? curve;
  RewardTuning? rewards;
  int? levelsPerChapter;

  for (final entry in documents.entries) {
    final path = entry.key;
    if (path == kManifestPath) continue;
    final json = _open(path, entry.value, issues, version);
    if (json == null) continue;
    switch (_DocKind.of(path)) {
      case _DocKind.colors:
        json.rejectUnknownKeys([...kEnvelopeFields, 'colors']);
        for (final item in json.objects('colors')) {
          item.rejectUnknownKeys(LiquidColorSpec.fields);
          colors.add(LiquidColorSpec.parse(item));
        }
      case _DocKind.chapters:
        levelsPerChapter = json.integer('levelsPerChapter', min: 1);
        json.rejectUnknownKeys([
          ...kEnvelopeFields,
          'levelsPerChapter',
          'chapters',
        ]);
        for (final item in json.objects('chapters')) {
          item.rejectUnknownKeys(ChapterSpec.fields);
          chapters.add(ChapterSpec.parse(item));
        }
      case _DocKind.curve:
        json.rejectUnknownKeys([...kEnvelopeFields, ...CurveSpec.fields]);
        curve = CurveSpec.parse(json);
      case _DocKind.levelPack:
        json.rejectUnknownKeys([...kEnvelopeFields, 'packId', 'levels']);
        for (final item in json.objects('levels')) {
          item.rejectUnknownKeys(LevelSpec.fields);
          final spec = LevelSpec.parse(item);
          final clash = levels[spec.level];
          if (clash != null) {
            issues.add(
              '${item.path}.level',
              'level ${spec.level} is already defined by ${clash.id}',
            );
            continue;
          }
          levels[spec.level] = spec;
        }
      case _DocKind.modes:
        json.rejectUnknownKeys([...kEnvelopeFields, 'modes']);
        for (final item in json.objects('modes')) {
          item.rejectUnknownKeys(ModeSpec.fields);
          modes.add(ModeSpec.parse(item));
        }
      case _DocKind.quests:
        json.rejectUnknownKeys([...kEnvelopeFields, 'daily']);
        for (final item in json.objects('daily')) {
          item.rejectUnknownKeys(QuestSpec.fields);
          quests.add(QuestSpec.parse(item));
        }
      case _DocKind.events:
        json.rejectUnknownKeys([...kEnvelopeFields, 'events']);
        for (final item in json.objects('events')) {
          item.rejectUnknownKeys(EventSpec.fields);
          events.add(EventSpec.parse(item));
        }
      case _DocKind.achievements:
        json.rejectUnknownKeys([...kEnvelopeFields, 'achievements']);
        for (final item in json.objects('achievements')) {
          item.rejectUnknownKeys(AchievementSpec.fields);
          achievements.add(AchievementSpec.parse(item));
        }
      case _DocKind.shop:
        json.rejectUnknownKeys([...kEnvelopeFields, 'items']);
        for (final item in json.objects('items')) {
          item.rejectUnknownKeys(ShopSpec.fields);
          shop.add(ShopSpec.parse(item));
        }
      case _DocKind.wheel:
        json.rejectUnknownKeys([...kEnvelopeFields, 'segments']);
        for (final item in json.objects('segments')) {
          item.rejectUnknownKeys(WheelSegmentSpec.fields);
          wheel.add(WheelSegmentSpec.parse(item));
        }
      case _DocKind.rewards:
        json.rejectUnknownKeys([
          ...kEnvelopeFields,
          'levels',
          'player',
          'streak',
          'spin',
          'powerUps',
        ]);
        rewards = RewardTuning.parse(json);
      case _DocKind.unknown:
        issues.add(path, 'no reader knows this document');
    }
  }

  if (curve == null) {
    issues.add(_DocKind.curve.path, 'missing');
  }
  if (rewards == null) {
    issues.add(_DocKind.rewards.path, 'missing');
  }
  if (levelsPerChapter == null) {
    issues.add('${_DocKind.chapters.path}.levelsPerChapter', 'required');
  }
  if (issues.hasErrors) return null;

  colors.sort((a, b) => a.id.compareTo(b.id));
  chapters.sort((a, b) => a.startsAtLevel.compareTo(b.startsAtLevel));
  return GameContent(
    contentVersion: version,
    colors: colors,
    levelsPerChapter: levelsPerChapter ?? 20,
    chapters: chapters,
    curve: curve ?? CurveSpec.parse(JsonObject('_', {}, ContentIssues())),
    levels: levels,
    modes: modes,
    quests: quests,
    events: events,
    achievements: achievements,
    shop: shop,
    wheel: wheel,
    rewards: rewards ??
        RewardTuning.parse(JsonObject('_', {}, ContentIssues())),
  );
}

/// Checks one document's envelope and hands back its body.
JsonObject? _open(
  String path,
  Map<String, dynamic> raw,
  ContentIssues issues,
  String version,
) {
  final json = JsonObject(path, raw, issues);
  final schema = json.integer('schemaVersion');
  if (schema != GameContent.supportedSchemaVersion) {
    issues.add(
      '$path.schemaVersion',
      'this build speaks schema ${GameContent.supportedSchemaVersion}',
    );
    return null;
  }
  final contentVersion = json.string('contentVersion');
  if (contentVersion == null) return null;
  if (contentVersion != version) {
    issues.add(
      '$path.contentVersion',
      'says $contentVersion while the manifest says $version',
    );
    return null;
  }
  return json;
}
