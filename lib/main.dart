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
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every layout in this game is composed for a portrait phone.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp();
  await StorageService.init();
  // These talk to separate SDKs and none of them depend on each other, so a
  // slow Play Games / store handshake should not add to splash time.
  await Future.wait([
    AudioService.init(),
    AdManager.init(),
    PlayGamesService.init(),
    IapService.init(),
    HapticService.init(),
  ]);
  runApp(const ColorPuzzleGameApp());
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
