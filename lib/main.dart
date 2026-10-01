import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'core/storage_service.dart';
import 'core/audio_service.dart';
import 'core/ad_manager.dart';
import 'core/play_games_service.dart';
import 'core/iap_service.dart';
import 'core/haptic_service.dart';
import 'content/content_repository.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every layout in this game is composed for a portrait phone.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // The one SDK the game can play without. Analytics already swallows its own
  // failures, and iOS has no GoogleService-Info.plist in the repo yet, so an
  // unguarded await here would stop the app from ever opening on that platform.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase unavailable, playing without analytics: $error');
  }
  await StorageService.init();
  // These talk to separate SDKs and none of them depend on each other, so a
  // slow Play Games / store handshake should not add to splash time. Loading
  // the content set is in this group too: it already serves from the copy
  // compiled into the binary, so a bundle read that fails or arrives late can
  // never leave a screen with nothing to show.
  await Future.wait([
    ContentRepository.refresh(),
    AudioService.init(),
    AdManager.init(),
    PlayGamesService.init(),
    IapService.init(),
    HapticService.init(),
  ]);
  _logContentSource();
  runApp(const ColorPuzzleGameApp());
}

/// Says which copy of the content set is serving, and why a bundle was refused.
/// The two are meant to hold identical bytes, so a difference here is a build
/// problem worth seeing in a log rather than one a player has to describe.
void _logContentSource() {
  final source = ContentRepository.source;
  if (source.isCompiledFallback) {
    debugPrint('Content ${source.version} from the compiled copy');
  } else {
    debugPrint('Content ${source.version} from the asset bundle');
  }
  for (final issue in source.issues) {
    debugPrint('Content refused: $issue');
  }
}

class ColorPuzzleGameApp extends StatefulWidget {
  const ColorPuzzleGameApp({super.key});

  @override
  State<ColorPuzzleGameApp> createState() => _ColorPuzzleGameAppState();
}

class _ColorPuzzleGameAppState extends State<ColorPuzzleGameApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      AudioService.pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.resumeBGM();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
