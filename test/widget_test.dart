
import 'package:flutter_test/flutter_test.dart';

import 'package:color_puzzle_game/main.dart';
import 'package:color_puzzle_game/screens/splash_screen.dart';

void main() {
  testWidgets('app starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ColorPuzzleGameApp());

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
