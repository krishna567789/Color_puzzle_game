import 'dart:io';
import 'dart:math';

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/widgets/common/level_complete_dialog.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// Only a rendered screen shows whether a win is felt on the board itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  testWidgets('the winning pour rattles the board before the results arrive', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const GameScreen(targetLevel: 7),
      ),
    );

    final errors = <FlutterErrorDetails>[];
    final reportFirst = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      reportFirst?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportFirst);

    /// A frame of the fake clock, plus a breath of the real one so the Hive
    /// writes behind the payout can finish.
    Future<void> pulse() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    Future<void> tick(int ms) async {
      for (var elapsed = 0; elapsed < ms; elapsed += 16) {
        await pulse();
      }
    }

    for (var i = 0; i < 8; i++) {
      await pulse();
    }

    final tubes = find.byType(TubeWidget);
    final count = tubes.evaluate().length;
    final board = List<Tube>.generate(
      count,
      (i) => tester.widget<TubeWidget>(tubes.at(i)).tube,
    );

    // Arrange one pour away from a win: every bottle sorted but the pair the
    // player finishes with.
    for (var i = 0; i < count - 2; i++) {
      board[i].colors
        ..clear()
        ..addAll(
          List.filled(board[i].capacity, Color(0xFF200000 + i * 0x050505)),
        );
      board[i].hiddenCount = 0;
    }
    const last = Color(0xFFFF2A2A);
    final winner = board[count - 2];
    final spare = board[count - 1];
    winner.colors
      ..clear()
      ..addAll([last, last, last]);
    spare.colors
      ..clear()
      ..add(last);

    await tick(80);
    expect(find.byType(Wrap), findsOneWidget);
    final settledX = _boardCenterX(tester);

    await tester.tap(tubes.at(count - 1));
    await tick(80);
    await tester.tap(tubes.at(count - 2));
    await tick(1300);

    expect(winner.colors.length, 4, reason: 'the last layer has to land');
    expect(
      find.byType(LevelCompleteDialog),
      findsNothing,
      reason: 'the board gets its own moment first',
    );

    var jolt = 0.0;
    for (var frame = 0; frame < 25; frame++) {
      await pulse();
      jolt = max(jolt, (_boardCenterX(tester) - settledX).abs());
    }
    expect(jolt, greaterThan(1.0), reason: 'the win should rattle the shelf');
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<MagicDustPainter>(),
      isNotEmpty,
      reason: 'the sorted tubes cheer along with it',
    );

    await tick(1200);
    expect(
      (_boardCenterX(tester) - settledX).abs(),
      lessThan(0.5),
      reason: 'and then the board settles',
    );
    expect(
      find.byType(LevelCompleteDialog),
      findsOneWidget,
      reason: 'the results still follow the celebration',
    );

    expect(errors, isEmpty);
    for (var i = 0; i < 20; i++) {
      await pulse();
    }
  });
}

double _boardCenterX(WidgetTester tester) =>
    tester.getRect(find.byType(Wrap)).center.dx;
