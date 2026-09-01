import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import '../core/ad_manager.dart';
import '../widgets/tube_widget.dart';
import '../core/app_colors.dart';
import '../widgets/common/hand_indicator.dart';
import '../widgets/common/game_button.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/common/level_complete_dialog.dart';
import '../widgets/common/pouring_stream_effect.dart';

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
    bool canUseExtraChance = _controller.extraChancesUsed < 3;
    bool outOfTime = _controller.remainingTime == 0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Main Card
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              margin: const EdgeInsets.only(top: 40), // Space for the overlapping icon
              decoration: BoxDecoration(
                color: const Color(0xFF1E153A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF5A3D99), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    canUseExtraChance ? 'KEEP GOING?' : 'GAME OVER',
                    style: TextStyle(
                      color: canUseExtraChance ? Colors.orangeAccent : Colors.redAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: (canUseExtraChance ? Colors.orange : Colors.red).withOpacity(0.5),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    canUseExtraChance
                        ? (outOfTime ? 'You ran out of time!\nGet 30 seconds to continue?' : 'You ran out of moves!\nGet 5 moves to continue?')
                        : 'You used all extra chances.\nTry again?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  if (canUseExtraChance) ...[
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pay Coins
                        GameButton(
                          width: 120,
                          onTap: () {
                            if (_controller.coins >= 50) {
                              Navigator.pop(context);
                              _controller.useExtraChance(outOfTime);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not enough coins!')),
                              );
                            }
                          },
                          color: const Color(0xFFFF9900), // Orange/Gold
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('50', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(width: 6),
                              Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                            ],
                          ),
                        ),
                        // Watch Ad
                        GameButton(
                          width: 120,
                          onTap: () {
                            AdManager.showRewardedAd(() {
                              Navigator.pop(context);
                              _controller.useExtraChance(outOfTime, isAd: true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Thanks for watching!')),
                              );
                            }, () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ad is not ready yet. Please try again!')),
                              );
                            });
                          },
                          color: const Color(0xFFE91E63), // Pink
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  'assets/images/icon_play.jpg',
                                  width: 20,
                                  height: 20,
                                  colorBlendMode: BlendMode.screen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('WATCH AD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _controller.restartLevel();
                      },
                      child: const Text('GIVE UP', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ] else ...[
                    // Retry Button
                    GameButton(
                      width: 160,
                      onTap: () {
                        Navigator.pop(context);
                        _controller.restartLevel();
                      },
                      color: Colors.redAccent,
                      child: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                    ),
                  ],
                ],
              ),
            ),

            // Floating 3D Icon at Top
            Positioned(
              top: 0,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // Dark background to make screen blend work
                  boxShadow: [
                    BoxShadow(
                      color: outOfTime ? Colors.orange.withOpacity(0.6) : Colors.cyan.withOpacity(0.6),
                      blurRadius: 30,
                    )
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    outOfTime ? 'assets/images/icon_hourglass.jpg' : 'assets/images/icon_broken_tube.jpg',
                    fit: BoxFit.cover,
                    colorBlendMode: BlendMode.screen,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      appBar: null,
      body: Stack(
        children: [
          // Dynamic Background based on selected theme
          _buildBackground(),
          
          // Top UI Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTopUI()),
          ),
          
          // Game Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 100.0, // Space for top bar
                  bottom: 32.0,
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
                  child: Stack(
                    key: ValueKey(_controller.currentLevel),
                    clipBehavior: Clip.none,
                    children: [
                      // Magical Glowing Shelf (Background)
                      Positioned(
                        bottom: -30,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Wrap(
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
                            isHinted: _controller.activeHint != null && 
                                (_controller.activeHint!.fromIndex == index || 
                                 _controller.activeHint!.toIndex == index),
                          ),
                        );
                      }),
                    ),
                    
                    // Liquid Pouring Stream Overlay
                    Positioned.fill(
                      child: PouringStreamEffect(
                        controller: _controller,
                        tubeKeys: _tubeKeys,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom Tools
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomTools(),
          ),
          
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_controller.selectedThemeId == 'forest_theme') {
      return Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                Color(0xFF2E7D32), // Lighter green top
                Color(0xFF1B5E20), // Dark green
                Color(0xFF051205), // Very dark bottom
              ],
            ),
          ),
        ),
      );
    } else if (_controller.selectedThemeId == 'space_theme') {
      return Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                Color(0xFF2B1B54), // Lighter purple top
                Color(0xFF0F0524), // Dark deep space bottom
              ],
            ),
          ),
        ),
      );
    }

    // Default theme (Wizard Room)
    return Positioned.fill(
      child: Image.asset(
        'assets/images/wizard_room_bg.jpg',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildTopUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Coins (Top Left)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEBCA), // Cream color
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4A373), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco, color: Colors.amber, size: 18), // Leaf/Coin icon
                  const SizedBox(width: 6),
                  Text(
                    '${_controller.coins}',
                    style: const TextStyle(
                      color: Color(0xFF8B0000), // Dark red text
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Level Info (Top Center)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B2A6A).withOpacity(0.8), // Purple transparent pill
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF5E4B9A)),
                ),
                child: Text(
                  _getModeTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.remainingTime != null) ...[
                    const Icon(Icons.timer, color: Colors.orangeAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_controller.remainingTime!),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.touch_app, color: Colors.cyanAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _controller.movesLimit != null
                        ? '${_controller.movesCount} / ${_controller.movesLimit}'
                        : '${_controller.movesCount}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          
          // Settings / Pause (Top Right)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A2BE2), // Bright purple circle
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB175FF), width: 2),
                ),
                child: const Icon(Icons.settings, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTools() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionBtn(
            imagePath: 'assets/images/icon_undo.jpg',
            cost: 50,
            onTap: () => _controller.undo(),
          ),
          const SizedBox(width: 20),
          _buildActionBtn(
            icon: Icons.lightbulb_outline,
            cost: 50,
            onTap: () => _controller.requestHint(),
          ),
          const SizedBox(width: 20),
          _buildActionBtn(
            imagePath: 'assets/images/icon_add_tube.jpg',
            cost: 100,
            onTap: () => _controller.addExtraTube(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({String? imagePath, IconData? icon, required int cost, required VoidCallback onTap}) {
    bool canAfford = _controller.coins >= cost;
    return GestureDetector(
      onTap: canAfford ? onTap : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins!')),
        );
      },
      child: Opacity(
        opacity: canAfford ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF6C20D6), // Purple background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700), width: 2.5), // Yellow border
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 8),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: imagePath != null
                  ? Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      colorBlendMode: BlendMode.screen,
                    )
                  : Icon(icon, color: Colors.amberAccent, size: 32),
              ),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0055), // Pink/Red badge
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$cost',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.monetization_on, color: Colors.yellow, size: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
