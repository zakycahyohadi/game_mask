import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:pixel_adventure/components/jump_button.dart';
import 'package:pixel_adventure/components/player.dart';
import 'package:pixel_adventure/components/level.dart';

class PixelAdventure extends FlameGame
    with
        HasKeyboardHandlerComponents,
        DragCallbacks,
        HasCollisionDetection,
        TapCallbacks {
  @override
  Color backgroundColor() => const Color(0xFF211F30);
  late CameraComponent cam;
  Player player = Player(character: 'Mask Dude');
  JoystickComponent? joystick;
  bool showControls = false; // Set false untuk desktop (keyboard only)
  bool playSounds = true;
  double soundVolume = 1.0;
  List<String> levelNames = ['Level-01', 'Level-02'];
  int currentLevelIndex = 0;
  StreamSubscription<GamepadEvent>? _gamepadSubscription;

  @override
  FutureOr<void> onLoad() async {
    // Load all images into cache
    await images.loadAllImages();

    _loadLevel();

    // Only show touch controls on mobile
    if (showControls) {
      addJoystick();
      add(JumpButton());
    }

    // Initialize gamepad support (PS Controller)
    _initGamepad();

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
      // ═══════════════════════════════════════════════════════
      // PS CONTROLLER - JUMP BUTTON (X / Cross)
      // ═══════════════════════════════════════════════════════
      if (event.key == 'xmark.circle' || 
          event.key == 'button_0' ||
          event.key == 'cross' ||
          event.key == 'a.button') {
        if (event.value > 0.5) {
          player.hasJumped = true;
        } else {
          player.hasJumped = false;
        }
      }
      
      // ═══════════════════════════════════════════════════════
      // PS CONTROLLER - LEFT ANALOG STICK (Horizontal Movement)
      // ═══════════════════════════════════════════════════════
      if (event.key == 'l.joystick - xAxis' || 
          event.key == 'l.joystick.button.xAxis' ||
          event.key == 'dpad - xAxis' || 
          event.key == 'axis_0' ||
          event.key == 'axis 0' ||
          event.key.startsWith('axis')) {
        
        // Dead zone 0.2 for analog precision
        if (event.value > 0.2) {
          player.horizontalMovement = 1; // Right
        } else if (event.value < -0.2) {
          player.horizontalMovement = -1; // Left
        } else {
          player.horizontalMovement = 0; // Idle
        }
      }
      
      // ═══════════════════════════════════════════════════════
      // PS CONTROLLER - D-PAD (Alternative movement)
      // ═══════════════════════════════════════════════════════
      // D-Pad Left
      if (event.key.contains('dpad') && event.key.contains('left') ||
          event.key == 'button_14') {
        if (event.value > 0.5) {
          player.horizontalMovement = -1;
        } else if (player.horizontalMovement == -1) {
          player.horizontalMovement = 0;
        }
      }
      
      // D-Pad Right
      if (event.key.contains('dpad') && event.key.contains('right') ||
          event.key == 'button_15') {
        if (event.value > 0.5) {
          player.horizontalMovement = 1;
        } else if (player.horizontalMovement == 1) {
          player.horizontalMovement = 0;
        }
      }
    });
  }

  @override
  void update(double dt) {
    if (showControls && joystick != null) {
      updateJoystick();
    }
    super.update(dt);
  }

  void addJoystick() {
    joystick = JoystickComponent(
      priority: 10,
      knob: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Knob.png'),
        ),
      ),
      background: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Joystick.png'),
        ),
      ),
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    );

    add(joystick!);
  }

  void updateJoystick() {
    switch (joystick!.direction) {
      case JoystickDirection.left:
      case JoystickDirection.upLeft:
      case JoystickDirection.downLeft:
        player.horizontalMovement = -1;
        break;
      case JoystickDirection.right:
      case JoystickDirection.upRight:
      case JoystickDirection.downRight:
        player.horizontalMovement = 1;
        break;
      default:
        player.horizontalMovement = 0;
        break;
    }
  }

  void loadNextLevel() {
    print('Loading next level. Current: $currentLevelIndex');

    // Remove old camera and world
    if (cam.isMounted) {
      cam.removeFromParent();
    }

    removeWhere((component) => component is Level);

    // Remove old controls
    if (joystick != null && joystick!.isMounted) {
      joystick!.removeFromParent();
      joystick = null;
    }
    removeWhere((component) => component is JumpButton);

    if (currentLevelIndex < levelNames.length - 1) {
      currentLevelIndex++;
    } else {
      currentLevelIndex = 0;
    }

    print('Next level index: $currentLevelIndex, Level name: ${levelNames[currentLevelIndex]}');

    _loadLevel();

    // Re-add controls for new level
    if (showControls) {
      addJoystick();
      add(JumpButton());
    }
  }

  void _loadLevel() {
    // Create a new player for each level to avoid issues
    player = Player(character: 'Mask Dude');

    Level world = Level(
      player: player,
      levelName: levelNames[currentLevelIndex],
    );

    cam = CameraComponent.withFixedResolution(
      world: world,
      width: 640,
      height: 360,
    );
    cam.viewfinder.anchor = Anchor.topLeft;

    addAll([cam, world]);
  }
}