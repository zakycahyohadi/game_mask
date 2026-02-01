import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyEvent, KeyDownEvent, KeyUpEvent;
import 'package:pixel_adventure/components/aura_effect.dart';
import 'package:pixel_adventure/components/bullet.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/mask.dart';

enum PixelFighterState { idle, run, hit, jump, fall }

class PixelFighter extends SpriteAnimationGroupComponent<PixelFighterState>
    with KeyboardHandler, CollisionCallbacks, HasGameReference {
  final int playerIndex;
  final String character;

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
  static const double fixedDeltaTime = 1 / 60;
  double _velocityY = 0;
  bool _isOnGround = false;
  bool _hasJumped = false;
  bool _canDoubleJump = false; // Track if double jump is available

  double _moveSpeed = 120;
  double _velocityX = 0;
  double _stateTimer = 0;
  
  // Input state tracking for responsive controls
  // Made public for gamepad access
  bool _isMovingLeft = false;
  bool _isMovingRight = false;
  
  // Expose private fields for gamepad access
  bool get isMovingLeft => _isMovingLeft;
  bool get isMovingRight => _isMovingRight;
  set isMovingLeft(bool value) => _isMovingLeft = value;
  set isMovingRight(bool value) => _isMovingRight = value;
  
  // Expose other needed fields for gamepad
  bool get isOnGround => _isOnGround;
  bool get hasJumped => _hasJumped;
  set hasJumped(bool value) => _hasJumped = value;
  double get shootCooldown => _shootCooldown;
  void shoot() => _shoot();
  
  // Health and combat
  double _baseHealth = 100;
  double _maxHealth = 100;
  double _health = 100;
  double _baseDamage = 10;
  double _damage = 10;
  
  // Ammo system
  int _baseAmmo = 30;
  int _maxAmmo = 30;
  int _ammo = 30;
  double _shootCooldown = 0.0;
  static const double _shootCooldownTime = 0.3;
  
  // Shield system
  double _shield = 0;
  double _shieldTimer = 0;
  static const double _shieldDuration = 10.0;
  
  // Mask effects
  String? _activeMask;
  bool _hasRedMask = false;
  bool _hasGreenMask = false;
  bool _hasGoldMask = false;
  bool _hasBlueMask = false;

  List<CollisionBlock> collisionBlocks = [];
  AuraEffect? currentAura;
  
  // Set target player for AI (computer player)
  void setTargetPlayer(PixelFighter target) {
    if (playerIndex == 2) {
      _targetPlayer = target;
    }
  }

  bool get isAlive => _health > 0;
  double get health => _health;
  double get maxHealth => _maxHealth;
  int get ammo => _ammo;
  int get maxAmmo => _maxAmmo;
  double get shield => _shield;
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

    // Initialize velocity to prevent immediate falling
    _velocityY = 0;
    _velocityX = 0;
    _isOnGround = false; // Will be set to true when collision blocks are assigned

    return super.onLoad();
  }

  void addAura(String maskName) {
    if (currentAura != null) {
      currentAura!.removeFromParent();
    }
    
    _activeMask = maskName;
    final maskType = maskName.toLowerCase();
    
    // Apply mask effects
    _hasRedMask = maskType == 'red-mask';
    _hasGreenMask = maskType == 'green-mask';
    _hasGoldMask = maskType == 'gold-mask';
    _hasBlueMask = maskType == 'blue-mask';
    
    // Red mask: +10% damage
    if (_hasRedMask) {
      _damage = _baseDamage * 1.1;
    } else {
      _damage = _baseDamage;
    }
    
    // Green mask: +20% HP
    if (_hasGreenMask) {
      _maxHealth = _baseHealth * 1.2;
      _health = (_health / _baseHealth * _maxHealth).clamp(0, _maxHealth);
    } else {
      _maxHealth = _baseHealth;
    }
    
    // Gold mask: +10 ammo
    if (_hasGoldMask) {
      _maxAmmo = _baseAmmo + 10;
      _ammo = (_ammo + 10).clamp(0, _maxAmmo);
    } else {
      _maxAmmo = _baseAmmo;
    }
    
    // Blue mask: +20 shield for 10 seconds
    if (_hasBlueMask) {
      _shield = 20;
      _shieldTimer = _shieldDuration;
    }
    
    Color auraColor;
    switch (maskType) {
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
      duration: _hasBlueMask ? _shieldDuration : 999.0, // Permanent until shield expires
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
      // ═══════════════════════════════════════════════════════
      // PLAYER 1: PS CONTROLLER ONLY
      // =======================================================
      // P1 dikontrol dengan PS controller (gamepad)
      // P1 TIDAK bisa dikontrol dengan keyboard
      // All controls handled by gamepad in PixelFightingGame._initGamepad()
      // ═══════════════════════════════════════════════════════
      
      // Player 1: Uses PS Controller (gamepad) - NO keyboard controls
      return false; // Don't handle keyboard events for player 1
    } else {
      // ═══════════════════════════════════════════════════════
      // PLAYER 2: COMPUTER (AI)
      // =======================================================
      // P2 adalah computer/AI - tidak perlu keyboard atau gamepad
      // AI controls handled automatically in update() method
      // ═══════════════════════════════════════════════════════
      
      // Player 2: Computer/AI - NO keyboard controls
      return false; // Don't handle keyboard events for computer player
    }
  }
  
  void _shoot() {
    if (_ammo <= 0) return;
    
    _ammo--;
    _shootCooldown = _shootCooldownTime;
    
    // Play sound
    try {
      final playSounds = (game as dynamic).playSounds ?? true;
      final soundVolume = (game as dynamic).soundVolume ?? 1.0;
      if (playSounds) {
        FlameAudio.play('hit.wav', volume: soundVolume);
      }
    } catch (_) {}
    
    // Create bullet
    final bullet = Bullet(
      shooter: this,
      speed: 400,
      damage: _damage,
      goingRight: scale.x > 0,
      position: Vector2(
        position.x + (scale.x > 0 ? 20 : -20),
        position.y,
      ),
    );
    
    // Add bullet to world (find the world component)
    final world = parent;
    if (world != null) {
      world.add(bullet);
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

  void _checkHorizontalCollisions(double dt) {
    for (final block in collisionBlocks) {
      if (block.isPlatform) continue;
      
      // Check vertical overlap first
      if (_hitboxTop >= block.y + block.height || _hitboxBottom <= block.y)
        continue;
      
      // Moving right - check if we're about to collide
      if (_velocityX > 0) {
        final nextRight = _hitboxRight + _velocityX * dt;
        if (nextRight > block.x && _hitboxLeft < block.x + block.width) {
          _velocityX = 0;
          position.x = block.x - 20; // 10 (hitbox offset) + 10 (margin)
          break;
        }
      }
      
      // Moving left - check if we're about to collide
      if (_velocityX < 0) {
        final nextLeft = _hitboxLeft + _velocityX * dt;
        if (nextLeft < block.x + block.width && _hitboxRight > block.x) {
          _velocityX = 0;
          position.x = block.x + block.width + 4; // 10 (hitbox offset) - 6 (adjustment)
          break;
        }
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

    // Safety check: ensure collisionBlocks is not empty
    if (collisionBlocks.isEmpty) {
      // If no collision blocks, prevent falling through map
      if (position.y > 320) {
        position.y = 320;
        _velocityY = 0;
        _isOnGround = true;
      }
      return;
    }

    for (final block in collisionBlocks) {
      // Skip if no horizontal overlap
      if (_hitboxRight <= block.x || _hitboxLeft >= block.x + block.width)
        continue;

      // Land on top (falling) - platforms and solid blocks
      // Use predictive collision to prevent sinking
      if (_velocityY > 0) {
        final nextBottom = _hitboxBottom + _velocityY * dt;
        if (nextBottom >= block.y && _hitboxTop < block.y) {
          _velocityY = 0;
          position.y = block.y - 16; // 16 = half of character height (32/2)
          _isOnGround = true;
          _canDoubleJump = false; // Reset double jump when landing
          break;
        }
      }

      // Hit head (jumping) - solid blocks only
      if (!block.isPlatform && _velocityY < 0) {
        final nextTop = _hitboxTop + _velocityY * dt;
        if (nextTop <= block.y + block.height && _hitboxBottom > block.y + block.height) {
          _velocityY = 0;
          position.y = block.y + block.height + 16;
          break;
        }
      }
    }
    
    // Additional safety check: prevent falling through map bottom
    if (position.y > 360) {
      position.y = 320;
      _velocityY = 0;
      _isOnGround = true;
    }
  }

  // AI variables for computer player (playerIndex == 2)
  double _aiTimer = 0.0;
  double _aiShootTimer = 0.0;
  double _aiJumpTimer = 0.0;
  PixelFighter? _targetPlayer; // Target player untuk AI attack (P1)
  static const double _aiShootInterval = 0.8; // Shoot lebih sering (0.8 detik)
  static const double _aiJumpInterval = 1.5; // Jump lebih sering (1.5 detik)
  static const double _attackRange = 500.0; // Jarak maksimal untuk attack
  static const double _chaseRange = 1000.0; // Jarak maksimal untuk chase (selalu chase)
  static const double _closeRange = 100.0; // Jarak dekat untuk jump attack

  @override
  void update(double dt) {
    super.update(dt);

    if (!isAlive) return;

    _stateTimer += dt;
    _shootCooldown = (_shootCooldown - dt).clamp(0, _shootCooldownTime);
    
    // Update shield timer
    if (_shield > 0) {
      _shieldTimer -= dt;
      if (_shieldTimer <= 0) {
        _shield = 0;
        _hasBlueMask = false;
        if (_activeMask == 'blue-mask') {
          // Remove aura when shield expires
          if (currentAura != null) {
            currentAura!.removeFromParent();
            currentAura = null;
          }
          _activeMask = null;
        }
      }
    }

    // AI LOGIC FOR COMPUTER PLAYER (playerIndex == 2) - AUTO CHASE & ATTACK P1
    if (playerIndex == 2 && _targetPlayer != null && _targetPlayer!.isAlive) {
      _aiTimer += dt;
      _aiShootTimer += dt;
      _aiJumpTimer += dt;

      // Get target (P1) position
      final targetPos = _targetPlayer!.position;
      final myPos = position;
      final distanceX = (targetPos.x - myPos.x).abs();
      final distance = (targetPos - myPos).length;
      final directionToTarget = targetPos.x - myPos.x;

      // ═══════════════════════════════════════════════════════
      // AI CHASE LOGIC - GERAK MAJU MUNDUR UNTUK NGEJAR P1
      // =======================================================
      // AI akan bergerak maju mundur untuk mengejar P1 dengan efektif
      
      // Selalu menghadap ke arah P1
      if (directionToTarget > 0) {
        scale.x = 1; // Face right (menghadap P1)
      } else {
        scale.x = -1; // Face left (menghadap P1)
      }

      // Chase P1 - bergerak maju (mendekati P1)
      if (distanceX > 15) {
        // Jika P1 di kanan, move right (maju ke kanan)
        if (directionToTarget > 0) {
          _isMovingRight = true;
          _isMovingLeft = false;
        } 
        // Jika P1 di kiri, move left (maju ke kiri)
        else {
          _isMovingLeft = true;
          _isMovingRight = false;
        }
      } 
      // Jika sudah cukup dekat, bisa mundur sedikit untuk positioning
      else if (distanceX < 8) {
        // Mundur sedikit untuk mendapatkan jarak yang lebih baik
        if (directionToTarget > 0) {
          _isMovingLeft = true; // Mundur ke kiri
          _isMovingRight = false;
        } else {
          _isMovingRight = true; // Mundur ke kanan
          _isMovingLeft = false;
        }
      }
      // Jarak optimal, stop moving
      else {
        _isMovingLeft = false;
        _isMovingRight = false;
      }

      // ═══════════════════════════════════════════════════════
      // AI ATTACK LOGIC - AUTO SHOOT KE ARAH P1
      // =======================================================
      // AI akan menembak P1 ketika dalam jangkauan
      if (distance < _attackRange && _shootCooldown <= 0 && _ammo > 0) {
        // Shoot lebih agresif dan sering
        if (_aiShootTimer >= _aiShootInterval) {
          _aiShootTimer = 0;
          _shoot(); // Auto attack P1
        }
      }

      // ═══════════════════════════════════════════════════════
      // AI JUMP LOGIC - JUMP UNTUK ATTACK/CHASE
      // =======================================================
      // AI akan jump untuk mengejar atau menyerang P1
      if (_isOnGround) {
        // Jump ketika dekat dengan target untuk attack
        if (distance < _closeRange && _aiJumpTimer >= 0.3) {
          _aiJumpTimer = 0;
          _hasJumped = true; // Jump attack ketika dekat
        } 
        // Jump secara periodik untuk chase
        else if (_aiJumpTimer >= _aiJumpInterval) {
          _aiJumpTimer = 0;
          _hasJumped = true; // Jump untuk chase
        }
      }
    }

      // Jump - support double jump
      if (_hasJumped) {
        if (_isOnGround) {
          // First jump from ground
          try {
            final playSounds = (game as dynamic).playSounds ?? true;
            final soundVolume = (game as dynamic).soundVolume ?? 1.0;
            if (playSounds) {
              FlameAudio.play('jump.wav', volume: soundVolume);
            }
          } catch (_) {}

          _velocityY = -_jumpForce;
          _isOnGround = false;
          _canDoubleJump = true; // Enable double jump after first jump
          _hasJumped = false;
        } else if (_canDoubleJump) {
          // Double jump in air
          try {
            final playSounds = (game as dynamic).playSounds ?? true;
            final soundVolume = (game as dynamic).soundVolume ?? 1.0;
            if (playSounds) {
              FlameAudio.play('jump.wav', volume: soundVolume);
            }
          } catch (_) {}

          _velocityY = -_jumpForce;
          _canDoubleJump = false; // Disable double jump after using it
          _hasJumped = false;
        }
      }

    // Update movement based on input state - responsive and no delay
    if (_isMovingLeft && !_isMovingRight) {
      _velocityX = -_moveSpeed;
      scale.x = -1;
    } else if (_isMovingRight && !_isMovingLeft) {
      _velocityX = _moveSpeed;
      scale.x = 1;
    } else if (!_isMovingLeft && !_isMovingRight) {
      _velocityX = 0;
    }
    // If both keys pressed, stop movement
    if (_isMovingLeft && _isMovingRight) {
      _velocityX = 0;
    }

    // Horizontal movement
    position.x += _velocityX * dt;
    _checkHorizontalCollisions(dt);
    position.x = position.x.clamp(64, 544);

    // Gravity
    _applyGravity(dt);
    _checkVerticalCollisions(dt);

    _updatePlayerState();
  }

  void takeDamage(double amount) {
    if (_shield > 0) {
      // Shield absorbs damage
      final damageToShield = amount.clamp(0, _shield);
      _shield -= damageToShield;
      amount -= damageToShield;
    }
    _health = (_health - amount).clamp(0, _maxHealth);
  }
}
