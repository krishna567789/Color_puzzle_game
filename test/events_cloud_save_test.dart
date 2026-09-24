import 'dart:io';

import 'package:color_puzzle_game/core/cloud_save_service.dart';
import 'package:color_puzzle_game/core/event_service.dart';
import 'package:color_puzzle_game/core/progress_service.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:color_puzzle_game/game/events.dart';
import 'package:color_puzzle_game/game/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  setUp(() async => StorageService.resetAllSettings());

  group('calendar', () {
    test(
      'something is always live, and a live window always contains today',
      () {
        // A year of middling days: enough to cross every cycle boundary.
        for (var day = 0; day < 370; day++) {
          final now = DateTime(2026, 1, 4).add(Duration(days: day));
          final open = EventCatalog.all.where((t) => t.windowAt(now).isOpen);
          expect(open, isNotEmpty, reason: 'nothing to play on $now');
          for (final template in EventCatalog.all) {
            final window = template.windowAt(now);
            expect(
              window.end.difference(window.start),
              template.openFor,
              reason: '${template.id} window length drifts',
            );
            if (window.isOpen) {
              expect(now.isBefore(window.start), isFalse);
              expect(now.isBefore(window.end), isTrue);
            } else {
              expect(
                window.start.isAfter(now),
                isTrue,
                reason: '${template.id} previews a window that already began',
              );
            }
          }
        }
      },
    );

    test('a season repeats itself instead of expiring', () {
      final season = EventCatalog.byId('season')!;
      final first = season.windowAt(DateTime(2026, 1, 20));
      expect(first.isOpen, isTrue);
      expect(first.start, DateTime(2026, 1, 1));

      // The very next day the second run owns the calendar.
      final second = season.windowAt(DateTime(2026, 1, 29));
      expect(second.isOpen, isTrue);
      expect(second.start, DateTime(2026, 1, 29));
    });

    test(
      'the weekend run is open Saturday to Monday and previews next week',
      () {
        final weekend = EventCatalog.byId('weekend')!;
        final monday = weekend.windowAt(DateTime(2026, 1, 5, 12));
        expect(monday.isOpen, isTrue);
        expect(monday.start, DateTime(2026, 1, 3));

        final wednesday = weekend.windowAt(DateTime(2026, 1, 7, 12));
        expect(wednesday.isOpen, isFalse);
        expect(wednesday.start, DateTime(2026, 1, 10));
      },
    );
  });

  group('live progress', () {
    test('a win feeds every open event and nothing else', () async {
      final monday = DateTime(2026, 1, 5, 12);
      await EventService.recordWin(stars: 3, now: monday);

      final byId = {
        for (final e in await EventService.schedule(now: monday)) e.id: e,
      };
      expect(byId['season']!.currentProgress, 1);
      expect(byId['star_hunt']!.currentProgress, 3);
      expect(byId['weekend']!.currentProgress, 1);
      expect(byId['weekend']!.isOpen, isTrue);

      // Wednesday: the weekend run is closed, so its counter stays where it was
      // while the two long runs keep taking wins.
      await EventService.recordWin(stars: 2, now: DateTime(2026, 1, 7, 12));
      final later = {
        for (final e in await EventService.schedule(
          now: DateTime(2026, 1, 7, 12),
        ))
          e.id: e,
      };
      expect(later['season']!.currentProgress, 2);
      expect(later['star_hunt']!.currentProgress, 5);
      expect(later['weekend']!.currentProgress, 0);
      expect(later['weekend']!.isOpen, isFalse);
    });

    test(
      'a rollover starts a fresh counter instead of inheriting one',
      () async {
        await EventService.recordWin(stars: 1, now: DateTime(2026, 1, 20));
        expect(
          (await EventService.schedule(
            now: DateTime(2026, 1, 20),
          )).firstWhere((e) => e.id == 'season').currentProgress,
          1,
        );

        // Run two opens on the 29th and knows nothing about run one.
        final next = await EventService.schedule(now: DateTime(2026, 1, 29));
        expect(
          next.firstWhere((e) => e.id == 'season').currentProgress,
          0,
          reason: 'the new season must start empty',
        );
      },
    );

    test('an event pays once, and only when its own run is finished', () async {
      final monday = DateTime(2026, 1, 5, 12);
      final weekend = EventCatalog.byId('weekend')!;

      await EventService.recordWin(stars: 1, now: monday);
      var card = (await EventService.schedule(
        now: monday,
      )).firstWhere((e) => e.id == weekend.id);
      expect(await EventService.claim(card.id, now: monday), isNull);

      for (var i = 0; i < weekend.goal - 1; i++) {
        await EventService.recordWin(stars: 1, now: monday);
      }
      card = (await EventService.schedule(
        now: monday,
      )).firstWhere((e) => e.id == weekend.id);
      expect(card.canClaim, isTrue);

      // A screen left open across the rollover still shows Monday's finished
      // card, but claiming it now belongs to a run with no progress at all.
      expect(
        await EventService.claim(card.id, now: DateTime(2026, 1, 7, 12)),
        isNull,
      );

      final coinsBefore = await StorageService.getCoins();
      final gemsBefore = await StorageService.getGems();
      final paid = await EventService.claim(card.id, now: monday);
      expect(paid, isNotNull);
      expect(
        await StorageService.getCoins(),
        coinsBefore + weekend.rewardCoins,
      );
      expect(await StorageService.getGems(), gemsBefore + weekend.rewardGems);

      expect(
        await EventService.claim(card.id, now: monday),
        isNull,
        reason: 'no second payout',
      );
      expect(
        await StorageService.getCoins(),
        coinsBefore + weekend.rewardCoins,
      );

      // The card now reads claimed, and its coin figure went stale the moment
      // the run was paid out, so the screen has to reload it.
      final after = await EventService.schedule(now: monday);
      final settled = after.firstWhere((e) => e.id == weekend.id);
      expect(settled.isClaimed, isTrue);
      expect(settled.canClaim, isFalse);
      expect(after.first.canClaim, isFalse);
    });
  });

  group('cloud save', () {
    test('a round trip keeps every number that matters', () {
      final save = CloudSave(
        savedAt: DateTime(2026, 9, 24, 10, 30),
        level: 42,
        coins: 1780,
        gems: 12,
        totalLevelsWon: 96,
        playerXp: 1240,
        levelStars: {1: 3, 41: 2, 42: 3},
      );
      final read = CloudSave.decode(save.encode())!;
      expect(read.level, 42);
      expect(read.coins, 1780);
      expect(read.gems, 12);
      expect(read.totalLevelsWon, 96);
      expect(read.playerXp, 1240);
      expect(read.levelStars, {1: 3, 41: 2, 42: 3});
      expect(read.savedAt, save.savedAt);
    });

    test('anything that is not a save this build understands is ignored', () {
      // What earlier versions wrote. Restoring from it must be a no-op rather
      // than a half-read account.
      expect(CloudSave.decode('level:12,coins:340,gems:3'), isNull);
      expect(CloudSave.decode(null), isNull);
      expect(CloudSave.decode(''), isNull);
      expect(
        CloudSave.decode('{"v":99,"savedAt":"2026-01-01T00:00:00.000Z"}'),
        isNull,
      );
      expect(CloudSave.decode('{"savedAt":"nonsense","level":3}'), isNull);
    });

    test('a version 1 save still restores, without XP', () {
      // Written by the build before player levels existed. Everything it does
      // carry has to come back; the XP it never had reads as zero.
      final read = CloudSave.decode(
        '{"v":1,"savedAt":"2026-01-01T00:00:00.000Z","level":8,'
        '"coins":300,"gems":2,"wins":11,"stars":{"7":3}}',
      );
      expect(read, isNotNull);
      expect(read!.level, 8);
      expect(read.totalLevelsWon, 11);
      expect(read.levelStars, {7: 3});
      expect(read.playerXp, 0);
    });

    test('a merge can only give progress back', () async {
      await StorageService.saveLevel(10);
      await StorageService.saveCoins(500);
      await StorageService.saveGems(4);
      await StorageService.saveLevelStars(7, 3);
      await StorageService.addPlayerXp(900);
      // This device pushed after the copy below was written, so its purse is
      // the newer one and must survive.
      await StorageService.setCloudUploadedAt(DateTime(2026, 6, 1));

      await CloudSaveService.merge(
        CloudSave(
          savedAt: DateTime(2026, 1, 1),
          level: 4,
          coins: 9000,
          gems: 40,
          totalLevelsWon: 250,
          playerXp: 400,
          levelStars: {7: 1, 8: 2},
        ),
      );

      expect(await StorageService.getCoins(), 500);
      expect(await StorageService.getGems(), 4);
      // A level and a star rating from elsewhere are both kept.
      expect(await StorageService.getLevel(), 10);
      expect(await StorageService.getLevelStars(7), 3);
      expect(await StorageService.getLevelStars(8), 2);
      expect(await StorageService.getTotalLevelsWon(), 250);
      expect(
        await StorageService.getPlayerXp(),
        900,
        reason: 'a second phone cannot take earned XP away',
      );
    });

    test('the newest copy wins the wallet', () async {
      await StorageService.saveLevel(30);
      await StorageService.saveCoins(500);
      await StorageService.saveGems(4);
      await StorageService.addPlayerXp(120);
      await StorageService.setCloudUploadedAt(DateTime(2026, 1, 1));

      await CloudSaveService.merge(
        CloudSave(
          savedAt: DateTime(2026, 3, 1),
          level: 1,
          coins: 9000,
          gems: 40,
          totalLevelsWon: 0,
          playerXp: 5000,
          levelStars: {},
        ),
      );

      expect(await StorageService.getCoins(), 9000);
      expect(await StorageService.getGems(), 40);
      expect(await StorageService.getPlayerXp(), 5000);
      expect(
        await StorageService.getLevel(),
        30,
        reason: 'a second phone cannot take a level away',
      );
    });
  });

  test('a purchase refuses a short wallet instead of going negative', () async {
    await StorageService.saveCoins(0);
    await StorageService.saveGems(SpinReward.extraSpinGems);

    expect(
      await ProgressService.spend(gems: SpinReward.extraSpinGems + 1),
      isFalse,
    );
    expect(await StorageService.getGems(), SpinReward.extraSpinGems);
    expect(await ProgressService.spend(gems: SpinReward.extraSpinGems), isTrue);
    expect(await StorageService.getGems(), 0);
  });
}
