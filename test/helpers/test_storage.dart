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

/// Paint a widget into [size] *and* let it see [size].
///
/// `setSurfaceSize` only moves the render surface; `MediaQuery` still reports
/// the test window's own 800x600, so a responsive screen lays itself out for one
/// phone and paints itself into another. Any assertion about what fits on a
/// small screen is vacuous until the view agrees with the surface.
Future<void> useScreenSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
