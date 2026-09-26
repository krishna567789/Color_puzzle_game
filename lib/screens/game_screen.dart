import 'dart:math';

import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import '../core/ad_manager.dart';
import '../widgets/tube_widget.dart';
import '../core/app_colors.dart';
import '../game/pour_geometry.dart';
import '../widgets/common/hand_indicator.dart';
import '../widgets/common/game_button.dart';
import '../widgets/common/bouncing_button.dart';
import '../core/audio_service.dart';
import '../widgets/common/level_complete_dialog.dart';
import '../widgets/common/pouring_stream_effect.dart';
import 'package:confetti/confetti.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final int? targetLevel;
  const GameScreen({super.key, this.mode = GameMode.classic, this.targetLevel});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameController _controller;
  late List<GlobalKey> _tubeKeys;
  bool _isEndDialogVisible = false;
  int _solvedTubesCount = 0;
  bool _showTutorial = false;
  int _tutorialStep = 0;
  int _currentLevelForKeys = 0;
  late ConfettiController _confettiController;

  /// The board's victory jolt: the last tube locking into place should rattle
  /// the whole shelf before the results screen takes over.
  late final AnimationController _victoryShake;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      mode: widget.mode,
      targetLevel: widget.targetLevel,
    );
    _controller.addListener(_onGameStateChanged);
    _currentLevelForKeys = _controller.currentLevel;
    _tubeKeys = List.generate(20, (_) => GlobalKey());
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _victoryShake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkTutorial();
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
    }

    setState(() {});

    // The controller already plays the pour effect on every pour; a second
    // player here would both double the sound and ignore the SFX setting.
    int currentSolvedCount = _controller.tubes
        .where(
          (t) =>
              t.isFull &&
              t.colors.isNotEmpty &&
              t.colors.every((c) => c == t.colors.first),
        )
        .length;
    if (currentSolvedCount > _solvedTubesCount) {
      AudioService.playSfx('lock.wav');
    }
    _solvedTubesCount = currentSolvedCount;

    if (_isEndDialogVisible) return;
    if (_controller.isLevelComplete) {
      // Wait for the payout to be stored: the screen quotes the controller's
      // numbers, and it is better to be a frame late than to promise wrong ones.
      if (!_controller.winRewarded) return;
      _isEndDialogVisible = true;
      _victoryShake.forward(from: 0.0);
      _confettiController.play();
      // The jolt and the sparkles need a beat before the results take over.
      Future.delayed(const Duration(milliseconds: 700), () {
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
      case GameMode.timeAttack:
        return 'Time Attack';
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
    final bool stuck = _controller.isStuck;
    final bool canRecover =
        _controller.extraChancesUsed < GameController.maxExtraChances;
    final bool outOfTime = _controller.remainingTime == 0;

    // A deadlock is not fixed by more time or more moves; only a re-scramble
    // gives the board a legal pour again.
    final int rescueCost = stuck
        ? _controller.costOf(PowerUp.shuffle)
        : GameController.extraChanceCost;

    bool rescue({required bool adFunded}) => stuck
        ? _controller.shuffleTubes(adFunded: adFunded)
        : _controller.useExtraChance(outOfTime, isAd: adFunded);

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
              margin: const EdgeInsets.only(
                top: 40,
              ), // Space for the overlapping icon
              decoration: BoxDecoration(
                color: const Color(0xFF1E153A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF5A3D99), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2).withValues(alpha: 0.4),
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
                    canRecover ? 'KEEP GOING?' : 'GAME OVER',
                    style: TextStyle(
                      color: canRecover
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: (canRecover ? Colors.orange : Colors.red)
                              .withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    !canRecover
                        ? 'You used all extra chances.\nTry again?'
                        : stuck
                        ? 'No pours are left on this board.\nStir the bottles to continue?'
                        : (outOfTime
                              ? 'You ran out of time!\nGet 30 seconds to continue?'
                              : 'You ran out of moves!\nGet 5 moves to continue?'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  if (canRecover) ...[
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pay Coins
                        GameButton(
                          width: 120,
                          onTap: () {
                            if (!rescue(adFunded: false)) {
                              _showSnack('Not enough coins for another try!');
                              return;
                            }
                            Navigator.pop(context);
                          },
                          color: const Color(0xFFFF9900), // Orange/Gold
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$rescueCost',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.yellow,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        // Watch Ad
                        GameButton(
                          width: 120,
                          onTap: () {
                            AdManager.showRewardedAd(
                              () {
                                if (!rescue(adFunded: true)) {
                                  _showSnack(
                                    'This rescue is no longer available.',
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                              },
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ad is not ready yet. Please try again!',
                                    ),
                                  ),
                                );
                              },
                            );
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
                              const Text(
                                'WATCH AD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
                      child: const Text(
                        'GIVE UP',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
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
                      child: const Text(
                        'RETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
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
                  color:
                      Colors.black, // Dark background to make screen blend work
                  boxShadow: [
                    BoxShadow(
                      color: outOfTime
                          ? Colors.orange.withValues(alpha: 0.6)
                          : Colors.cyan.withValues(alpha: 0.6),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    outOfTime
                        ? 'assets/images/icon_hourglass.jpg'
                        : 'assets/images/icon_broken_tube.jpg',
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
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, _) => LevelCompleteDialog(
          stars: _controller.starsEarned,
          level: _controller.currentLevel,
          coinsEarned: _controller.coinsEarned,
          gemsEarned: _controller.gemsEarned,
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
    _confettiController.dispose();
    _victoryShake.dispose();
    _controller.removeListener(_onGameStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTutorialOverlay() {
    int targetIndex = -1;
    if (_tutorialStep == 0) {
      targetIndex = _controller.tubes.indexWhere((t) => t.isNotEmpty);
    } else if (_controller.selectedTubeIndex != null) {
      targetIndex = _controller.tubes.indexWhere((t) {
        int idx = _controller.tubes.indexOf(t);
        return _controller.canPour(_controller.selectedTubeIndex!, idx);
      });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C2FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF00C2FF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C2FF).withValues(alpha: 0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  _tutorialStep == 0 ? 'TAP BOTTLE' : 'POUR HERE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
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
              child: const Text(
                'SKIP',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Remove the old _buildAnimatedFinger as it's replaced by HandIndicator

  /// The confetti wears the level's own liquids, not the package's rainbow.
  List<Color> _celebrationColors() {
    final colors = _controller.tubes
        .expand((tube) => tube.colors)
        .whereType<Color>()
        .toSet()
        .toList();
    return colors.isEmpty ? const [Colors.amber, Colors.cyanAccent] : colors;
  }

  /// A side-to-side rattle that dies away over its own length.
  Offset _victoryJolt() {
    final t = _victoryShake.value;
    if (t <= 0.0 || t >= 1.0) return Offset.zero;
    final decay = (1.0 - t) * (1.0 - t);
    return Offset(sin(t * pi * 7) * 7 * decay, 0);
  }

  // The board is a grid of 55 x 160 bottles with these gaps, in unscaled units.
  static const double _tubeGap = 24;
  static const double _rowGap = 40;

  /// How many bottles fit in a row, and the scale that makes the whole grid fit
  /// the screen between the top bar and the power-up strip.
  ///
  /// A `Wrap` only knows its row count once the scale is known, and the scale
  /// depends on the row count, so the grid shape is decided here and the `Wrap`
  /// is then given exactly enough width to lay out that shape.
  ({int columns, double scale}) _boardLayout(int tubeCount, Size screen) {
    // The widest row the screen can carry, then the bottle count spread evenly
    // over the rows that need - 9 bottles are a 3 x 3 board, not a 4 / 4 / 1.
    final target = tubeCount >= 12 ? 5 : 4;
    // The controller fills its tubes a frame after the first build, and a
    // zero-row grid divides by zero on the way to the scale.
    final rows = max(1, (tubeCount / target).ceil());
    final columns = max(1, min(tubeCount, (tubeCount / rows).ceil()));
    // 100 for the top bar, and 40 + 56 + the badge overhang for the tools.
    final usableHeight = screen.height - 100 - 112 - 16;
    final widthScale =
        (screen.width - 32) / (columns * 55 + (columns - 1) * _tubeGap);
    final heightScale = usableHeight / (rows * 160 + (rows - 1) * _rowGap);
    final scale = min(
      widthScale,
      heightScale,
    ).clamp(0.5, screen.width > 600 ? 1.3 : 1.1);
    return (columns: columns, scale: scale);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final layout = _boardLayout(_controller.tubes.length, screenSize);
    final double scale = layout.scale;
    // A tipped-over bottle is a whole tube-length long, so the pour has to know
    // where the screen ends to keep it from hanging off the side.
    final pourBounds = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

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
          AnimatedBuilder(
            animation: _victoryShake,
            builder: (context, child) =>
                Transform.translate(offset: _victoryJolt(), child: child),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 100.0, // Space for the top bar
                    // On a short screen the board still has to scroll clear of
                    // the power-up strip, which is 96 tall plus its badge.
                    bottom: 120.0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
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
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          // Exactly one row of `columns` bottles wide, so the wrap
                          // breaks rows where the layout math says it should.
                          width:
                              layout.columns * 55 * scale +
                              (layout.columns - 1) * _tubeGap * scale,
                          child: Wrap(
                            spacing: _tubeGap * scale,
                            runSpacing: _rowGap * scale,
                            alignment: WrapAlignment.center,
                            children: List.generate(_controller.tubes.length, (
                              index,
                            ) {
                              bool isPouringSource =
                                  _controller.pouringFromIndex == index;

                              Offset moveOffset = Offset.zero;
                              double tilt = 0.0;

                              if (isPouringSource &&
                                  _controller.pouringToIndex != null) {
                                final sourceContext =
                                    _tubeKeys[index].currentContext;
                                final targetContext =
                                    _tubeKeys[_controller.pouringToIndex!]
                                        .currentContext;
                                if (sourceContext != null &&
                                    targetContext != null) {
                                  final sourceBox =
                                      sourceContext.findRenderObject()
                                          as RenderBox;
                                  final targetBox =
                                      targetContext.findRenderObject()
                                          as RenderBox;

                                  final targetTube = _controller
                                      .tubes[_controller.pouringToIndex!];
                                  final geometry = PourGeometry.forTubes(
                                    sourceTopLeft: sourceBox.localToGlobal(
                                      Offset.zero,
                                    ),
                                    sourceSize: sourceBox.size,
                                    targetTopLeft: targetBox.localToGlobal(
                                      Offset.zero,
                                    ),
                                    targetSize: targetBox.size,
                                    tilt: _controller.pourTiltAngle,
                                    bounds: pourBounds,
                                    targetLayers: targetTube.colors.length,
                                    targetCapacity: targetTube.capacity,
                                  );
                                  // The lean and the hover come from one place: the
                                  // tube has to tip the same way the stream expects.
                                  tilt = geometry.tilt;
                                  moveOffset = geometry.hoverOffset;
                                }
                              }

                              return Container(
                                key: _tubeKeys[index],
                                child: TubeWidget(
                                  tube: _controller.tubes[index],
                                  isSelected:
                                      _controller.selectedTubeIndex == index,
                                  isShaking:
                                      _controller.wrongMoveIndex == index,
                                  tiltAngle: tilt,
                                  offset: moveOffset,
                                  scale: scale,
                                  onTap: () {
                                    if (_showTutorial) {
                                      bool isCorrect = false;
                                      if (_tutorialStep == 0) {
                                        // Correct if user taps any non-empty tube
                                        isCorrect =
                                            _controller.tubes[index].isNotEmpty;
                                      } else {
                                        // Correct if user taps any valid target tube
                                        if (_controller.selectedTubeIndex !=
                                            null) {
                                          isCorrect = _controller.canPour(
                                            _controller.selectedTubeIndex!,
                                            index,
                                          );
                                        }
                                      }

                                      if (!isCorrect) {
                                        _controller.triggerWrongMove(index);
                                        return;
                                      }

                                      setState(() {
                                        _tutorialStep++;
                                        if (_tutorialStep >= 2) {
                                          _showTutorial = false;
                                          StorageService.setTutorialCompleted(
                                            true,
                                          );
                                        }
                                      });
                                    }
                                    _controller.selectTube(index);
                                  },
                                  skinId: _controller.selectedSkinId,
                                  showPatterns:
                                      _controller.showColorblindPatterns,
                                  celebrate: _controller.isLevelComplete,
                                  isHinted:
                                      _controller.activeHint != null &&
                                      (_controller.activeHint!.fromIndex ==
                                              index ||
                                          _controller.activeHint!.toIndex ==
                                              index),
                                ),
                              );
                            }),
                          ),
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
          ),

          // Bottom Tools. Left-handed mode puts them under the left thumb.
          Align(
            alignment: _controller.leftHandedLayout
                ? Alignment.bottomLeft
                : Alignment.bottomCenter,
            child: _buildBottomTools(),
          ),

          if (_showTutorial) _buildTutorialOverlay(),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              colors: _celebrationColors(),
              blastDirection: pi / 2, // downwards
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
            ),
          ),
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
      child: Image.asset('assets/images/wizard_room_bg.jpg', fit: BoxFit.cover),
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
                  const Icon(
                    Icons.eco,
                    color: Colors.amber,
                    size: 18,
                  ), // Leaf/Coin icon
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF3B2A6A,
                  ).withValues(alpha: 0.8), // Purple transparent pill
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
                    const Icon(
                      Icons.timer,
                      color: Colors.orangeAccent,
                      size: 12,
                    ),
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
                  const Icon(
                    Icons.touch_app,
                    color: Colors.cyanAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _controller.movesLimit != null
                        ? '${_controller.movesCount} / ${_controller.movesLimit}'
                        : '${_controller.movesCount}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
                child: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTools() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 40.0,
        // Only the mirrored mode hugs an edge; centring is `Align`'s job, and a
        // matching right inset here would knock the row off centre by half of it.
        left: _controller.leftHandedLayout ? 20.0 : 0.0,
      ),
      child: Row(
        // The strip itself, not the padding box around it: the 20dp mirror inset
        // has to show up in whatever a test measures.
        key: const Key('bottomTools'),
        // Shrunk to its buttons so `Align` has something to place.
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionBtn(
            power: PowerUp.undo,
            imagePath: 'assets/images/icon_undo.jpg',
          ),
          const SizedBox(width: 20),
          _buildActionBtn(power: PowerUp.hint, icon: Icons.lightbulb_outline),
          const SizedBox(width: 20),
          _buildActionBtn(
            power: PowerUp.shuffle,
            imagePath: 'assets/images/icon_shuffle.jpg',
          ),
          const SizedBox(width: 20),
          _buildActionBtn(
            power: PowerUp.addTube,
            imagePath: 'assets/images/icon_add_tube.jpg',
          ),
        ],
      ),
    );
  }

  int _costOf(PowerUp power) => _controller.costOf(power);

  /// Returns false when the power-up could not take effect on this board state.
  bool _applyPower(PowerUp power, {required bool adFunded}) => switch (power) {
    PowerUp.undo => _controller.undo(adFunded: adFunded),
    PowerUp.hint => _controller.requestHint(adFunded: adFunded),
    PowerUp.shuffle => _controller.shuffleTubes(adFunded: adFunded),
    PowerUp.addTube => _controller.addExtraTube(adFunded: adFunded),
  };

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildActionBtn({
    required PowerUp power,
    String? imagePath,
    IconData? icon,
  }) {
    final int cost = _costOf(power);
    final bool canAfford = _controller.coins >= cost;
    final bool usable = _controller.canUsePowerUp(power);
    final bool payWithCoins = canAfford && usable;

    return BouncingButton(
      onTap: () {
        if (!usable) {
          _showSnack('Not available for the current board.');
          return;
        }
        if (payWithCoins) {
          _applyPower(power, adFunded: false);
          return;
        }
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text(
              'Not Enough Coins',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Watch a short video to use this power-up for free?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  AdManager.showRewardedAd(
                    () {
                      if (!_applyPower(power, adFunded: true)) {
                        _showSnack('This power-up is no longer available.');
                      }
                    },
                    () => _showSnack(
                      'Failed to load Ad. Please try again later.',
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Watch Ad', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      child: Opacity(
        opacity: payWithCoins ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF6C20D6), // Purple background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 2.5,
                ), // Yellow border
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
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
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.yellow,
                      size: 10,
                    ),
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
