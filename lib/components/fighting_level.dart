import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:pixel_adventure/components/background_tile.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/mask.dart';
import 'package:pixel_adventure/components/pixel_fighter.dart';

class FightingLevel extends World {
  final String levelName;
  final PixelFighter player1;
  final PixelFighter player2;
  
  FightingLevel({
    required this.levelName,
    required this.player1,
    required this.player2,
  });
  
  late TiledComponent level;
  List<CollisionBlock> collisionBlocks = [];

  @override
  FutureOr<void> onLoad() async {
    // Access game through findGame() instead of gameRef
    final gameInstance = findGame()!;
    level = await TiledComponent.load('$levelName.tmx', Vector2.all(16));

    add(level);

    _scrollingBackground();
    _spawningObjects();
    _addCollisions();

    return super.onLoad();
  }

  void _scrollingBackground() {
    final backgroundLayer = level.tileMap.getLayer('Background');

    if (backgroundLayer != null) {
      final backgroundColor =
          backgroundLayer.properties.getValue('BackgroundColor');
      final backgroundTile = BackgroundTile(
        color: backgroundColor ?? 'Gray',
        position: Vector2(0, 0),
      );
      add(backgroundTile);
    }
  }

  void _spawningObjects() {
  final spawnPointsLayer = level.tileMap.getLayer<ObjectGroup>('Spawnpoints');

  Vector2? player1Spawn;
  Vector2? player2Spawn;

  if (spawnPointsLayer != null) {
    for (final spawnPoint in spawnPointsLayer.objects) {
      switch (spawnPoint.class_) {
        case 'Player':
          if (player1Spawn == null) {
            player1Spawn = Vector2(spawnPoint.x, spawnPoint.y);
            print('Player 1 spawn point: $player1Spawn');
          } else if (player2Spawn == null) {
            player2Spawn = Vector2(spawnPoint.x, spawnPoint.y);
            print('Player 2 spawn point: $player2Spawn');
          }
          break;
        // ... rest of switch cases
      }
    }
  }

  // Set positions with fallback - ensure both players spawn above ground
  if (player1Spawn != null) {
    player1.position = player1Spawn;
    player1.scale.x = 1;
  } else {
    // Default position: x=100, y=270 (above ground at y=304)
    player1.position = Vector2(100, 270);
    print('Using default position for player 1: ${player1.position}');
  }
  // Reset velocity to prevent falling before collision blocks are set
  player1.position = Vector2(player1.position.x, player1.position.y);
  add(player1);

  if (player2Spawn != null) {
    player2.position = player2Spawn;
    player2.scale.x = -1;
  } else {
    // Default position: x=500, y=270 (above ground at y=304)
    player2.position = Vector2(500, 270);
    print('Using default position for player 2: ${player2.position}');
  }
  // Reset velocity to prevent falling before collision blocks are set
  player2.position = Vector2(player2.position.x, player2.position.y);
  add(player2);

  _autoSpawnMasks();
}

  void _autoSpawnMasks() {
    final redMask = Mask(
      mask: 'red-mask',
      position: Vector2(150, 200),
      size: Vector2(32, 32),
    );
    add(redMask);

    final greenMask = Mask(
      mask: 'green-mask',
      position: Vector2(250, 200),
      size: Vector2(32, 32),
    );
    add(greenMask);

    final goldMask = Mask(
      mask: 'gold-mask',
      position: Vector2(350, 200),
      size: Vector2(32, 32),
    );
    add(goldMask);

    final blueMask = Mask(
      mask: 'blue-mask',
      position: Vector2(450, 200),
      size: Vector2(32, 32),
    );
    add(blueMask);
  }

  void _addCollisions() {
  final collisionsLayer = level.tileMap.getLayer<ObjectGroup>('Collisions');

  print('=== COLLISION DEBUG ===');
  print('Collisions layer found: ${collisionsLayer != null}');
  
  if (collisionsLayer != null) {
    print('Number of collision objects: ${collisionsLayer.objects.length}');
    
    for (final collision in collisionsLayer.objects) {
      print('Collision at: (${collision.x}, ${collision.y}) size: (${collision.width}, ${collision.height}) isPlatform: ${collision.class_ == 'Platform'}');
      
      switch (collision.class_) {
        case 'Platform':
          final platform = CollisionBlock(
            position: Vector2(collision.x, collision.y),
            size: Vector2(collision.width, collision.height),
            isPlatform: true,
          );
          collisionBlocks.add(platform);
          add(platform);
          break;
        default:
          final block = CollisionBlock(
            position: Vector2(collision.x, collision.y),
            size: Vector2(collision.width, collision.height),
          );
          collisionBlocks.add(block);
          add(block);
      }
    }
  } else {
    print('WARNING: No Collisions layer found!');
    // ADD DEFAULT GROUND as fallback
    _addDefaultGround();
  }
  
  print('Total collision blocks added: ${collisionBlocks.length}');
  print('Player 1 position: ${player1.position}');
  print('Player 2 position: ${player2.position}');
  print('======================');
  
  // CRITICAL: Assign collision blocks to both players
  // This must be done after collision blocks are created
  player1.collisionBlocks = collisionBlocks;
  player2.collisionBlocks = collisionBlocks;
  
  // Ensure both players are initialized on ground
  // This prevents them from falling before collision detection works
  _initializePlayersOnGround();
}

// Add fallback ground if no collisions in map
void _addDefaultGround() {
  print('Adding default ground...');
  
  // Ground at bottom
  final ground = CollisionBlock(
    position: Vector2(0, 304), // 320 - 16 (tile size)
    size: Vector2(640, 16),
    isPlatform: true,
  );
  collisionBlocks.add(ground);
  add(ground);
  
  // Left wall
  final leftWall = CollisionBlock(
    position: Vector2(0, 0),
    size: Vector2(16, 360),
    isPlatform: false,
  );
  collisionBlocks.add(leftWall);
  add(leftWall);
  
  // Right wall
  final rightWall = CollisionBlock(
    position: Vector2(624, 0),
    size: Vector2(16, 360),
    isPlatform: false,
  );
  collisionBlocks.add(rightWall);
  add(rightWall);
  
  print('Default ground added at y=304');
}

// Initialize players on ground to prevent falling
void _initializePlayersOnGround() {
  // Find the ground level (lowest collision block that's not a platform or wall)
  double groundLevel = 304.0; // Default ground level
  
  for (final block in collisionBlocks) {
    if (!block.isPlatform && block.y + block.height > groundLevel) {
      groundLevel = block.y + block.height;
    }
  }
  
  // Ensure Player 1 is on ground
  if (player1.position.y > groundLevel - 20) {
    player1.position = Vector2(player1.position.x, groundLevel - 16);
    print('Player 1 adjusted to ground level: ${player1.position}');
  }
  
  // Ensure Player 2 is on ground
  if (player2.position.y > groundLevel - 20) {
    player2.position = Vector2(player2.position.x, groundLevel - 16);
    print('Player 2 adjusted to ground level: ${player2.position}');
  }
}
}