import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import '../widgets/tube_widget.dart';
import '../core/app_colors.dart';
import '../widgets/common/hand_indicator.dart';
import '../widgets/common/game_button.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/common/level_complete_dialog.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final int? targetLevel;
  const GameScreen({super.key, this.mode = GameMode.classic, this.targetLevel});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _lockAudioPlayer;
  late List<GlobalKey> _tubeKeys;
  bool _isPlayingSound = false;
  bool _isEndDialogVisible = false;
  int _solvedTubesCount = 0;
  bool _showTutorial = false;
  int _tutorialStep = 0;
  int _currentLevelForKeys = 0;
  
  // Performance Tracking
  final Stopwatch _levelStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _controller = GameController(mode: widget.mode, targetLevel: widget.targetLevel);
    _controller.addListener(_onGameStateChanged);
    _audioPlayer = AudioPlayer();
    _lockAudioPlayer = AudioPlayer();
    _currentLevelForKeys = _controller.currentLevel;
    _tubeKeys = List.generate(20, (_) => GlobalKey());
    _checkTutorial();
    _levelStopwatch.start();
  }

  Future<void> _checkTutorial() async {
    if (widget.mode == GameMode.classic) {
      bool completed = await StorageService.isTutorialCompleted();
      if (!completed && _controller.currentLevel == 1) {
        setState(() {
          _showTutorial = true;
        });
        // Force a rebuild after frame to calculate positions
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _onGameStateChanged() {
    if (!mounted) return;

    // Refresh keys if level changed to avoid "Duplicate GlobalKeys" during AnimatedSwitcher transition
    if (_controller.currentLevel != _currentLevelForKeys) {
      _tubeKeys = List.generate(20, (_) => GlobalKey());
      _currentLevelForKeys = _controller.currentLevel;
      _levelStopwatch.reset();
      _levelStopwatch.start();
    }

    setState(() {});

    // Play sound when pouring starts
    if (_controller.pouringFromIndex != null && !_isPlayingSound) {
      _isPlayingSound = true;
      _audioPlayer.play(AssetSource('audio/pour.ogg'));
    } else if (_controller.pouringFromIndex == null && _isPlayingSound) {
      _isPlayingSound = false;
      _audioPlayer.stop();
    }

    int currentSolvedCount = _controller.tubes
        .where(
          (t) =>
              t.isFull &&
              t.colors.isNotEmpty &&
              t.colors.every((c) => c == t.colors.first),
        )
        .length;
    if (currentSolvedCount > _solvedTubesCount) {
      _lockAudioPlayer.play(AssetSource('audio/lock.wav'));
    }
    _solvedTubesCount = currentSolvedCount;

    if (_isEndDialogVisible) return;
    if (_controller.isLevelComplete) {
      _isEndDialogVisible = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showWinDialog();
      });
    } else if (_controller.isGameOver) {
      _isEndDialogVisible = true;
      if (mounted) _showGameOverDialog();
    }
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case GameMode.classic:
        return 'Level ${_controller.currentLevel}';
      case GameMode.challenge:
        return 'Challenge';
      case GameMode.daily:
        return 'Daily Challenge';
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  void _showGameOverDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Game Over!',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'You ran out of time or moves. Try again?',
          style: TextStyle(color: Colors.white70),
        ),

        actions: [
          Center(
            child: GameButton(
              width: 160,
              onTap: () {
                Navigator.pop(context);
                _controller.restartLevel();
              },
              color: Colors.redAccent,
              child: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    ).whenComplete(() => _isEndDialogVisible = false);
  }

  void _showWinDialog() {
    _levelStopwatch.stop();
    final int elapsedSeconds = _levelStopwatch.elapsed.inSeconds;
    final int moves = _controller.movesCount;
    
    // Star Calculation Logic (3 stars = good, 1 star = slow/many moves)
    int stars = 1;
    if (moves <= 15 && elapsedSeconds <= 30) {
      stars = 3;
    } else if (moves <= 25 && elapsedSeconds <= 60) {
      stars = 2;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => LevelCompleteDialog(
          stars: stars,
          level: _controller.currentLevel,
          coinsEarned: 50,
          gemsEarned: 5,
          onNext: () {
            Navigator.pop(context);
            _controller.nextLevel();
          },
          onHome: () {
            Navigator.pop(context);
            Navigator.pop(context); // Go back to dashboard
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => _isEndDialogVisible = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    _audioPlayer.dispose();
    _lockAudioPlayer.dispose();
    super.dispose();
  }

  Widget _buildTutorialOverlay() {
    int targetIndex = -1;
    if (_tutorialStep == 0) {
      targetIndex = _controller.tubes.indexWhere((t) => t.isNotEmpty);
    } else {
      targetIndex = _controller.tubes.indexWhere((t) => t.isEmpty);
    }
    
    Offset handPos = Offset.zero;
    if (targetIndex != -1 && targetIndex < _tubeKeys.length) {
      final context = _tubeKeys[targetIndex].currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          final size = box.size;
          handPos = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
        }
      }
    }

    return Stack(
      children: [
        // 1. Full screen IgnorePointer for the hand and ripple
        if (handPos != Offset.zero)
          IgnorePointer(
            child: Stack(
              children: [
                Container(color: Colors.black12), // Subtle dimming
                Positioned(
                  left: handPos.dx - 50,
                  top: handPos.dy - 50,
                  child: const HandIndicator(),
                ),
              ],
            ),
          ),

        // 2. Short Message (Non-blocking)
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 140),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C2FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00C2FF).withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: Text(
                  _tutorialStep == 0 ? 'TAP BOTTLE' : 'POUR HERE',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                ),
              ),
            ),
          ),
        ),

        // 3. SKIP button (Interactive)
        Positioned(
          top: 60,
          right: 20,
          child: GestureDetector(
            onTap: () {
              setState(() => _showTutorial = false);
              StorageService.setTutorialCompleted(true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('SKIP', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // Remove the old _buildAnimatedFinger as it's replaced by HandIndicator

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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.remainingTime != null) ...[
                  const Icon(Icons.timer, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_controller.remainingTime!),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
            icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
            onPressed: _showHint,
            tooltip: 'Show Hint',
          ),

          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.restartLevel(),
            tooltip: 'Restart Level',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  AppColors.background.withValues(alpha: 0.8),
                  AppColors.background,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 32.0,
                  ),
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
                      children: List.generate(_controller.tubes.length, (index) {
                        bool isPouringSource =
                            _controller.pouringFromIndex == index;
                        bool isReceiving = _controller.pouringToIndex == index;

                        Offset moveOffset = Offset.zero;
                        Offset? targetOffset;

                        if (isPouringSource && _controller.pouringToIndex != null) {
                          if (_tubeKeys[index].currentContext != null &&
                              _tubeKeys[_controller.pouringToIndex!]
                                      .currentContext !=
                                  null) {
                            RenderBox sourceBox =
                                _tubeKeys[index].currentContext!.findRenderObject()
                                    as RenderBox;
                            RenderBox targetBox =
                                _tubeKeys[_controller.pouringToIndex!]
                                        .currentContext!
                                        .findRenderObject()
                                    as RenderBox;

                            Offset sourcePos = sourceBox.localToGlobal(Offset.zero);
                            Offset targetPos = targetBox.localToGlobal(Offset.zero);

                            double tiltDir = _controller.pourTiltAngle > 0
                                ? -20
                                : 20;
                            moveOffset = Offset(
                              targetPos.dx - sourcePos.dx + tiltDir,
                              targetPos.dy - sourcePos.dy - 160,
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
                            tiltAngle: isPouringSource
                                ? _controller.pourTiltAngle
                                : 0.0,
                            offset: moveOffset,
                            targetOffset: targetOffset,
                            pouringColor: _controller.pouringColor,
                            onTap: () {
                          if (_showTutorial) {
                            bool isCorrect = false;
                            if (_tutorialStep == 0) {
                              // Correct if user taps any non-empty tube
                              isCorrect = _controller.tubes[index].isNotEmpty;
                            } else {
                              // Correct if user taps any valid target tube (empty for the first move)
                              isCorrect = _controller.tubes[index].isEmpty;
                            }
                            
                            if (!isCorrect) {
                              _controller.triggerWrongMove(index);
                              return;
                            }
                            
                            setState(() {
                              _tutorialStep++;
                              if (_tutorialStep >= 2) {
                                _showTutorial = false;
                                StorageService.setTutorialCompleted(true);
                              }
                            });
                          }
                          _controller.selectTube(index);
                        },
                            skinId: _controller.selectedSkinId,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  void _showHint() {
    final hint = _controller.requestHint();
    final message = hint == null
        ? 'No hint available right now.'
        : 'Hint: pour tube ${hint.fromIndex + 1} into tube ${hint.toIndex + 1}.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
