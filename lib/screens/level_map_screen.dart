import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import 'game_screen.dart';

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen>
    with SingleTickerProviderStateMixin {
  int _userLevel = 1;
  final int _totalLevels = 100;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _loadData();
  }

  Future<void> _loadData() async {
    final level = await StorageService.getLevel();
    setState(() {
      _userLevel = level;
    });

    // Auto-scroll to current level after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          // Calculate offset (each item is 140 height)
          double offset =
              (_userLevel - 1) * 140.0 -
              (MediaQuery.of(context).size.height / 2) +
              70;
          offset = offset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _getOffsetX(int index, double width) {
    // Creates a wavy path using sine wave
    return (width / 2) + sin(index * 0.8) * (width * 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LEVELS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [Shadow(color: AppColors.primaryButton, blurRadius: 20)],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          // Scrollable Map
          ListView.builder(
            controller: _scrollController,
            reverse: true, // Starts from bottom
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80, // Space for app bar
              bottom: 100, // Bottom padding
            ),
            itemCount: _totalLevels,
            itemBuilder: (context, index) {
              final levelNumber = index + 1;
              final isCompleted = levelNumber < _userLevel;
              final isCurrent = levelNumber == _userLevel;
              final isLocked = levelNumber > _userLevel;

              final currentX = _getOffsetX(index, screenWidth);
              final nextX = index < _totalLevels - 1
                  ? _getOffsetX(index + 1, screenWidth)
                  : currentX;
              final prevX = index > 0
                  ? _getOffsetX(index - 1, screenWidth)
                  : currentX;

              return SizedBox(
                height: 140,
                width: screenWidth,
                child: CustomPaint(
                  painter: PathSegmentPainter(
                    currentX: currentX,
                    nextX: nextX,
                    prevX: prevX,
                    isCompleted: isCompleted,
                    isFirst: index == 0,
                    isLast: index == _totalLevels - 1,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: currentX - 40, // Centered
                        top: 30, // Centered vertically (140 - 80) / 2
                        child: _buildLevelNode(
                          levelNumber,
                          isCompleted,
                          isCurrent,
                          isLocked,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLevelNode(
    int level,
    bool isCompleted,
    bool isCurrent,
    bool isLocked,
  ) {
    Widget node = GestureDetector(
      onTap: () {
        if (!isLocked) {
          AudioService.playClickSfx();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(targetLevel: level),
            ),
          ).then((_) => _loadData()); // Reload level when returning
        }
      },
      child: Container(
        width: isCurrent ? 90 : 80,
        height: isCurrent ? 90 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isLocked
              ? Colors.grey.shade800
              : (isCompleted ? AppColors.goldCoin : AppColors.primaryButton),
          border: Border.all(color: Colors.white, width: isCurrent ? 4 : 2),
          boxShadow: [
            if (isCurrent || isCompleted)
              BoxShadow(
                color: isCompleted
                    ? AppColors.goldCoin
                    : AppColors.primaryButton,
                blurRadius: 20,
                spreadRadius: isCurrent ? 5 : 2,
              ),
          ],
        ),
        child: Center(
          child: isLocked
              ? Image.asset('assets/icon/lock_3d.png', width: 36, height: 36)
              : (isCompleted
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/icon/star_3d.png', width: 28, height: 28),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/icon/star_3d.png', width: 18, height: 18),
                              const SizedBox(width: 8),
                              Image.asset('assets/icon/star_3d.png', width: 18, height: 18),
                            ],
                          ),
                        ],
                      )
                    : Text(
                        level.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      )),
        ),
      ),
    );

    if (isCurrent) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            node,
            Positioned(top: -40, child: _buildPlayerAvatar()),
          ],
        ),
      );
    }

    return node;
  }

  Widget _buildPlayerAvatar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.background,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}

class PathSegmentPainter extends CustomPainter {
  final double currentX;
  final double nextX; // Path to i+1 (top)
  final double prevX; // Path from i-1 (bottom)
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  PathSegmentPainter({
    required this.currentX,
    required this.nextX,
    required this.prevX,
    required this.isCompleted,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isCompleted ? AppColors.goldCoin : Colors.white24
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double centerY = size.height / 2;

    // Draw path downwards to previous node (i-1)
    if (!isFirst) {
      final pathDown = Path();
      pathDown.moveTo(currentX, centerY);
      pathDown.quadraticBezierTo(
        currentX,
        size.height * 0.8,
        prevX,
        size.height,
      );
      _drawDashedLine(canvas, pathDown, paint);
    }

    // Draw path upwards to next node (i+1)
    if (!isLast) {
      final paintUp = Paint()
        ..color = Colors
            .white24 // Always dim for the path leading forward to uncompleted
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final pathUp = Path();
      pathUp.moveTo(currentX, centerY);
      pathUp.quadraticBezierTo(currentX, size.height * 0.2, nextX, 0);
      _drawDashedLine(canvas, pathUp, paintUp);
    }
  }

  void _drawDashedLine(Canvas canvas, Path path, Paint paint) {
    final dashWidth = 15.0;
    final dashSpace = 10.0;

    // A simple approximation for dashing curves in Flutter without metrics:
    // Actually, Flutter doesn't have a built-in dashed path.
    // We can use a simple continuous line with a slightly transparent color
    // or implement path metrics. Let's use path metrics for perfect dashes!

    final pathMetrics = path.computeMetrics();
    final dashedPath = Path();
    for (var metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant PathSegmentPainter oldDelegate) {
    return oldDelegate.currentX != currentX ||
        oldDelegate.isCompleted != isCompleted;
  }
}
