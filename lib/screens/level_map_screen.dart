import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../core/play_games_service.dart';
import '../content/content_repository.dart';
import '../content/content_types.dart';
import '../game/level_design.dart';
import 'package:games_services/games_services.dart';
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import 'game_screen.dart';
import '../controllers/game_controller.dart' show GameMode;

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key, this.mode = GameMode.classic});

  /// Which ladder this map draws. Classic walks the campaign's chapters; a side
  /// mode walks its own stages, with its own unlocks and its own records, and
  /// the two never read each other's numbers.
  final GameMode mode;

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen>
    with SingleTickerProviderStateMixin {
  /// The height of an ordinary level's row.
  static const double _rowHeight = 140;

  /// A chapter's opening row carries its card as well as its node. The player
  /// walks this trail upward, so the card sits under the node it introduces -
  /// and the row is tall enough to keep it clear of the avatar badge.
  static const double _chapterRowHeight = 280;

  /// The row this map has walked up to: the campaign's furthest unlocked level,
  /// or the stage a side mode's own ladder has reached. Every other row is
  /// judged against it, so one number decides what is done, current and locked.
  int _frontier = 1;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();
  String? _playerImageBase64;
  Map<int, List<LeaderboardScoreData>> _friendsScoresByLevel = {};

  /// Best rating ever earned on each row, so a node can show one star when the
  /// player only just scraped past it. A campaign map reads this by level
  /// number and a mode map by stage number; the two ladders are never drawn on
  /// one screen, and their records are stored apart, so a stage can never borrow
  /// a level's stars.
  Map<int, int> _bestStarsByRow = {};

  /// The chapters whose purse has already been paid, so a card can say so
  /// instead of advertising a reward that is gone.
  List<String> _claimedChapters = const [];

  /// Which mode's ladder this screen walks, or null for the campaign. The id is
  /// the one content names in `modes.json` and the one the records are filed
  /// under.
  String? get _ladderId => switch (widget.mode) {
    GameMode.challenge => 'challenge',
    GameMode.timeAttack => 'timeAttack',
    GameMode.classic => null,
    GameMode.daily => null,
  };

  ModeSpec? get _mode {
    final id = _ladderId;
    return id == null ? null : ContentRepository.content.modeFor(id);
  }

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
    final ladder = _ladderId;
    final level = ladder == null
        ? await StorageService.getLevel()
        : await StorageService.getModeProgress(ladder);
    final stars = ladder == null
        ? await StorageService.getAllLevelStars()
        : await StorageService.getModeStarsByStage(ladder);
    final claimed = await StorageService.getClaimedChapters();
    String? playerImg;
    Map<int, List<LeaderboardScoreData>> friendsMap = {};
    // A friend's score is a campaign level, so it belongs on the campaign's
    // path and nowhere else.
    if (ladder == null && PlayGamesService.isSignedIn) {
      playerImg = await PlayGamesService.getPlayerIconImage();
      final friendsScores = await PlayGamesService.loadFriendsScores();
      if (friendsScores != null) {
        for (var scoreData in friendsScores) {
          final int friendLevel = scoreData.rawScore;
          if (!friendsMap.containsKey(friendLevel)) {
            friendsMap[friendLevel] = [];
          }
          friendsMap[friendLevel]!.add(scoreData);
        }
      }
    }

    // Clearing a ladder records the stage after the one just beaten, and a
    // finite ladder has no stage past its last. Left unclamped the cursor would
    // point at a row that is not drawn and scroll the map off its own end.
    final lastStage = ladder == null
        ? 0
        : ContentRepository.content.stageCountOf(ladder);

    if (mounted) {
      setState(() {
        _frontier = lastStage == 0 ? level : level.clamp(1, lastStage);
        _bestStarsByRow = stars;
        _claimedChapters = claimed;
        _playerImageBase64 = playerImg;
        _friendsScoresByLevel = friendsMap;
      });
    }

    // Auto-scroll to current level after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewportHeight = MediaQuery.of(context).size.height;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || !_scrollController.hasClients) return;
        // Chapter rows are taller than the rest, so the distance to the
        // current one is a sum rather than a multiple.
        final offset =
            (_extentBefore(_frontier) + _rowHeight / 2 - viewportHeight / 2)
                .clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                );
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
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

  /// How many rows this map draws.
  ///
  /// A campaign never ends, so the classic path runs to the next chapter
  /// boundary past the player rather than stopping on a hard-walled 100. A side
  /// mode's ladder is finite and that is the whole point of it: the last stage
  /// is the last row, and the map can be finished.
  int get _totalRows {
    final ladder = _mode;
    if (ladder != null) return ladder.stageCount;
    return max(
      100,
      (_frontier ~/ LevelDesign.levelsPerChapter + 1) *
          LevelDesign.levelsPerChapter,
    );
  }

  /// The chapters exactly as the content set spells them, in the order the map
  /// meets them. Nothing here invents a chapter of its own.
  List<ChapterSpec> get _chapters => ContentRepository.content.chapters;

  /// The chapter owning [row], or null on a mode's map - a stage belongs to a
  /// ladder, not to a chapter of the campaign.
  ChapterSpec? _chapterAt(int row) =>
      _ladderId == null ? ContentRepository.content.chapterFor(row) : null;

  /// The colour this row wears: its chapter's badge, or the whole ladder's for a
  /// side mode, which has one identity rather than ten.
  Color _accentFor(int row) =>
      _chapterAt(row)?.accentColor ??
      _mode?.accentColor ??
      AppColors.primaryButton;

  /// The room behind the path, wearing the grade of the chapter or the mode that
  /// owns where the player has got to.
  ({String image, Color tint}) get _room {
    final ladder = _mode;
    if (ladder != null) {
      return (image: ladder.image, tint: ladder.tintColor);
    }
    final here = ContentRepository.content.chapterFor(_frontier);
    return (
      image: here?.image ?? ChapterSpec.kDefaultImage,
      tint: here?.tintColor ?? Colors.transparent,
    );
  }

  /// The room a row takes. A chapter's opening level, and a ladder's first
  /// stage, carry their card as well as their node.
  double _rowExtent(int row) =>
      _chapterAt(row)?.startsAtLevel == row ||
      (_ladderId != null && row == 1)
      ? _chapterRowHeight
      : _rowHeight;

  /// Distance from row 1 to the top of [row], which is what the reversed list
  /// measures its scroll offset in.
  double _extentBefore(int row) {
    var headers = 0;
    for (final chapter in _chapters) {
      if (_ladderId == null && chapter.startsAtLevel < row) headers++;
    }
    // A mode's map opens with one card, and every row after it sits above that.
    if (_ladderId != null && row > 1) headers = 1;
    return (row - 1) * _rowHeight + headers * (_chapterRowHeight - _rowHeight);
  }

  /// The card a side mode's ladder opens with: what it is, what it asks, and how
  /// many of its stars this account has collected.
  Widget _modeCard(ModeSpec ladder) {
    final earned = _bestStarsByRow.values.fold<int>(
      0,
      (sum, stars) => sum + stars.clamp(0, 3),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ladder.accentColor.withValues(alpha: 0.85),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${ladder.name.toUpperCase()} · '
                  '${ladder.stageCount} STAGES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ladder.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                if (ladder.blurb.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ladder.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/star_3d.png', width: 15, height: 15),
              const SizedBox(width: 4),
              Text(
                '$earned/${ladder.stageCount * 3}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The card a chapter opens with: where the player is, what it asks of them,
  /// and what it pays for getting through it.
  Widget _chapterCard(ChapterSpec chapter) {
    final accent = chapter.accentColor;
    final collected = _claimedChapters.contains(chapter.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CHAPTER ${_chapters.indexOf(chapter) + 1} · '
                  '${chapter.name.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                if (chapter.blurb.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    chapter.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // What the closing board pays, and whether this account has had it.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _rewardLine(
                collected: collected,
                icon: Image.asset(
                  'assets/blender/coin.png',
                  width: 14,
                  height: 14,
                ),
                amount: chapter.rewardCoins,
              ),
              if (chapter.rewardGems > 0)
                _rewardLine(
                  collected: collected,
                  icon: const Icon(
                    Icons.diamond,
                    size: 13,
                    color: Colors.purpleAccent,
                  ),
                  amount: chapter.rewardGems,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardLine({
    required Widget icon,
    required int amount,
    required bool collected,
  }) {
    if (amount <= 0) return const SizedBox.shrink();
    final dim = collected ? Colors.white38 : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (collected)
            const Icon(Icons.check_circle, size: 13, color: Colors.white38)
          else
            icon,
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: TextStyle(
              color: dim,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // The room the player is standing in, wearing the grade of the chapter or
    // the mode that owns where they have got to. One photo reads as several
    // places this way, and a set that names a different image gets it without
    // a code change.
    final room = _room;
    final ladder = _mode;

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
        // A campaign map is a trail of levels; a mode map is a ladder of
        // stages, and the player needs to know which one they are looking at
        // before they tap a number.
        title: Text(
          ladder?.name.toUpperCase() ?? 'LEVELS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: ladder?.accentColor ?? AppColors.primaryButton,
                blurRadius: 20,
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background: the room's own photo under the room's own grade.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: Stack(
                key: ValueKey('${room.image}_${room.tint.toARGB32()}'),
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      room.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: ColoredBox(color: room.tint),
                  ),
                ],
              ),
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
            itemCount: _totalRows,
            itemBuilder: (context, index) {
              final levelNumber = index + 1;
              final isCompleted = levelNumber < _frontier;
              final isCurrent = levelNumber == _frontier;
              final isLocked = levelNumber > _frontier;

              final currentX = _getOffsetX(index, screenWidth);
              final chapter = _chapterAt(levelNumber);
              // The card this row carries, if any: a chapter opens on its first
              // level, a ladder opens on its first stage, and both take the tall
              // row that `_rowExtent` reserves for them.
              Widget? card;
              if (chapter != null && chapter.startsAtLevel == levelNumber) {
                card = _chapterCard(chapter);
              } else if (ladder != null && levelNumber == 1) {
                card = _modeCard(ladder);
              }
              final nextX = index < _totalRows - 1
                  ? _getOffsetX(index + 1, screenWidth)
                  : currentX;
              final prevX = index > 0
                  ? _getOffsetX(index - 1, screenWidth)
                  : currentX;

              return SizedBox(
                height: _rowExtent(levelNumber),
                width: screenWidth,
                child: CustomPaint(
                  painter: PathSegmentPainter(
                    currentX: currentX,
                    nextX: nextX,
                    prevX: prevX,
                    isCompleted: isCompleted,
                    completedColor: _accentFor(levelNumber),
                    isFirst: index == 0,
                    isLast: index == _totalRows - 1,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (card != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10,
                          child: card,
                        ),
                      Positioned(
                        left: currentX - 40, // Centered
                        // The node stays on the row's mid-line, which is where
                        // the path is drawn, whatever sits above it.
                        top: _rowExtent(levelNumber) / 2 - 40,
                        child: _buildLevelNode(
                          levelNumber,
                          isCompleted,
                          isCurrent,
                          isLocked,
                          _friendsScoresByLevel[levelNumber],
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: (index * 50).ms)
                 .fadeIn(duration: 400.ms)
                 .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
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
    List<LeaderboardScoreData>? friends,
  ) {
    // The chapter this level belongs to, worn by the ring and the glow, so a
    // shelf of bottles reads as the same place as its card.
    final accent = _accentFor(level);
    Widget node = GestureDetector(
      onTap: () {
        if (!isLocked) {
          AudioService.playClickSfx();
          Navigator.push(
            context,
            // The row number means a level on the campaign path and a stage on
            // a mode's ladder, so it has to travel with the mode it was read in.
            MaterialPageRoute(
              builder: (context) =>
                  GameScreen(mode: widget.mode, targetLevel: level),
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
          border: Border.all(
            color: isCurrent ? accent : Colors.white,
            width: isCurrent ? 4 : 2,
          ),
          boxShadow: [
            if (isCurrent || isCompleted)
              BoxShadow(
                color: isCompleted ? AppColors.goldCoin : accent,
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
                          Text(
                            level.toString(),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var star = 1; star <= 3; star++)
                                star <= (_bestStarsByRow[level] ?? 0)
                                    ? Image.asset(
                                        'assets/icon/star_3d.png',
                                        width: 15,
                                        height: 15,
                                      )
                                    : const Icon(
                                        Icons.star_border,
                                        size: 15,
                                        color: Colors.black38,
                                      ),
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
            if (friends != null && friends.isNotEmpty)
              Positioned(right: -30, top: -20, child: _buildFriendsAvatars(friends)),
          ],
        ),
      );
    }

    if (friends != null && friends.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          node,
          Positioned(right: -30, top: -20, child: _buildFriendsAvatars(friends)),
        ],
      );
    }

    return node;
  }

  Widget _buildFriendsAvatars(List<LeaderboardScoreData> friends) {
    // Show max 3 friends to avoid crowding
    final displayFriends = friends.take(3).toList();
    return SizedBox(
      width: 30.0 + (displayFriends.length - 1) * 20.0,
      height: 30,
      child: Stack(
        children: List.generate(displayFriends.length, (index) {
          final friend = displayFriends[index];
          final imgBase64 = friend.scoreHolder.iconImage;
          
          return Positioned(
            left: index * 20.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: imgBase64 != null && imgBase64.isNotEmpty
                  ? ClipOval(
                      child: Image.memory(
                        base64Decode(imgBase64.replaceAll('\n', '')),
                        width: 26,
                        height: 26,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) => const CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                      ),
                    )
                  : const CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
            ),
          );
        }),
      ),
    );
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
      child: _playerImageBase64 != null
          ? ClipOval(
              child: Image.memory(
                base64Decode(_playerImageBase64!.replaceAll('\n', '')),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.background,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            )
          : const CircleAvatar(
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

  /// The colour of a trail the player has already walked, which is the colour
  /// of the chapter it belongs to.
  final Color completedColor;
  final bool isFirst;
  final bool isLast;

  PathSegmentPainter({
    required this.currentX,
    required this.nextX,
    required this.prevX,
    required this.isCompleted,
    required this.completedColor,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isCompleted ? completedColor : Colors.white24
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
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.completedColor != completedColor;
  }
}
