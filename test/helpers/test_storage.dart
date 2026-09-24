import 'dart:io';

import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Points `StorageService`'s Hive box at a throwaway directory so economy tests
/// exercise the same persistence path the app ships with. Returns the directory
/// so the caller can delete it in `tearDownAll`.
Future<Directory> useTestStorage() async {
  final dir = await Directory.systemTemp.createTemp('color_puzzle_test');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
  // Open the box here rather than letting the first test touch it: the open is
  // memoised, and a box first opened inside a `testWidgets` body belongs to a
  // fake-async zone whose timers the disk read waits on never advance, so every
  // later read in the file would inherit a future that never completes.
  await StorageService.init();
  return dir;
}

/// `google_mobile_ads` reaches the native SDK over a method channel no test
/// binding implements, so a screen that loads a banner on the first frame would
/// fail with MissingPluginException before it ever gets laid out.
///
/// The reply has to be an encoded success envelope: the plugin's channel uses
/// `StandardMethodCodec(AdMessageCodec())`, and a null reply is what
/// `decodeEnvelope` translates into MissingPluginException. It is intercepted
/// at the byte level because that codec's payloads are not readable by the
/// plain `setMockMethodCallHandler` decoder.
void stubAdsChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        'plugins.flutter.io/google_mobile_ads',
        (message) async =>
            const StandardMethodCodec().encodeSuccessEnvelope(null),
      );
}
