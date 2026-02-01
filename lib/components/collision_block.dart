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
    debugMode = false; // Disabled - no coordinate lines
  }

  // Removed custom render to hide collision boxes and coordinate lines
}