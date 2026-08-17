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
              Navigator.pop(context);
              _controller.restartLevel();
            },
            child: const Text('Restart', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _controller.nextLevel();
            },
            child: const Text('Next Level', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        title: Column(
          children: [
            Text(
              'Level ${_controller.currentLevel}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.2),
            ),
            Text(
              'Moves: ${_controller.movesCount}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () => _controller.undo(),
            tooltip: 'Undo Move',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.restartLevel(),
            tooltip: 'Restart Level',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppColors.background.withOpacity(0.8),
              AppColors.background,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Wrap(
                  key: ValueKey(_controller.currentLevel),
                  spacing: 24,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    _controller.tubes.length,
                    (index) {
                      bool isPouringSource = _controller.pouringFromIndex == index;
                      bool isReceiving = _controller.pouringToIndex == index;
                      
                      return TubeWidget(
                        tube: _controller.tubes[index],
                        isSelected: _controller.selectedTubeIndex == index,
                        isShaking: _controller.wrongMoveIndex == index,
                        isReceiving: isReceiving,
                        tiltAngle: isPouringSource ? _controller.pourTiltAngle : 0.0,
                        onTap: () => _controller.selectTube(index),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
