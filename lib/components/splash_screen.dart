import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:pixel_adventure/pixel_fighting.dart';
import 'package:pixel_adventure/components/character_selection.dart';

class SplashScreen extends Component with HasGameRef<PixelFightingGame> {
  @override
  FutureOr<void> onLoad() async {
    // Load splash images (path relatif dari assets/images/)
    // Gambar sudah di-load oleh loadAllImages(), tapi kita load lagi untuk memastikan
    try {
      await game.images.load('splash/Home Screen.png.jpeg');
      await game.images.load('splash/ggj splash-landscape.png');
    } catch (e) {
      // Jika sudah ter-load, ignore error
      print('Splash images already loaded or error: $e');
    }

    // Show first splash image
    _showFirstSplash();
  }

  void _showFirstSplash() async {
    // First splash image - full screen
    final firstSplash = SpriteComponent(
      sprite: Sprite(game.images.fromCache('splash/Home Screen.png.jpeg')),
      size: Vector2(game.size.x, game.size.y),
      position: Vector2.zero(),
      anchor: Anchor.topLeft,
    );
    
    // Start with opacity 0 for fade in
    firstSplash.opacity = 0;
    add(firstSplash);

    // Fade in effect
    firstSplash.add(
      OpacityEffect.to(
        1.0,
        EffectController(
          duration: 0.8,
          curve: Curves.easeIn,
        ),
      ),
    );

    // Wait for fade in + display time
    await Future.delayed(const Duration(milliseconds: 2000));

    // Fade out effect
    firstSplash.add(
      OpacityEffect.to(
        0.0,
        EffectController(
          duration: 0.6,
          curve: Curves.easeOut,
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    firstSplash.removeFromParent();

    // Show second splash image
    _showSecondSplash();
  }

  void _showSecondSplash() async {
    // Second splash image - full screen
    final secondSplash = SpriteComponent(
      sprite: Sprite(game.images.fromCache('splash/ggj splash-landscape.png')),
      size: Vector2(game.size.x, game.size.y),
      position: Vector2.zero(),
      anchor: Anchor.topLeft,
    );
    
    // Start with opacity 0 for fade in
    secondSplash.opacity = 0;
    add(secondSplash);

    // Fade in effect
    secondSplash.add(
      OpacityEffect.to(
        1.0,
        EffectController(
          duration: 0.8,
          curve: Curves.easeIn,
        ),
      ),
    );

    // Wait for fade in + display time
    await Future.delayed(const Duration(milliseconds: 2000));

    // Fade out effect
    secondSplash.add(
      OpacityEffect.to(
        0.0,
        EffectController(
          duration: 0.6,
          curve: Curves.easeOut,
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    secondSplash.removeFromParent();

    // Transition to character selection
    _goToCharacterSelection();
  }

  void _goToCharacterSelection() {
    // Remove splash screen
    removeFromParent();

    // Show character selection
    game.showCharacterSelection();
  }
}
