/// Regenerates the shipped content: the authored level packs, and the copy of
/// the whole set that is compiled into the binary.
///
/// This is the only thing allowed to write a board into `assets/content`, and it
/// writes it through the same dealer and solver the game runs, so every authored
/// level is winnable by construction and carries a proved `parMoves` rather than
/// an estimate. The Dart file it emits holds the JSON bytes verbatim, so the
/// compiled-in fallback is the shipped content and the two cannot drift.
///
///   flutter test tools/content/generate.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:color_puzzle_game/content/content_documents.dart';
import 'package:color_puzzle_game/content/content_types.dart';
import 'package:color_puzzle_game/content/content_validator.dart';
import 'package:color_puzzle_game/game/level_dealer.dart';
import 'package:color_puzzle_game/game/water_sort_solver.dart';

/// How many chapters this tool writes boards for, counted from the top of
/// `chapters.json`. Everything above this number is dealt procedurally at run
/// time. Raising it by one adds a pack, one manifest line and twenty boards.
const int _authoredChapters = 5;

/// How many deals one level may try before the tool gives up. A deal is
/// winnable by construction, so a run of inconclusive searches means the curve
/// has outrun the search, and the fix belongs in `levels/curve.json` rather
/// than in a bigger number here.
const int _dealsPerLevel = 8;

/// How many proved boards to collect for the two levels worth choosing between.
const int _candidatesToKeep = 4;

const String _compiledPath = 'lib/content/generated/compiled_content.dart';

/// Which board a level takes out of the ones it proved.
enum _Pick {
  /// The first deal the solver could finish, which is what a level in the middle
  /// of a chapter wants: no taste to satisfy, only a board that plays.
  first,

  /// The shortest proved solution, for the board that decides whether a player
  /// believes the chapter is on their side.
  plainest,

  /// The longest proved solution, for the board that ends a chapter.
  deepest,
}

void main() {
  test(
    'author the packs, then compile the content set',
    () {
    // The set without the packs this tool owns, because they are what is about
    // to be written.
    final owned = {
      for (var index = 0; index < _authoredChapters; index++) _packPath(index),
    };
    final base = _load([
      kManifestPath,
      ..._listedDocuments().where((path) => !owned.contains(path)),
    ]);

    final chapters = base.chapters.take(_authoredChapters).toList();
    if (chapters.length < _authoredChapters) {
      fail(
        'chapters.json has ${chapters.length} chapters and this tool writes '
        'boards for $_authoredChapters',
      );
    }

    final authored = <LevelSpec>[];
    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      final levels = _authorPack(base, chapter, _packId(index));
      File(_packPath(index)).writeAsStringSync(
        _packDocument(base, _packId(index), levels),
      );
      authored.addAll(levels);
      stdout.writeln(
        '${_packId(index)} ${chapter.id}: ${levels.length} levels, par '
        '${levels.map((level) => level.parMoves).join(' ')}',
      );
    }

    final paths = [kManifestPath, ..._listedDocuments()];
    final shipped = _load(paths);
    if (shipped.levels.length != authored.length) {
      fail(
        'the set read back from disk has ${shipped.levels.length} levels, '
        'the generator authored ${authored.length}',
      );
    }

    _compile(paths);
    stdout.writeln(
      '${authored.length} authored boards across '
      '${chapters.length} chapters',
    );
  },
  // A hundred boards through the solver, which is a real run rather than a
  // unit test. The default budget is for the latter.
  timeout: const Timeout(Duration(minutes: 4)));
}

/// The pack a chapter's boards live in. One pack per chapter keeps a chapter's
/// boards diffable as one unit, and the parser already treats every file under
/// `levels/` as another pack to merge.
String _packId(int chapterIndex) =>
    'pack_${(chapterIndex + 1).toString().padLeft(3, '0')}';

String _packPath(int chapterIndex) =>
    'assets/content/levels/${_packId(chapterIndex)}.json';

/// The document paths the manifest lists, in the order it lists them.
List<String> _listedDocuments() {
  final manifest = jsonDecode(File(kManifestPath).readAsStringSync());
  if (manifest is! Map<String, dynamic>) {
    fail('$kManifestPath is not an object');
  }
  final documents = manifest['documents'];
  if (documents is! List) fail('$kManifestPath has no documents list');
  return [for (final path in documents) '$path'];
}

/// Reads and checks the documents at [paths]. Every authored field is validated
/// here before anything is written, so the generator cannot be the thing that
/// ships a broken set.
GameContent _load(List<String> paths) {
  final documents = <String, Map<String, dynamic>>{};
  for (final path in paths) {
    final value = jsonDecode(_read(path));
    documents[path] = value is Map<String, dynamic>
        ? value
        : fail('$path is not a JSON object');
  }
  final manifest = documents[kManifestPath];
  if (manifest != null) {
    // The set is exactly the files handed in. A pack that has not been written
    // yet is the generator's own business, not a missing document.
    manifest['documents'] = [
      for (final path in paths)
        if (path != kManifestPath) path,
    ];
  }

  final issues = ContentIssues();
  final bundle = parseContentDocuments(documents, issues);
  if (bundle == null) {
    fail('the content set does not parse:\n  ${issues.messages.join('\n  ')}');
  }
  final problems = validateContent(
    bundle,
    assetExists: (path) => File(path).existsSync(),
  );
  if (problems.isNotEmpty) {
    fail('the content set is not valid:\n  ${problems.join('\n  ')}');
  }
  return bundle;
}

/// One chapter's boards. The opener is the plainest thing the dealer offered for
/// that shape and the closer the deepest, because a chapter is judged by how it
/// starts and how it ends; the levels between them take the first proved deal.
///
/// A board is dealt, not drawn: at twelve colours over fourteen bottles there is
/// no hand to place, and a hand-drawn board that the solver refuses is worse for
/// the player than a dealt one the solver proved. What is chosen by hand here is
/// which of the proved deals opens and which closes.
List<LevelSpec> _authorPack(
  GameContent content,
  ChapterSpec chapter,
  String packId,
) {
  final first = chapter.startsAtLevel;
  final last = content.lastLevelOf(chapter);
  final levels = <LevelSpec>[];
  for (var level = first; level <= last; level++) {
    final pick = level == first
        ? _Pick.plainest
        : level == last
        ? _Pick.deepest
        : _Pick.first;
    levels.add(_author(content, chapter, packId, level, pick: pick));
  }
  return levels;
}

/// Deals boards for [level], keeps the ones the search finishes, and hands back
/// the one [pick] asks for with the move count the search proved.
LevelSpec _author(
  GameContent content,
  ChapterSpec chapter,
  String packId,
  int level, {
  required _Pick pick,
}) {
  final spec = content.curve.configFor(level);
  final wanted = pick == _Pick.first ? 1 : _candidatesToKeep;
  final candidates = <LevelSpec>[];

  for (
    var attempt = 0;
    attempt < _dealsPerLevel && candidates.length < wanted;
    attempt++
  ) {
    final dealt = LevelDealer.deal(
      spec: spec,
      palette: content.paletteFor(chapter),
      random: Random(level * 7919 + attempt),
    );
    final report = WaterSortSolver.solveLayers(
      dealt.tubes,
      capacity: spec.capacity,
    );
    if (report.outcome != SolveOutcome.solved) continue;
    if (!LevelDealer.dealsWholeSegments(dealt, spec)) {
      fail('L$level was dealt with a colour in pieces');
    }
    candidates.add(
      LevelSpec(
        id: 'l${level.toString().padLeft(3, '0')}_$packId',
        level: level,
        chapter: chapter.id,
        capacity: spec.capacity,
        colors: dealt.colors,
        tubes: dealt.tubes,
        hidden: dealt.hidden,
        parMoves: report.pours!,
      ),
    );
  }

  if (candidates.isEmpty) {
    fail(
      'L$level never produced a board the solver could finish within '
      '${WaterSortSolver.defaultNodeBudget} states. Ease the curve for it, or '
      'let it be dealt procedurally at run time.',
    );
  }
  return switch (pick) {
    _Pick.plainest => candidates.reduce(
      (a, b) => b.parMoves < a.parMoves ? b : a,
    ),
    _Pick.deepest => candidates.reduce(
      (a, b) => b.parMoves > a.parMoves ? b : a,
    ),
    _Pick.first => candidates.first,
  };
}

/// One level per line-group, with each bottle on its own line: a pack is read
/// and diffed by people, and a board is one line per tube either way.
String _packDocument(
  GameContent content,
  String packId,
  List<LevelSpec> levels,
) {
  final lines = <String>[
    '{',
    '  "schemaVersion": ${GameContent.supportedSchemaVersion},',
    '  "contentVersion": ${jsonEncode(content.contentVersion)},',
    '  "packId": ${jsonEncode(packId)},',
    '  "levels": [',
  ];

  for (var i = 0; i < levels.length; i++) {
    final level = levels[i];
    lines.addAll([
      '    {',
      '      "id": ${jsonEncode(level.id)},',
      '      "level": ${level.level},',
      '      "chapter": ${jsonEncode(level.chapter)},',
      '      "capacity": ${level.capacity},',
      '      "colors": ${_row(level.colors)},',
      '      "tubes": [',
    ]);
    for (var tube = 0; tube < level.tubes.length; tube++) {
      lines.add(
        '        ${_row(level.tubes[tube])}'
        '${tube == level.tubes.length - 1 ? '' : ','}',
      );
    }
    lines.addAll([
      '      ],',
      '      "hidden": ${_row(level.hidden)},',
      '      "parMoves": ${level.parMoves}',
      '    }${i == levels.length - 1 ? '' : ','}',
    ]);
  }

  lines.addAll(['  ]', '}']);
  return '${lines.join('\n')}\n';
}

String _row(List<Object> values) => '[${values.map(jsonEncode).join(', ')}]';

/// Writes the whole content set into Dart, as the exact bytes on disk.
void _compile(List<String> paths) {
  final entries = <String>[];
  for (final path in paths) {
    final text = _read(path);
    if (text.contains("'''")) {
      fail('$path cannot be compiled in: it holds a triple quote');
    }
    entries.add('  ${jsonEncode(path)}: r${_quote(text)},');
  }

  Directory('lib/content/generated').createSync(recursive: true);
  File(_compiledPath).writeAsStringSync(
    '/// Generated by `flutter test tools/content/generate.dart`. Do not edit.\n'
    '///\n'
    '/// The shipped content set, byte for byte, compiled into the binary so a\n'
    '/// build whose asset bundle cannot be read still plays the same game. Edit\n'
    '/// the JSON and regenerate; changing this file only makes the two disagree.\n'
    'const Map<String, String> kCompiledContent = {\n'
    '${entries.join('\n')}\n'
    '};\n',
  );
  stdout.writeln('$_compiledPath: ${paths.length} documents');
}

/// A raw triple-quoted literal, so a `$` in the data stays a `$`.
String _quote(String text) => "'''$text'''";

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('$path is missing');
  return file.readAsStringSync();
}
