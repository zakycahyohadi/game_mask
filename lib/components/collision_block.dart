import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CollisionBlock extends PositionComponent {
  bool isPlatform;
  
  CollisionBlock({
    position,
    size,
    this.isPlatform = false,
  }) : super(
          position: position,
          size: size,
        ) {
    debugMode = true; // AKTIFKAN INI untuk melihat collision boxes
  }

  @override
  void render(Canvas canvas) {
    // Draw collision boxes
    final paint = Paint()
      ..color = isPlatform ? Colors.yellow.withOpacity(0.5) : Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(size.toRect(), paint);
    super.render(canvas);
  }
}