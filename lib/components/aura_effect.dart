import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class AuraEffect extends PositionComponent {
  final Color color;
  final double duration;
  double _elapsed = 0;
  bool _fadeOut = false;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  AuraEffect({
    required this.color,
    this.duration = 3.0,
    required Vector2 size,
  }) : super(
          size: size,
          anchor: Anchor.center,
        ) {
    // Create particles
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        angle: _random.nextDouble() * 2 * pi,
        speed: 20 + _random.nextDouble() * 30,
        size: 2 + _random.nextDouble() * 3,
        offset: _random.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;

    if (_elapsed >= duration - 0.5 && !_fadeOut) {
      _fadeOut = true;
    }

    if (_elapsed >= duration) {
      removeFromParent();
    }

    // Update particles
    for (var particle in _particles) {
      particle.update(dt);
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final opacity = _fadeOut 
        ? max(0.0, 0.5 - ((_elapsed - (duration - 0.5)) / 0.5) * 0.5)
        : 0.5;

    // Draw main glow
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      paint,
    );

    // Draw inner bright core
    paint.color = color.withOpacity(opacity);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 3,
      paint,
    );

    // Draw particles
    final particlePaint = Paint()..color = color.withOpacity(opacity);
    for (var particle in _particles) {
      final x = size.x / 2 + cos(particle.angle) * particle.distance;
      final y = size.y / 2 + sin(particle.angle) * particle.distance;
      canvas.drawCircle(Offset(x, y), particle.size, particlePaint);
    }

    super.render(canvas);
  }
}

class _Particle {
  double angle;
  double speed;
  double distance = 0;
  double size;
  double offset;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.offset,
  });

  void update(double dt) {
    distance += speed * dt;
    // Oscillate outward
    angle += dt * 0.5;
  }
}