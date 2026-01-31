import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyEvent;
import 'package:pixel_adventure/components/aura_effect.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/mask.dart';

enum PixelFighterState { idle, run, hit, jump, fall }

class PixelFighter extends SpriteAnimationGroupComponent<PixelFighterState>
    with KeyboardHandler, CollisionCallbacks, HasGameReference {
  // ... rest of code stays the same
  final int playerIndex;
  final String character;

  bool _wasKick = false; // ← ADD THIS LINE!

  PixelFighter({
    required this.playerIndex,
    this.character = 'Mask Dude',
    position,
  }) : super(
          position: position,
          size: Vector2.all(32),
          anchor: Anchor.center,
        );

  final double stepTime = 0.05;
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation jumpAnimation;
  late final SpriteAnimation fallAnimation;

  static const double _gravity = 9.8;
  static const double _jumpForce = 260;
  static const double _terminalVelocity = 300;
  double _velocityY = 0;
  bool _isOnGround = false;
  bool _hasJumped = false;

  double _moveSpeed = 120;
  double _velocityX = 0;
  double _stateTimer = 0;
  double _health = 100;
  static const double _attackRange = 45;
  static const double _punchDamage = 10;
  static const double _kickDamage = 15;

  List<CollisionBlock> collisionBlocks = [];
  AuraEffect? currentAura;

  bool get isAlive => _health > 0;
  double get health => _health;
  PixelFighterState? get state => current;

  @override
  FutureOr<void> onLoad() async {
    _loadAnimations();

    animations = {
      PixelFighterState.idle: idleAnimation,
      PixelFighterState.run: runAnimation,
      PixelFighterState.hit: hitAnimation,
      PixelFighterState.jump: jumpAnimation,
      PixelFighterState.fall: fallAnimation,
    };
    current = PixelFighterState.idle;

    add(RectangleHitbox(
      position: Vector2(6, 4),
      size: Vector2(20, 28),
      collisionType: CollisionType.active,
    ));

    return super.onLoad();
  }

  void addAura(String maskName) {
  if (currentAura != null) {
    currentAura!.removeFromParent();
  }
  
  Color auraColor;
  switch (maskName.toLowerCase()) {
    case 'red-mask':
      auraColor = Colors.red;
      break;
    case 'gold-mask':
      auraColor = const Color(0xFFFFD700);
      break;
    case 'blue-mask':
      auraColor = Colors.blue;
      break;
    case 'green-mask':
      auraColor = Colors.green;
      break;
    default:
      auraColor = Colors.cyan;
  }
  
  currentAura = AuraEffect(
    color: auraColor,
    duration: 5.0,
    size: Vector2.all(80),
  );
  currentAura!.position = Vector2(size.x / 2, size.y / 2);
  add(currentAura!);
}

  void _updatePlayerState() {
  if (current == PixelFighterState.hit) return;
  if (_velocityY < 0) {
    current = PixelFighterState.jump;
  } else if (_velocityY > 0) {
    current = PixelFighterState.fall;
  } else if (_velocityX != 0) {
    current = PixelFighterState.run;
  } else {
    current = PixelFighterState.idle;
  }
}

  void _loadAnimations() {
    idleAnimation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/Idle (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: 11,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );

    runAnimation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/Run (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: 12,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );

    hitAnimation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/Hit (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: 7,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
        loop: false,
      ),
    );

    jumpAnimation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/Jump (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );

    fallAnimation = SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/Fall (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (playerIndex == 1) {
      final moveLeft = keysPressed.contains(LogicalKeyboardKey.keyA);
      final moveRight = keysPressed.contains(LogicalKeyboardKey.keyD);
      final punch = keysPressed.contains(LogicalKeyboardKey.keyW);
      final kick = keysPressed.contains(LogicalKeyboardKey.keyS);
      final jump = keysPressed.contains(LogicalKeyboardKey.space);

      if (moveLeft) {
        _velocityX = -_moveSpeed;
        scale.x = -1;
      } else if (moveRight) {
        _velocityX = _moveSpeed;
        scale.x = 1;
      } else {
        _velocityX = 0;
      }

      _hasJumped = jump;

      if (punch && current != PixelFighterState.hit) {
        current = PixelFighterState.hit;
        _wasKick = false;
        animationTicker?.reset();
        _stateTimer = 0;
      } else if (kick && current != PixelFighterState.hit) {
        current = PixelFighterState.hit;
        _wasKick = true;
        animationTicker?.reset();
        _stateTimer = 0;
      }

      return moveLeft || moveRight || punch || kick || jump;
    } else {
      final moveLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
      final moveRight = keysPressed.contains(LogicalKeyboardKey.arrowRight);
      final punch = keysPressed.contains(LogicalKeyboardKey.arrowUp);
      final kick = keysPressed.contains(LogicalKeyboardKey.arrowDown);
      final jump = keysPressed.contains(LogicalKeyboardKey.shiftRight);

      if (moveLeft) {
        _velocityX = -_moveSpeed;
        scale.x = -1;
      } else if (moveRight) {
        _velocityX = _moveSpeed;
        scale.x = 1;
      } else {
        _velocityX = 0;
      }

      _hasJumped = jump;

      if (punch && current != PixelFighterState.hit) {
        current = PixelFighterState.hit;
        _wasKick = false;
        animationTicker?.reset();
        _stateTimer = 0;
      } else if (kick && current != PixelFighterState.hit) {
        current = PixelFighterState.hit;
        _wasKick = true;
        animationTicker?.reset();
        _stateTimer = 0;
      }

      return moveLeft || moveRight || punch || kick || jump;
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Mask) other.collidedWithPlayer(this);
    super.onCollisionStart(intersectionPoints, other);
  }

  // Hitbox: anchor center 32x32, hitbox at (6,4) size (20,28)
  double get _hitboxLeft => position.x - 16 + 6;
  double get _hitboxRight => _hitboxLeft + 20;
  double get _hitboxTop => position.y - 16 + 4;
  double get _hitboxBottom => _hitboxTop + 28;

  void _checkHorizontalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPlatform) continue;
      if (_hitboxTop >= block.y + block.height || _hitboxBottom <= block.y)
        continue;
      if (_velocityX > 0 &&
          _hitboxRight > block.x &&
          _hitboxLeft < block.x + block.width) {
        _velocityX = 0;
        position.x =
            block.x - 10; // hitboxRight = position.x + 10, stop at block left
        break;
      }
      if (_velocityX < 0 &&
          _hitboxLeft < block.x + block.width &&
          _hitboxRight > block.x) {
        _velocityX = 0;
        position.x = block.x + block.width + 10; // hitboxLeft = position.x - 10
        break;
      }
    }
  }

  void _applyGravity(double dt) {
    _velocityY += _gravity;
    _velocityY = _velocityY.clamp(-_jumpForce, _terminalVelocity);
    position.y += _velocityY * dt;
  }

  void _checkVerticalCollisions(double dt) {
    _isOnGround = false;

    for (final block in collisionBlocks) {
      // Skip if no horizontal overlap
      if (_hitboxRight <= block.x || _hitboxLeft >= block.x + block.width)
        continue;

      // Debug logging
      // print('Checking collision with block at ${block.position}');

      // Land on top (falling) - platforms and solid blocks
      if (_velocityY > 0 &&
          _hitboxBottom >= block.y &&
          _hitboxBottom <= block.y + 10) {
        _velocityY = 0;
        position.y = block.y - 16; // 16 = half of character height (32/2)
        _isOnGround = true;
        // print('Player landed on ground at y=${position.y}');
        break;
      }

      // Hit head (jumping) - solid blocks only
      if (!block.isPlatform && _velocityY < 0) {
        if (_hitboxTop <= block.y + block.height && _hitboxTop >= block.y) {
          _velocityY = 0;
          position.y = block.y + block.height + 16;
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isAlive) return;

    _stateTimer += dt;

    if (current == PixelFighterState.hit) {
      if (_stateTimer > 0.35) {
        current = PixelFighterState.idle;
      }
      // Still apply gravity during hit
      _applyGravity(dt);
      _checkVerticalCollisions(dt);
    } else {
      // Jump
      if (_hasJumped && _isOnGround) {
        // Access game dynamically
        try {
          final playSounds = (game as dynamic).playSounds ?? true;
          final soundVolume = (game as dynamic).soundVolume ?? 1.0;
          if (playSounds) {
            FlameAudio.play('jump.wav', volume: soundVolume);
          }
        } catch (_) {}

        _velocityY = -_jumpForce;
        _isOnGround = false;
      }

      // Horizontal movement
      position.x += _velocityX * dt;
      _checkHorizontalCollisions();
      position.x = position.x.clamp(64, 544);

      // Gravity
      _applyGravity(dt);
      _checkVerticalCollisions(dt);

      _updatePlayerState();
    }
  }

  void takeDamage(double amount) {
    _health = (_health - amount).clamp(0, 100);
  }

  void checkHit(PixelFighter other) {
    if (!isAlive || !other.isAlive) return;
    if (current != PixelFighterState.hit) return;
    if (_stateTimer > 0.25) return;

    final dx = (other.position - position).x;
    final inRange = dx.abs() < _attackRange;
    final facingTarget = (scale.x > 0 && dx > 0) || (scale.x < 0 && dx < 0);

    if (inRange && facingTarget) {
      final damage = _wasKick ? _kickDamage : _punchDamage;
      other.takeDamage(damage);
    }
  }
}
