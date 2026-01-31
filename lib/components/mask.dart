import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:pixel_adventure/components/aura_effect.dart';

class Mask extends PositionComponent
    with HasGameReference, CollisionCallbacks {
  final String mask;

  Mask({
    this.mask = 'red-mask',
    position,
    size,
  }) : super(
          position: position,
          size: size ?? Vector2.all(32),
        );

  bool collected = false;

  late double _baseY;
  double _floatTime = 0;
  static const double _floatAmplitude = 3;
  static const double _floatSpeed = 4;

  @override
  FutureOr<void> onLoad() {
    priority = -1;

    _baseY = position.y;

    add(
      RectangleHitbox(
        collisionType: CollisionType.passive,
      ),
    );

    // Shadow - drawn first (behind mask)
    final shadow = RectangleComponent(
      size: Vector2(size.x * 0.7, 6),
      position: Vector2((size.x - size.x * 0.7) / 2, size.y - 8),
      paint: Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );
    add(shadow);

    // Mask sprite using actual image
    final maskSprite = SpriteComponent(
      sprite: Sprite(game.images.fromCache('Items/mask/$mask.png')),
      size: size,
      position: Vector2.zero(),
    );
    add(maskSprite);

    // Optional: Add glow effect around mask
    final glowColor = _getMaskGlowColor();
    final glow = CircleComponent(
      radius: size.x / 1.5,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      paint: Paint()
        ..color = glowColor.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    add(glow);

    return super.onLoad();
  }

  // Get glow color based on mask type
  Color _getMaskGlowColor() {
    switch (mask.toLowerCase()) {
      case 'red-mask':
        return Colors.red;
      case 'gold-mask':
        return const Color(0xFFFFD700);
      case 'blue-mask':
        return Colors.blue;
      case 'green-mask':
        return Colors.green;
      default:
        return Colors.cyan;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!collected) {
      _floatTime += dt;
      position.y = _baseY + sin(_floatTime * _floatSpeed) * _floatAmplitude;
    }
  }

  void collidedWithPlayer(dynamic collector) async {
    if (!collected) {
      collected = true;

      // Play sound
      try {
        final playSounds = (game as dynamic).playSounds ?? true;
        final soundVolume = (game as dynamic).soundVolume ?? 1.0;
        if (playSounds) {
          FlameAudio.play('jump.wav', volume: soundVolume);
        }
      } catch (_) {}

      // Add aura to player
      if (collector != null) {
        try {
          collector.addAura(mask);
        } catch (_) {}
      }

      // Remove mask sprite and shadow
      removeAll(children.query<SpriteComponent>());
      removeAll(children.query<RectangleComponent>());
      removeAll(children.query<CircleComponent>());

      // Create collection effect - star burst
      final glowColor = _getMaskGlowColor();
      for (int i = 0; i < 8; i++) {
        final angle = (i * pi / 4);
        final particle = CircleComponent(
          radius: 4,
          position: Vector2(size.x / 2, size.y / 2),
          anchor: Anchor.center,
          paint: Paint()
            ..color = glowColor
            ..style = PaintingStyle.fill,
        );
        add(particle);
        
        // Animate particle outward
        final endPos = Vector2(
          size.x / 2 + cos(angle) * 25,
          size.y / 2 + sin(angle) * 25,
        );
        particle.add(
          MoveEffect.to(
            endPos,
            EffectController(duration: 0.4),
          ),
        );
        particle.add(
          OpacityEffect.fadeOut(
            EffectController(duration: 0.4),
          ),
        );
      }

      // Center burst effect
      final centerBurst = CircleComponent(
        radius: 8,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      add(centerBurst);
      
      centerBurst.add(
        ScaleEffect.by(
          Vector2.all(3),
          EffectController(duration: 0.4),
        ),
      );
      centerBurst.add(
        OpacityEffect.fadeOut(
          EffectController(duration: 0.4),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      removeFromParent();

      // Respawn after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (parent != null) {
          final newMask = Mask(
            mask: mask,
            position: Vector2(position.x, _baseY),
            size: size,
          );
          parent!.add(newMask);
        }
      });
    }
  }
}