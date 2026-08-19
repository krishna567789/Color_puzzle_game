import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../widgets/tube_widget.dart';
import '../core/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, this.mode = GameMode.classic});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final AudioPlayer _audioPlayer;
  late List<GlobalKey> _tubeKeys;
  bool _isPlayingSound = false;
  int _solvedTubesCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = GameController(mode: widget.mode);
    _controller.addListener(_onGameStateChanged);
    _audioPlayer = AudioPlayer();
    _tubeKeys = List.generate(20, (_) => GlobalKey());
  }

  void _onGameStateChanged() {
    setState(() {});
    
    // Play sound when pouring starts
    if (_controller.pouringFromIndex != null && !_isPlayingSound) {
      _isPlayingSound = true;
      _audioPlayer.play(AssetSource('audio/pour.ogg'));
    } else if (_controller.pouringFromIndex == null && _isPlayingSound) {
      _isPlayingSound = false;
      _audioPlayer.stop();
    }

    int currentSolvedCount = _controller.tubes.where((t) => t.isFull && t.colors.isNotEmpty && t.colors.every((c) => c == t.colors.first)).length;
    if (currentSolvedCount > _solvedTubesCount) {
       AudioPlayer().play(AssetSource('audio/lock.wav'));
    }
    _solvedTubesCount = currentSolvedCount;

    if (_controller.isLevelComplete) {
      // Small delay to allow the last pour to render before showing dialog
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showWinDialog();
      });
    } else if (_controller.remainingTime == 0 || (_controller.movesLimit != null && _controller.movesCount >= _controller.movesLimit!)) {
       if (mounted) _showGameOverDialog();
    }
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case GameMode.classic: return 'Level ${_controller.currentLevel}';
      case GameMode.challenge: return 'Challenge';
      case GameMode.daily: return 'Daily Challenge';
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Game Over!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('You ran out of time or moves. Try again?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.restartLevel();
            },
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
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
    _audioPlayer.dispose();
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
              _getModeTitle(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.remainingTime != null) ...[
                  const Icon(Icons.timer, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_controller.remainingTime!),
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.touch_app, color: Colors.cyan, size: 16),
                const SizedBox(width: 4),
                Text(
                  _controller.movesLimit != null 
                    ? '${_controller.movesCount} / ${_controller.movesLimit}' 
                    : '${_controller.movesCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
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
                      
                      Offset moveOffset = Offset.zero;
                      Offset? targetOffset;

                      if (isPouringSource && _controller.pouringToIndex != null) {
                         if (_tubeKeys[index].currentContext != null && 
                             _tubeKeys[_controller.pouringToIndex!].currentContext != null) {
                           RenderBox sourceBox = _tubeKeys[index].currentContext!.findRenderObject() as RenderBox;
                           RenderBox targetBox = _tubeKeys[_controller.pouringToIndex!].currentContext!.findRenderObject() as RenderBox;
                           
                           Offset sourcePos = sourceBox.localToGlobal(Offset.zero);
                           Offset targetPos = targetBox.localToGlobal(Offset.zero);
                           
                           double tiltDir = _controller.pourTiltAngle > 0 ? -20 : 20;
                           moveOffset = Offset(
                             targetPos.dx - sourcePos.dx + tiltDir, 
                             targetPos.dy - sourcePos.dy - 160
                           );
                           
                           targetOffset = Offset(0, 160);
                         }
                      }

                      return Container(
                        key: _tubeKeys[index],
                        child: TubeWidget(
                          tube: _controller.tubes[index],
                          isSelected: _controller.selectedTubeIndex == index,
                          isShaking: _controller.wrongMoveIndex == index,
                          isReceiving: isReceiving,
                          tiltAngle: isPouringSource ? _controller.pourTiltAngle : 0.0,
                          offset: moveOffset,
                          targetOffset: targetOffset,
                          pouringColor: _controller.pouringColor,
                          onTap: () => _controller.selectTube(index),
                        ),
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
