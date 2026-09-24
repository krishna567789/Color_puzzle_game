import 'package:color_puzzle_game/core/numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compactAmount', () {
    test('keeps small balances exact', () {
      expect(compactAmount(0), '0');
      expect(compactAmount(500), '500');
      expect(compactAmount(9999), '9999');
    });

    test('shortens the balances that used to break the HUD pills', () {
      expect(compactAmount(10000), '10K');
      expect(compactAmount(12500), '12.5K');
      expect(compactAmount(999949), '999.9K');
      expect(compactAmount(999999), '1M');
      expect(compactAmount(1000000), '1M');
      expect(compactAmount(1250865), '1.3M');
      expect(compactAmount(150000000), '150M');
    });

    test('does not lose the sign of a debt', () {
      expect(compactAmount(-25000), '-25K');
    });
  });
}
