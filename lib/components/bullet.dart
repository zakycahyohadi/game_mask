import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pixel_adventure/components/pixel_fighter.dart';
import 'package:pixel_adventure/components/collision_block.dart';

class Bullet extends RectangleComponent with CollisionCallbacks {
  final PixelFighter shooter;
  final double speed;
  final double damage;
  final bool goingRight;

  Bullet({
    required this.shooter,
    required this.speed,
    required this.damage,
    required this.goingRight,
    position,
  }) : super(
          position: position,
          size: Vector2(8, 4),
          anchor: Anchor.center,
        );

  @override
  FutureOr<void> onLoad() async {
    // Bullet visual
    paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    // Add border for visibility
    final border = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = const Color(0xFFFF0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    add(border);

    // Hitbox
    add(RectangleHitbox(
      collisionType: CollisionType.active,
    ));

    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move bullet
    position.x += (goingRight ? 1 : -1) * speed * dt;

    // Remove if out of bounds
    if (position.x < -50 || position.x > 690) {
      removeFromParent();
    }
  }

  @override
  bool onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is PixelFighter && other != shooter && other.isAlive) {
      // Hit enemy player
      other.takeDamage(damage);
      removeFromParent();
      return true;
    }
    // Also collide with walls/blocks
    if (other is CollisionBlock) {
      removeFromParent();
      return true;
    }
    return false;
  }
}
