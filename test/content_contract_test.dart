/// The contract the shipped content set keeps.
///
/// This is the CI half of `validateContent`: it reads the real files off disk,
/// runs the same checks the generator runs, and adds the two things only a
/// search can prove - that every authored board is finishable, and that it is
/// finishable in the number of moves the file claims. A build that passes this
/// test cannot hand a player a board they cannot beat or a price the till does
/// not have.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:flutter_test/flutter_test.dart';

import 'package:color_puzzle_game/controllers/game_controller.dart'
    show GameController, GameMode, PowerUp;
import 'package:color_puzzle_game/content/content_documents.dart';
import 'package:color_puzzle_game/content/content_repository.dart';
import 'package:color_puzzle_game/content/content_types.dart';
import 'package:color_puzzle_game/content/content_validator.dart';
import 'package:color_puzzle_game/content/generated/compiled_content.dart';
import 'package:color_puzzle_game/game/achievements.dart';
import 'package:color_puzzle_game/game/quests.dart';
import 'package:color_puzzle_game/game/water_sort_solver.dart';

/// The set exactly as it ships, read off disk. `rootBundle` is not wired up in
/// a plain test, and disk is where the generator wrote the truth.
GameContent _shipped() {
  final issues = ContentIssues();
  final bundle = parseContentDocuments(_documentsFromDisk(), issues);
  if (bundle == null) {
    final report = issues.messages.join('\n  ');
    fail('the shipped content does not parse:\n  $report');
  }
  return bundle;
}

Map<String, Map<String, dynamic>> _documentsFromDisk() {
  final manifest = _json(kManifestPath);
  final documents = <String, Map<String, dynamic>>{kManifestPath: manifest};
  for (final path in (manifest['documents'] as List).cast<String>()) {
    documents[path] = _json(path);
  }
  return documents;
}

Map<String, dynamic> _json(String path) {
  final text = File(path).readAsStringSync();
  final value = jsonDecode(text);
  expect(value, isA<Map<String, dynamic>>(), reason: '$path is not an object');
  return value as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shipped content set', () {
    test('parses and passes every contract check', () {
      final content = _shipped();
      expect(
        validateContent(
          content,
          assetExists: (path) => File(path).existsSync(),
        ),
        isEmpty,
      );
    });

    test('every document carries the same version as the manifest', () {
      final version = _json(kManifestPath)['contentVersion'];
      for (final path in _documentsFromDisk().keys) {
        expect(
          _json(path)['contentVersion'],
          version,
          reason: '$path is out of step with the manifest',
        );
        expect(
          _json(path)['schemaVersion'],
          GameContent.supportedSchemaVersion,
        );
      }
    });

    test('is declared as an asset directory, so the bundle can serve it', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final directory in ['assets/content/', 'assets/content/levels/']) {
        expect(
          pubspec,
          contains('- $directory'),
          reason: '$directory holds content but is not in flutter: assets',
        );
      }
    });

    test('the compiled fallback is the shipped files, byte for byte', () {
      final documents = _documentsFromDisk();
      expect(kCompiledContent.keys.toList(), documents.keys.toList());
      for (final entry in kCompiledContent.entries) {
        expect(
          entry.value,
          File(entry.key).readAsStringSync(),
          reason: '${entry.key} changed without running '
              'flutter test tools/content/generate.dart',
        );
      }
    });

    test('every authored board solves, at the par it ships', () {
      final content = _shipped();
      expect(content.levels, isNotEmpty);
      for (final spec in content.levels.values) {
        final report = WaterSortSolver.solveLayers(
          spec.tubes,
          capacity: spec.capacity,
        );
        expect(
          report.outcome,
          SolveOutcome.solved,
          reason: '${spec.id} is not finishable: $report',
        );
        expect(
          report.pours,
          spec.parMoves,
          reason: '${spec.id} promises ${spec.parMoves} moves',
        );
      }
    });

    test('a chapter ships whole, in the colours it introduced', () {
      final content = _shipped();
      for (final chapter in content.chapters) {
        final block = <LevelSpec?>[
          for (
            var level = chapter.startsAtLevel;
            level <= content.lastLevelOf(chapter);
            level++
          )
            content.levels[level],
        ];
        final authored = block.whereType<LevelSpec>().length;
        // Half a chapter is the worst shape a pack can ship: the player reaches
        // a board dealt at run time and cannot tell it from an authored one,
        // and the chapter's closer may not exist at all.
        expect(
          authored,
          anyOf(0, block.length),
          reason: '${chapter.id} ships $authored of ${block.length} boards',
        );
        for (final spec in block.whereType<LevelSpec>()) {
          expect(spec.chapter, chapter.id, reason: '${spec.id} is misfiled');
          if (chapter.palette.isEmpty) continue;
          final strays = spec.colors.where(
            (color) => !chapter.palette.contains(color),
          );
          expect(
            strays,
            isEmpty,
            reason: '${spec.id} plays ${strays.toList()}, which '
                '${chapter.id} never introduces',
          );
        }
      }
    });
  });

  group('the ids the code keeps beside the data', () {
    test('power-up prices cover exactly the power-ups a player can tap', () {
      expect(kPowerUpCostKeys, PowerUp.values.map((powerUp) => powerUp.name));
      final costs = _shipped().rewards;
      for (final key in kPowerUpCostKeys) {
        expect(costs.powerUpCosts[key], greaterThan(0), reason: '$key is free');
      }
    });

    test('the side modes the code runs are the ones content gives ladders', () {
      // GameController keys a stage record by these ids and the validator
      // refuses a ladder for anything else, so the two lists drifting is not a
      // typo - it is a mode whose bests are filed under a name no save reads.
      final ladderModes = GameMode.values
          .where((mode) => mode != GameMode.classic && mode != GameMode.daily)
          .map((mode) => mode.name);
      expect(kSideModeIds, ladderModes);

      final content = _shipped();
      for (final id in kSideModeIds) {
        final ladder = content.modeFor(id);
        expect(ladder, isNotNull, reason: '$id has no ladder to play');
        expect(
          content.stageCountOf(id),
          greaterThanOrEqualTo(kSideLadderMinStages),
          reason: '$id is too short to be a map',
        );
        // The map needs a first stage and the win card needs to know when the
        // ladder stops, so the range has to be exactly 1 through the last.
        expect(content.stageAnchor(id, 1), isNotNull);
        expect(
          content.stageAnchor(id, content.stageCountOf(id)),
          isNotNull,
          reason: '$id ends on a stage that deals no board',
        );
        expect(content.stageAnchor(id, content.stageCountOf(id) + 1), isNull);
      }
    });

    test('the ceiling that keeps a Challenge stage winnable is one number', () {
      // Challenge sets its move limit from the shortest solution a search
      // proved. Beyond the distance a search can actually conclude the limit
      // would be measured against an estimate, which is a board the player can
      // lose without doing anything wrong - and the two constants live in
      // different files, so only a test keeps them the same number.
      expect(kSideLadderColorCeiling, GameController.searchableColorCount);

      final content = _shipped();
      final challenge = content.modeFor('challenge')!;
      for (var stage = 1; stage <= challenge.stageCount; stage++) {
        final anchor = challenge.stages[stage - 1];
        final shape = content.curve.configFor(anchor);
        expect(
          shape.colorCount,
          lessThanOrEqualTo(GameController.searchableColorCount),
          reason: 'challenge stage $stage sits at curve level $anchor, which '
              'deals ${shape.colorCount} colours - past what a search can '
              'prove a par for',
        );
      }
    });

    test('every paid row says what the till hands out', () {
      final content = _shipped();
      final paid = [for (final item in content.shop) if (item.isIap) item];
      expect(paid, isNotEmpty);
      for (final item in paid) {
        // Delivery reads the catalogue, so a row with no grant is a listing that
        // takes money and leaves the wallet exactly as it was.
        expect(
          item.grantCoins > 0 || item.isEntitlement,
          isTrue,
          reason: '${item.id} is on sale and delivers nothing',
        );
        expect(
          content.shopForProduct(item.iapProductId),
          same(item),
          reason: '${item.iapProductId} is not findable by the purchase '
              'listener that has to fulfil it',
        );
      }
      for (final item in content.shop.where((item) => item.isEntitlement)) {
        expect(item.entitlement, ShopSpec.kRemoveAds);
      }
      // The ad-free switch is the one entitlement the app keeps, and the shop
      // still sells it.
      expect(
        paid.where((item) => item.isEntitlement).map((item) => item.id),
        contains('remove_ads'),
      );
    });

    test('a board with more bottles than the layout holds is refused', () {
      final ceiling = _shipped().curve.maxBoardTubes;
      final documents = _documentsFromDisk();
      final levels =
          documents['assets/content/levels/pack_001.json']!['levels'] as List;
      final board = Map<String, dynamic>.from(levels.first as Map);
      // Empty bottles only, so nothing but the count is wrong: the colours still
      // add up, a spare bottle is still there, the shipped par still solves it.
      final bottles = List<dynamic>.from(board['tubes'] as List);
      board['tubes'] = [
        ...bottles,
        for (var count = bottles.length; count <= ceiling; count++)
          <String>[],
      ];
      levels[0] = board;

      final oversized = parseContentDocuments(documents, ContentIssues())!;
      expect(
        validateContent(oversized).join('\n'),
        allOf(
          contains('l001_pack_001'),
          contains('the board lays out at most'),
        ),
        reason: 'a ${ceiling + 1}-bottle board has to be caught before a '
            'player opens it',
      );
    });

    test('art a document names that the build does not ship is refused', () {
      // The same check the repository runs at launch against the real asset
      // bundle, run here against a bundle that ships nothing.
      final problems = validateContent(
        _shipped(),
        assetExists: (_) => false,
      ).join('\n');

      expect(problems, contains('does not exist'));
      expect(problems, contains('no such skin image'));
    });

    test('a chapter cannot name colours it cannot use', () {
      final documents = _documentsFromDisk();
      final chapters =
          documents['assets/content/chapters.json']!['chapters'] as List;
      final opener = Map<String, dynamic>.from(chapters.first as Map);
      // Too few to fill the chapter's widest board, one id the palette does not
      // carry, and one listed twice.
      opener['palette'] = ['red', 'blur', 'red'];
      chapters[0] = opener;

      final narrowed = parseContentDocuments(documents, ContentIssues())!;
      expect(
        validateContent(narrowed).join('\n'),
        allOf(
          contains('first_pours.palette'),
          contains('blur is not in the palette'),
          contains('lists the same colour twice'),
          contains('L20 asks for 6'),
        ),
        reason: 'a chapter that cannot fill its own widest board is one the '
            'generator cannot author',
      );
    });

    test('achievement goals count what the screens read', () {
      // The list of counters lives in one place and both ends have to agree:
      // a goal naming a stat nothing reads would show a bar stuck at zero, and
      // a counter the game keeps with no goal on it is a number nobody wrote
      // the copy for.
      final shippedStats = <String>{};
      for (final achievement in _shipped().achievements) {
        expect(
          AchievementStat.known,
          contains(achievement.stat),
          reason: '${achievement.id} counts something nothing reads',
        );
        shippedStats.add(achievement.stat);
      }
      expect(
        shippedStats,
        hasLength(AchievementStat.values.length),
        reason: 'every counter the game keeps should have a goal on it',
      );
    });
  });

  group('the daily draw', () {
    test('cuts a short slate out of the whole catalogue', () {
      expect(QuestCatalog.all.length, greaterThan(kDailyQuestCount));
      expect(QuestCatalog.forDay('2026-10-01'), hasLength(kDailyQuestCount));
    });

    test('gives the same day the same slate', () {
      // A player who restarts the app must not be able to reroll a task they
      // have already finished, and two devices must not disagree about what
      // "today" asks for.
      expect(
        QuestCatalog.forDay('2026-10-01').map((quest) => quest.id).toList(),
        orderedEquals(
          QuestCatalog.forDay('2026-10-01').map((quest) => quest.id).toList(),
        ),
      );
    });

    test('keeps every slate varied', () {
      for (var day = 1; day <= 28; day++) {
        final slate = QuestCatalog.forDay('2026-10-$day');
        final perStat = <String, int>{};
        for (final quest in slate) {
          perStat[quest.stat] = (perStat[quest.stat] ?? 0) + 1;
        }
        expect(
          perStat.values.reduce(max),
          lessThanOrEqualTo(kDailyQuestsPerStat),
          reason: '2026-10-$day asks for the same thing too often',
        );
      }
    });

    test('actually moves between days', () {
      // A fixed slate would be a shorter list; the draw only earns its keep if
      // tomorrow is not today.
      final today = QuestCatalog.forDay('2026-10-01').map((q) => q.id).toSet();
      final tomorrow = QuestCatalog.forDay('2026-10-02').map((q) => q.id).toSet();
      expect(today.intersection(tomorrow), hasLength(lessThan(kDailyQuestCount)));
    });
  });

  group('the repository', () {
    test('serves the compiled copy before anything is read', () {
      expect(ContentRepository.content.contentVersion, isNot('not-loaded'));
      expect(ContentRepository.source.isCompiledFallback, isTrue);
      expect(ContentRepository.source.issues, isEmpty);
    });

    test('refuses a set that breaks the contract and keeps the good one', () {
      final before = ContentRepository.content;
      final broken = _documentsFromDisk();
      broken['assets/content/rewards.json']!['powerUps'] = 'not an object';
      ContentRepository.adopt(broken, fromBundle: true);

      expect(ContentRepository.content, same(before));
      expect(ContentRepository.source.issues, isNotEmpty);

      ContentRepository.adopt(_documentsFromDisk(), fromBundle: true);
      expect(ContentRepository.source.issues, isEmpty);
      expect(ContentRepository.source.isCompiledFallback, isFalse);
    });

    // The launch check can only refuse missing art if the manifest it reads
    // really knows what this build packed.
    test('the manifest the launch check reads lists the packed content', () async {
      final packed = await ContentRepository.packedAssets();
      expect(
        packed,
        isNotNull,
        reason: 'the asset manifest was unreadable, so a document naming art '
            'nobody packed would slip past the launch check',
      );
      expect(packed!('assets/content/levels/pack_001.json'), isTrue);
      expect(packed('assets/content/not_a_real_file.json'), isFalse);
      for (final event in ContentRepository.content.events) {
        expect(packed(event.bannerImage), isTrue, reason: event.id);
      }
      for (final skin in ContentRepository.content.shop.where(
        (item) => item.type == 'tubeSkin',
      )) {
        expect(packed(skin.heroImage), isTrue, reason: skin.id);
      }
    });

    test('a set naming art the build does not have is refused too', () {
      final before = ContentRepository.content;
      ContentRepository.adopt(
        _documentsFromDisk(),
        fromBundle: true,
        assetExists: (_) => false,
      );

      expect(ContentRepository.content, same(before));
      expect(ContentRepository.source.issues, isNotEmpty);

      ContentRepository.adopt(_documentsFromDisk(), fromBundle: true);
      expect(ContentRepository.source.issues, isEmpty);
    });

    test('a bundle read that throws leaves the set already serving', () async {
      final before = ContentRepository.content;
      await ContentRepository.refresh(
        read: (path) async => throw StateError('no bundle on this device'),
      );
      expect(ContentRepository.content, same(before));
      expect(ContentRepository.source.isCompiledFallback, isTrue);
    });

    // The same read the app performs at launch, against the asset bundle the
    // build produces. A document that is not declared in `pubspec.yaml` cannot
    // be found here, which is exactly the mistake this catches.
    test('the shipped asset bundle carries every document', () async {
      await ContentRepository.refresh();
      expect(ContentRepository.source.isCompiledFallback, isFalse);
      expect(ContentRepository.source.issues, isEmpty);
      expect(ContentRepository.content.levels, isNotEmpty);
    });
  });
}
