import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/storage_service.dart';
import 'core/audio_service.dart';
import 'core/ad_manager.dart';
import 'core/play_games_service.dart';
import 'core/iap_service.dart';
import 'core/haptic_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await StorageService.init();
  await AudioService.init();
  await AdManager.init();
  await PlayGamesService.init();
  await IapService.init();
  await HapticService.init();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purpleAccent),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
