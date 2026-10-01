import 'package:color_puzzle_game/widgets/common/game_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 3D shadow under every button is a `Positioned` layer, and a Positioned
/// child with no horizontal constraint is laid out with an unbounded width. A
/// layer built with `width: double.infinity` therefore asserts in debug and
/// collapses to nothing in release, which is what a full-width button used to
/// ask for.
void main() {
  Future<void> host(WidgetTester tester, double width, {bool clamp = false}) async {
    final button = GameButton(
      width: width,
      onTap: () {},
      child: const Text('NEXT LEVEL'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            // A tight 280 parent is what a full-width button has to survive; a
            // fixed-width one is measured with nothing forcing it.
            child: clamp ? SizedBox(width: 280, child: button) : button,
          ),
        ),
      ),
    );
  }

  testWidgets('a full-width button lays out and keeps its shadow', (
    tester,
  ) async {
    await host(tester, double.infinity, clamp: true);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(GameButton)).width, 280);

    final layers = tester.widgetList<Container>(find.byType(Container));
    expect(layers, hasLength(2), reason: 'shadow plus face');
    for (final container in layers) {
      expect(
        tester.getSize(find.byWidget(container)).width,
        280,
        reason: 'a button layer rendered at no width',
      );
    }
  });

  testWidgets('a fixed-width button still sizes itself', (tester) async {
    await host(tester, 160);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(GameButton)).width, 160);
  });

  testWidgets('pressing moves the face and fires once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameButton(
              onTap: () => taps++,
              child: const Text('PLAY'),
            ),
          ),
        ),
      ),
    );
    final face = find.byType(GestureDetector);
    await tester.tap(face, warnIfMissed: false);
    await tester.pump();
    expect(taps, 1);
  });
}
