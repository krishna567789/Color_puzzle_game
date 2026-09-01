import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_service.dart';

class CoinAnimationUtils {
  /// Shows a flying coin animation from `startOffset` to `endOffset`.
  /// Uses an Overlay so it appears above all other widgets and dialogs.
  static void showCoinAnimation({
    required BuildContext context,
    required Offset startOffset,
    required Offset endOffset,
    int coinCount = 10,
    VoidCallback? onComplete,
  }) {
    final overlay = Overlay.of(context);
    List<OverlayEntry> entries = [];
    int completedCoins = 0;

    void onCoinComplete() {
      completedCoins++;
      if (completedCoins == coinCount) {
        for (var entry in entries) {
          entry.remove();
        }
        if (onComplete != null) onComplete();
      }
    }

    final random = Random();

    for (int i = 0; i < coinCount; i++) {
      // Add slight randomness to start position for explosion effect
      final spreadX = (random.nextDouble() - 0.5) * 100;
      final spreadY = (random.nextDouble() - 0.5) * 100;
      final specificStart = Offset(startOffset.dx + spreadX, startOffset.dy + spreadY);

      // Delay each coin slightly for a stream effect
      final delay = Duration(milliseconds: i * 50);

      final entry = OverlayEntry(
        builder: (context) => _AnimatedCoin(
          startOffset: startOffset, // Start from exact center first
          explodeOffset: specificStart, // Explode to here
          endOffset: endOffset, // Finally fly to here
          delay: delay,
          onComplete: onCoinComplete,
        ),
      );
      entries.add(entry);
    }

    // Play a single fast collection sound
    AudioService.playWinSfx(); // Or a specific coin collect sound if available

    for (var entry in entries) {
      overlay.insert(entry);
    }
  }

  /// Helper to get the center offset of a widget using its GlobalKey
  static Offset getOffsetFromKey(GlobalKey key, {Offset fallback = Offset.zero}) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);
      return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
    }
    return fallback;
  }
}

class _AnimatedCoin extends StatefulWidget {
  final Offset startOffset;
  final Offset explodeOffset;
  final Offset endOffset;
  final Duration delay;
  final VoidCallback onComplete;

  const _AnimatedCoin({
    Key? key,
    required this.startOffset,
    required this.explodeOffset,
    required this.endOffset,
    required this.delay,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_AnimatedCoin> createState() => _AnimatedCoinState();
}

class _AnimatedCoinState extends State<_AnimatedCoin> with TickerProviderStateMixin {
  late AnimationController _explodeController;
  late AnimationController _flyController;
  late Animation<Offset> _explodeAnimation;
  late Animation<Offset> _flyAnimation;
  late Animation<double> _scaleAnimation;

  bool _isExploding = false;
  bool _isFlying = false;

  @override
  void initState() {
    super.initState();

    _explodeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _explodeAnimation = Tween<Offset>(
      begin: widget.startOffset,
      end: widget.explodeOffset,
    ).animate(CurvedAnimation(parent: _explodeController, curve: Curves.easeOutCubic));

    _flyAnimation = Tween<Offset>(
      begin: widget.explodeOffset,
      end: widget.endOffset,
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeInOutCubic));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _flyController, curve: Curves.linear));

    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(widget.delay);
    if (!mounted) return;

    setState(() => _isExploding = true);
    await _explodeController.forward();
    
    if (!mounted) return;

    setState(() {
      _isExploding = false;
      _isFlying = true;
    });
    
    AudioService.playClickSfx(); // Optional: small tick for each coin arriving
    
    await _flyController.forward();

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _explodeController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExploding && !_isFlying) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_explodeController, _flyController]),
      builder: (context, child) {
        Offset currentPos = _isFlying ? _flyAnimation.value : _explodeAnimation.value;
        double scale = _isFlying ? (1.5 - _flyController.value * 1.0) : 1.0;

        return Positioned(
          left: currentPos.dx - 15, // Center the 30x30 coin
          top: currentPos.dy - 15,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Image.asset(
        'assets/blender/coin.png',
        width: 30,
        height: 30,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.monetization_on,
          color: Colors.amber,
          size: 30,
        ),
      ),
    );
  }
}
