import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:pixel_adventure/components/pixel_fighter.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/mask.dart';
import 'package:pixel_adventure/components/fighting_level.dart';

class PixelFightingGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  @override
  Color backgroundColor() => const Color(0xFF211F30);

  late CameraComponent cam;
  late PixelFighter player1;
  late PixelFighter player2;

  bool playSounds = true;
  double soundVolume = 1.0;

  // Health bars
  late TextComponent player1HealthText;
  late TextComponent player2HealthText;
  late RectangleComponent player1HealthBar;
  late RectangleComponent player2HealthBar;

  String currentLevel = 'Level-01';
  bool gameOver = false;

  @override
  FutureOr<void> onLoad() async {
    await images.loadAllImages();

    _loadFightingLevel();

    return super.onLoad();
  }

  void _loadFightingLevel() {
    // Create players
    player1 = PixelFighter(
      playerIndex: 1,
      character: 'Mask Dude',
      position: Vector2(100, 100), // Will be set by spawn point
    );

    player2 = PixelFighter(
      playerIndex: 2,
      character: 'Ninja Frog',
      position: Vector2(500, 100), // Will be set by spawn point
    );

    // Create fighting level (uses Tiled map)
    FightingLevel fightingLevel = FightingLevel(
      levelName: currentLevel,
      player1: player1,
      player2: player2,
    );

    cam = CameraComponent.withFixedResolution(
      world: fightingLevel,
      width: 640,
      height: 360,
    );
    cam.viewfinder.anchor = Anchor.topLeft;

    addAll([cam, fightingLevel]);

    _setupUI();
  }

  void _setupUI() {
    // Player 1 Health Bar (Top Left)
    player1HealthBar = RectangleComponent(
      position: Vector2(20, 20),
      size: Vector2(200, 20),
      paint: Paint()..color = const Color(0xFF00FF00),
    );
    cam.viewport.add(player1HealthBar);

    player1HealthText = TextComponent(
      text: 'P1: 100',
      position: Vector2(20, 45),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(player1HealthText);

    // Player 2 Health Bar (Top Right)
    player2HealthBar = RectangleComponent(
      position: Vector2(420, 20),
      size: Vector2(200, 20),
      paint: Paint()..color = const Color(0xFF00FF00),
    );
    cam.viewport.add(player2HealthBar);

    player2HealthText = TextComponent(
      text: 'P2: 100',
      position: Vector2(420, 45),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(player2HealthText);

    // Controls text
    final controlsText = TextComponent(
      text: 'P1: WASD+Space | P2: Arrows+RShift | W/Up=Punch | S/Down=Kick',
      position: Vector2(320, 340),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 10,
        ),
      ),
    );
    cam.viewport.add(controlsText);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!gameOver) {
      // Check hits between players
      if (player1.isAlive && player2.isAlive) {
        player1.checkHit(player2);
        player2.checkHit(player1);
      }

      // Update health bars
      _updateHealthBars();

      // Check for winner
      _checkGameOver();
    }
  }

  void _updateHealthBars() {
    // Player 1
    player1HealthBar.size.x = (player1.health / 100) * 200;
    player1HealthText.text = 'P1: ${player1.health.toInt()}';

    // Change color based on health
    if (player1.health > 60) {
      player1HealthBar.paint.color = const Color(0xFF00FF00); // Green
    } else if (player1.health > 30) {
      player1HealthBar.paint.color = const Color(0xFFFFFF00); // Yellow
    } else {
      player1HealthBar.paint.color = const Color(0xFFFF0000); // Red
    }

    // Player 2
    player2HealthBar.size.x = (player2.health / 100) * 200;
    player2HealthText.text = 'P2: ${player2.health.toInt()}';

    if (player2.health > 60) {
      player2HealthBar.paint.color = const Color(0xFF00FF00);
    } else if (player2.health > 30) {
      player2HealthBar.paint.color = const Color(0xFFFFFF00);
    } else {
      player2HealthBar.paint.color = const Color(0xFFFF0000);
    }
  }

  void _checkGameOver() {
    if (!player1.isAlive && !gameOver) {
      gameOver = true;
      _showWinner('Player 2');
    } else if (!player2.isAlive && !gameOver) {
      gameOver = true;
      _showWinner('Player 1');
    }
  }

  void _showWinner(String winner) {
    final winnerText = TextComponent(
      text: '$winner Wins!',
      position: Vector2(320, 180),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(winnerText);

    final restartText = TextComponent(
      text: 'Press R to Restart',
      position: Vector2(320, 220),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
        ),
      ),
    );
    cam.viewport.add(restartText);
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (gameOver && keysPressed.contains(LogicalKeyboardKey.keyR)) {
      restartGame();
      return KeyEventResult.handled;
    }
    return super.onKeyEvent(event, keysPressed);
  }

  void restartGame() {
    gameOver = false;

    // Remove all components
    world.removeAll(world.children);
    cam.viewport.removeAll(cam.viewport.children);

    // Reload level
    _loadFightingLevel();
  }
}
