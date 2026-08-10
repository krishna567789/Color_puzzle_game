import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../widgets/tube_widget.dart';
import '../core/app_colors.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController _controller = GameController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    setState(() {});
    if (_controller.isLevelComplete) {
      // Small delay to allow the last pour to render before showing dialog
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showWinDialog();
      });
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Level Complete!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Great job! You sorted all the colors.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _controller.restartLevel();
            },
            child: const Text('Play Again', style: TextStyle(color: AppColors.primaryButton, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Level 1',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.restartLevel(),
            tooltip: 'Restart Level',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
          child: Wrap(
            spacing: 24,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: List.generate(
              _controller.tubes.length,
              (index) => TubeWidget(
                tube: _controller.tubes[index],
                isSelected: _controller.selectedTubeIndex == index,
                onTap: () => _controller.selectTube(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
