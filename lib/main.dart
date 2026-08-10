import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ColorPuzzleGameApp());
}

class ColorPuzzleGameApp extends StatelessWidget {
  const ColorPuzzleGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Flow Puzzle',
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
