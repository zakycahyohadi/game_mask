import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:pixel_adventure/components/pixel_fighter.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/mask.dart';
import 'package:pixel_adventure/components/fighting_level.dart';
import 'package:pixel_adventure/components/character_selection.dart';

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
  
  // Ammo and shield displays
  late TextComponent player1AmmoText;
  late TextComponent player2AmmoText;
  late TextComponent player1ShieldText;
  late TextComponent player2ShieldText;

  String currentLevel = 'Level-01';
  bool gameOver = false;
  bool characterSelectionDone = false;
  StreamSubscription<GamepadEvent>? _gamepadSubscription;
  
  // Player 1 = Keyboard (WASD), Player 2 = PS4 Controller
  // No controller assignment needed - gamepad is only for Player 2

  @override
  FutureOr<void> onLoad() async {
    await images.loadAllImages();

    // Initialize gamepad support for Player 2 (PS4 Controller)
    _initGamepad();

    // Show character selection first
    _showCharacterSelection();

    return super.onLoad();
  }

  @override
  void onRemove() {
    // Cancel gamepad subscription when game is removed
    _gamepadSubscription?.cancel();
    super.onRemove();
  }
  
  void _initGamepad() {
    _gamepadSubscription = Gamepads.events.listen((event) {
      // 🎮 GAMEPAD KHUSUS PLAYER 1 (HUMAN PLAYER)
      // ==========================================
      // P1 dikontrol dengan PS controller
      // P2 adalah COMPUTER (AI) - tidak perlu gamepad
      
      if (!characterSelectionDone || gameOver) return;
      
      // PASTIKAN: Hanya player1 yang dikontrol dengan gamepad
      // Player2 adalah computer/AI - tidak perlu input gamepad

      // JUMP (X / Cross) - support double jump
      if (event.value > 0.5 &&
          (event.key == 'cross' ||
           event.key == 'button_0' ||
           event.key == 'xmark.circle' ||
           event.key == 'a.button' ||
           event.key.toLowerCase().contains('cross') ||
           event.key.toLowerCase().contains('x'))) {
        // Allow jump if on ground or can double jump (handled in PixelFighter)
        player1.hasJumped = true;
      }

      // SHOOT (R2 ONLY) - hanya R2 untuk shoot
      // R2 bisa berupa analog trigger (0.0-1.0) atau digital button
      final isR2Pressed = event.value > 0.5 &&
          (event.key == 'r2' ||
           event.key == 'r.trigger' ||
           event.key == 'button_7' ||
           event.key == 'button_8' ||
           event.key == 'right.trigger' ||
           event.key == 'right.trigger.button' ||
           event.key.toLowerCase() == 'r2' ||
           event.key.toLowerCase().contains('r2') ||
           event.key.toLowerCase().contains('right.trigger') ||
           (event.key.toLowerCase().contains('trigger') && 
            event.key.toLowerCase().contains('right')));
      
      if (isR2Pressed) {
        if (player1.shootCooldown <= 0 && player1.ammo > 0) {
          player1.shoot();
        }
      }

      // MOVE (Left Stick X / D-Pad / Arrow)
      // Analog Stick X-axis
      if (event.key == 'l.joystick - xAxis' || 
          event.key == 'l.joystick.button.xAxis' ||
          event.key == 'axis_0' ||
          event.key == 'axis 0' ||
          event.key == 'left.joystick.x' ||
          (event.key.startsWith('axis') && !event.key.contains('yAxis') && !event.key.contains('y'))) {
        if (event.value > 0.2) {
          player1.isMovingRight = true;
          player1.isMovingLeft = false;
        } else if (event.value < -0.2) {
          player1.isMovingLeft = true;
          player1.isMovingRight = false;
        } else {
          // Dead zone - stop movement when stick is centered
          player1.isMovingLeft = false;
          player1.isMovingRight = false;
        }
      }
      
      // D-Pad Left / Arrow Left
      if ((event.key.contains('dpad') && event.key.contains('left')) ||
          event.key == 'button_14' ||
          event.key == 'dpad.left' ||
          event.key.toLowerCase().contains('arrow.left')) {
        if (event.value > 0.5) {
          player1.isMovingLeft = true;
          player1.isMovingRight = false;
        } else {
          player1.isMovingLeft = false;
        }
      }
      
      // D-Pad Right / Arrow Right
      if ((event.key.contains('dpad') && event.key.contains('right')) ||
          event.key == 'button_15' ||
          event.key == 'dpad.right' ||
          event.key.toLowerCase().contains('arrow.right')) {
        if (event.value > 0.5) {
          player1.isMovingRight = true;
          player1.isMovingLeft = false;
        } else {
          player1.isMovingRight = false;
        }
      }
    });
  }
  
  void _showCharacterSelection() {
    final selectionScreen = CharacterSelectionScreen();
    add(selectionScreen);
  }
  
  void startGameWithCharacters(String char1, String char2) {
    characterSelectionDone = true;
    
    // No controller assignment needed - Player 1 uses keyboard, Player 2 uses gamepad
    
    _loadFightingLevel(char1, char2);
  }

  void _loadFightingLevel(String char1, String char2) {
    // Create players with selected characters
    player1 = PixelFighter(
      playerIndex: 1,
      character: char1,
      position: Vector2(100, 100), // Will be set by spawn point
    );

    player2 = PixelFighter(
      playerIndex: 2,
      character: char2,
      position: Vector2(500, 100), // Will be set by spawn point
    );

    // Set P1 sebagai target untuk AI (P2)
    // AI akan auto attack P1
    player2.setTargetPlayer(player1);

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
    
    // Ensure players are added to world for keyboard handling
    // Players are already added in FightingLevel, but ensure they're accessible
    if (!fightingLevel.children.contains(player1)) {
      fightingLevel.add(player1);
    }
    if (!fightingLevel.children.contains(player2)) {
      fightingLevel.add(player2);
    }

    _setupUI();
  }

  void _setupUI() {
    // Player 1 UI Panel (Top Left) - dengan background box
    final p1PanelBg = RectangleComponent(
      position: Vector2(10, 10),
      size: Vector2(220, 110),
      paint: Paint()
        ..color = const Color(0x80000000) // Semi-transparent black
        ..style = PaintingStyle.fill,
    );
    cam.viewport.add(p1PanelBg);
    
    final p1PanelBorder = RectangleComponent(
      position: Vector2(10, 10),
      size: Vector2(220, 110),
      paint: Paint()
        ..color = const Color(0xFF0088FF) // Blue border for P1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    cam.viewport.add(p1PanelBorder);

    // Player 1 Label
    final p1Label = TextComponent(
      text: 'PLAYER 1',
      position: Vector2(20, 15),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF0088FF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(p1Label);

    // Player 1 Health Bar Background
    final p1HealthBg = RectangleComponent(
      position: Vector2(20, 30),
      size: Vector2(200, 18),
      paint: Paint()..color = const Color(0x40FFFFFF),
    );
    cam.viewport.add(p1HealthBg);

    // Player 1 Health Bar
    player1HealthBar = RectangleComponent(
      position: Vector2(20, 30),
      size: Vector2(200, 18),
      paint: Paint()..color = const Color(0xFF00FF00),
    );
    cam.viewport.add(player1HealthBar);

    player1HealthText = TextComponent(
      text: '100 / 100',
      position: Vector2(120, 32),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(player1HealthText);

    // Player 1 Ammo
    player1AmmoText = TextComponent(
      text: '🔫 Ammo: 30/30',
      position: Vector2(20, 52),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
        ),
      ),
    );
    cam.viewport.add(player1AmmoText);
    
    // Player 1 Shield
    player1ShieldText = TextComponent(
      text: '🛡️ Shield: 0',
      position: Vector2(20, 68),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00FFFF),
          fontSize: 11,
        ),
      ),
    );
    cam.viewport.add(player1ShieldText);

    // Player 2 UI Panel (Top Right) - dengan background box
    final p2PanelBg = RectangleComponent(
      position: Vector2(410, 10),
      size: Vector2(220, 110),
      paint: Paint()
        ..color = const Color(0x80000000) // Semi-transparent black
        ..style = PaintingStyle.fill,
    );
    cam.viewport.add(p2PanelBg);
    
    final p2PanelBorder = RectangleComponent(
      position: Vector2(410, 10),
      size: Vector2(220, 110),
      paint: Paint()
        ..color = const Color(0xFFFF0000) // Red border for P2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    cam.viewport.add(p2PanelBorder);

    // Player 2 Label
    final p2Label = TextComponent(
      text: 'PLAYER 2',
      position: Vector2(420, 15),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF0000),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(p2Label);

    // Player 2 Health Bar Background
    final p2HealthBg = RectangleComponent(
      position: Vector2(420, 30),
      size: Vector2(200, 18),
      paint: Paint()..color = const Color(0x40FFFFFF),
    );
    cam.viewport.add(p2HealthBg);

    // Player 2 Health Bar
    player2HealthBar = RectangleComponent(
      position: Vector2(420, 30),
      size: Vector2(200, 18),
      paint: Paint()..color = const Color(0xFF00FF00),
    );
    cam.viewport.add(player2HealthBar);

    player2HealthText = TextComponent(
      text: '100 / 100',
      position: Vector2(520, 32),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(player2HealthText);

    // Player 2 Ammo
    player2AmmoText = TextComponent(
      text: '🔫 Ammo: 30/30',
      position: Vector2(420, 52),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
        ),
      ),
    );
    cam.viewport.add(player2AmmoText);
    
    // Player 2 Shield
    player2ShieldText = TextComponent(
      text: '🛡️ Shield: 0',
      position: Vector2(420, 68),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00FFFF),
          fontSize: 11,
        ),
      ),
    );
    cam.viewport.add(player2ShieldText);

    // Controls text - more visible and clear
    final controlsP1 = TextComponent(
      text: 'PLAYER 1 (PS Controller): Analog/Arrow = Move | X = Jump | R2 = Shoot',
      position: Vector2(320, 320),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF0088FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(controlsP1);
    
    final controlsP2 = TextComponent(
      text: 'PLAYER 2 (COMPUTER): AI - Automatic',
      position: Vector2(320, 340),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF0000),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cam.viewport.add(controlsP2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!gameOver && characterSelectionDone) {
      // P2 punya physics sendiri - tidak sync posisi Y dengan P1
      // P2 bisa jump sendiri dengan X button di PS controller
      // P2 bisa mendarat di tanah sendiri
      // TIDAK ada sync posisi Y - P2 punya kontrol penuh untuk jump dan landing
      
      // Update health bars
      _updateHealthBars();
      
      // Update ammo and shield displays
      _updateAmmoAndShield();

      // Check for winner
      _checkGameOver();
    }
  }

  void _updateHealthBars() {
    // Player 1
    final p1HealthPercent = player1.health / player1.maxHealth;
    player1HealthBar.size.x = p1HealthPercent * 200;
    player1HealthText.text = '${player1.health.toInt()} / ${player1.maxHealth.toInt()}';

    // Change color based on health
    if (p1HealthPercent > 0.6) {
      player1HealthBar.paint.color = const Color(0xFF00FF00); // Green
    } else if (p1HealthPercent > 0.3) {
      player1HealthBar.paint.color = const Color(0xFFFFFF00); // Yellow
    } else {
      player1HealthBar.paint.color = const Color(0xFFFF0000); // Red
    }

    // Player 2
    final p2HealthPercent = player2.health / player2.maxHealth;
    player2HealthBar.size.x = p2HealthPercent * 200;
    player2HealthText.text = '${player2.health.toInt()} / ${player2.maxHealth.toInt()}';

    if (p2HealthPercent > 0.6) {
      player2HealthBar.paint.color = const Color(0xFF00FF00);
    } else if (p2HealthPercent > 0.3) {
      player2HealthBar.paint.color = const Color(0xFFFFFF00);
    } else {
      player2HealthBar.paint.color = const Color(0xFFFF0000);
    }
  }
  
  void _updateAmmoAndShield() {
    player1AmmoText.text = '🔫 Ammo: ${player1.ammo}/${player1.maxAmmo}';
    player1ShieldText.text = '🛡️ Shield: ${player1.shield.toInt()}';
    
    player2AmmoText.text = '🔫 Ammo: ${player2.ammo}/${player2.maxAmmo}';
    player2ShieldText.text = '🛡️ Shield: ${player2.shield.toInt()}';
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
    // Only handle R key for restart when game is over
    if (gameOver && keysPressed.contains(LogicalKeyboardKey.keyR)) {
      restartGame();
      return KeyEventResult.handled;
    }
    
    // ═══════════════════════════════════════════════════════
    // NO KEYBOARD CONTROLS
    // =======================================================
    // P1 dikontrol dengan PS controller (gamepad)
    // P2 adalah COMPUTER (AI) - tidak perlu keyboard
    // ═══════════════════════════════════════════════════════
    
    // Tidak ada keyboard controls - semua kontrol via gamepad untuk P1
    // P2 adalah computer/AI yang dikontrol otomatis
    
    // Pass other keyboard events to children
    return super.onKeyEvent(event, keysPressed);
  }

  void restartGame() {
    gameOver = false;
    characterSelectionDone = false;

    // No controller assignment needed - Player 1 uses keyboard, Player 2 uses gamepad

    // Remove all components
    if (cam.isMounted) {
    world.removeAll(world.children);
    cam.viewport.removeAll(cam.viewport.children);
      cam.removeFromParent();
    }
    removeAll(children);

    // Show character selection again
    _showCharacterSelection();
  }
}
