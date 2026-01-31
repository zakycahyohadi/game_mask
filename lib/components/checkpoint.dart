import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:pixel_adventure/components/player.dart';
import 'package:pixel_adventure/components/level.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

class Checkpoint extends SpriteAnimationComponent
    with HasGameRef<PixelAdventure>, CollisionCallbacks {
  Checkpoint({
    position,
    size,
  }) : super(
          position: position,
          size: size,
        );

  bool reachedCheckpoint = false;

  @override
  FutureOr<void> onLoad() {
    // debugMode = true;
    add(RectangleHitbox(
      position: Vector2(18, 56),
      size: Vector2(12, 8),
      collisionType: CollisionType.passive,
    ));

    animation = SpriteAnimation.fromFrameData(
      game.images
          .fromCache('Items/Checkpoints/Checkpoint/Checkpoint (No Flag).png'),
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: 1,
        textureSize: Vector2.all(64),
      ),
    );
    return super.onLoad();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Player && !reachedCheckpoint) {
      print('Checkpoint reached! Position: $position'); // DEBUG
      _reachedCheckpoint();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void _reachedCheckpoint() async {
    print('=== CHECKPOINT ANIMATION STARTING ==='); // DEBUG
    reachedCheckpoint = true;

    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache(
          'Items/Checkpoints/Checkpoint/Checkpoint (Flag Out) (64x64).png'),
      SpriteAnimationData.sequenced(
        amount: 26,
        stepTime: 0.05,
        textureSize: Vector2.all(64),
        loop: false,
      ),
    );

    await animationTicker?.completed;
    print('=== FLAG OUT ANIMATION COMPLETED ==='); // DEBUG

    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache(
          'Items/Checkpoints/Checkpoint/Checkpoint (Flag Idle)(64x64).png'),
      SpriteAnimationData.sequenced(
        amount: 10,
        stepTime: 0.05,
        textureSize: Vector2.all(64),
      ),
    );

    print('=== WAITING 2 SECONDS BEFORE LEVEL TRANSITION ==='); // DEBUG

    // Wait for the animation to finish before transitioning
    Future.delayed(const Duration(seconds: 2), () {
      print('=== CHECKING IF CAN COMPLETE LEVEL ==='); // DEBUG
      print('isMounted: $isMounted'); // DEBUG
      print('parent is Level: ${parent is Level}'); // DEBUG

      if (isMounted && parent is Level) {
        print('=== CALLING completeLevel() ==='); // DEBUG
        (parent as Level).completeLevel();
      } else {
        print('=== CANNOT COMPLETE LEVEL ==='); // DEBUG
      }
    });
  }
}
