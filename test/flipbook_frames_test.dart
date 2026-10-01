/// The flipbook contract: a sequence the widgets play is a sequence that exists.
///
/// `FrameSequence` answers a missing frame with an empty box, so a folder that
/// has drifted out of step with its renderer - or that was never added to the
/// asset manifest - shows a blank where a celebration should be instead of
/// failing anywhere. Both are checked here against the files on disk.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every frame a `FrameSequence` is pointed at, in the order it plays them.
const Map<String, int> _shipped = {
  'assets/anim/victory_spin': 16,
  'assets/anim/spin_coin': 16,
  'assets/anim/spin_gem': 16,
};

void main() {
  final declared = File('pubspec.yaml').readAsStringSync();

  for (final entry in _shipped.entries) {
    group(entry.key, () {
      test('is bundled', () {
        expect(
          RegExp('^\\s*- ${entry.key}/\$', multiLine: true).hasMatch(declared),
          isTrue,
          reason: '$entry.key is not in pubspec.yaml, so it will not ship',
        );
      });

      test('has ${entry.value} contiguous frames', () {
        for (var frame = 1; frame <= entry.value; frame++) {
          final path = '${entry.key}/frame_${frame.toString().padLeft(2, '0')}.png';
          expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        }
        // A re-render that added frames leaves the tail unplayed rather than
        // breaking, so say so instead of letting it sit unnoticed.
        final extra =
            '${entry.key}/frame_${(entry.value + 1).toString().padLeft(2, '0')}.png';
        expect(
          File(extra).existsSync(),
          isFalse,
          reason: '$extra exists but no widget asks for it - update frameCount',
        );
      });
    });
  }
}
