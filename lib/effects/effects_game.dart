import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// The Flame layer that paints the board's effects.
///
/// The bottles, the shop and the settings stay Flutter widgets: what this
/// game loop is for is the stuff that has no business living in the widget
/// tree - hundreds of short-lived, physics-driven particles that would
/// otherwise rebuild the board every frame.
class EffectsGame extends FlameGame {
  EffectsGame({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  /// How many bursts are still on screen. Zero means the layer is idle.
  int get liveEffects =>
      world.children.whereType<ParticleSystemComponent>().length;

  @override
  Future<void>? onLoad() async {
    await super.onLoad();
    // Flame centres the world on the screen by default. This layer works in
    // screen pixels - a burst is aimed at a bottle's coordinates - so the
    // origin has to be the top-left of the canvas.
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  /// The level-win fireworks: tumbling strips of the level's own liquids,
  /// thrown up from [at] and pulled back down by gravity.
  void celebrate({required Offset at, required List<Color> colors}) {
    if (colors.isEmpty) return;
    world.add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        particle: ComposedParticle(
          // The system cleans itself up once the longest strip has landed.
          lifespan: 2.2,
          applyLifespanToChildren: false,
          children: List.generate(52, (_) => _strip(colors)),
        ),
      ),
    );
  }

  Particle _strip(List<Color> colors) {
    final life = 1.1 + _rng.nextDouble() * 1.1;
    final color = colors[_rng.nextInt(colors.length)];
    final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 3.1;
    final speed = 150 + _rng.nextDouble() * 260;
    final width = 2.4 + _rng.nextDouble() * 3.2;
    final paint = Paint()..style = PaintingStyle.fill;

    return AcceleratedParticle(
      lifespan: life,
      speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
      // Screen space, so a positive y is downwards: the strips come up and fall.
      acceleration: Vector2(0, 560),
      child: RotatingParticle(
        lifespan: life,
        from: _rng.nextDouble() * math.pi,
        to: (_rng.nextDouble() - 0.5) * 10,
        child: ComputedParticle(
          lifespan: life,
          renderer: (canvas, particle) {
            final t = particle.progress.clamp(0.0, 1.0);
            paint.color = color.withValues(alpha: (1.0 - t * t) * 0.95);
            canvas.drawRect(
              Rect.fromLTWH(-width, -width * 0.45, width * 2, width * 0.9),
              paint,
            );
          },
        ),
      ),
    );
  }

  @override
  Color backgroundColor() => const Color(0x00000000);
}
