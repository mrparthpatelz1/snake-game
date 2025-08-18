// // lib/app/modules/game/components/ai/ai_manager.dart
//
// import 'dart:math';
// import 'package:flame/components.dart';
// import 'package:flame/extensions.dart';
// import 'package:flutter/material.dart';
// import '../../views/game_screen.dart';
// import '../food/food_manager.dart';
// import '../player/player_component.dart';
// import 'ai_snake_data.dart';
//
// class AiManager extends Component {
//   final int numberOfSnakes = 100; // Increased to 50
//   final Random _random = Random();
//   final FoodManager foodManager;
//   final PlayerComponent player;
//   final List<AiSnakeData> snakes = [];
//
//   AiManager({required this.foodManager, required this.player}) {
//     for (int i = 0; i < numberOfSnakes; i++) {
//       _spawnSnake();
//     }
//   }
//
//   void update(double dt) {
//     for (final snake in snakes) {
//       _updateSnakeAI(snake, dt);
//     }
//   }
//
//   void _spawnSnake() {
//     final worldBounds = SlitherGame.worldBounds;
//     final position = Vector2(
//       _random.nextDouble() * worldBounds.width + worldBounds.left,
//       _random.nextDouble() * worldBounds.height + worldBounds.top,
//     );
//     final initialDirection = Vector2.random(_random)..normalize();
//
//     final snakeData = AiSnakeData(
//       position: position,
//       skinColors: _getRandomSkin(),
//       targetDirection: initialDirection,
//     );
//
//     // Initialize body segments
//     for (int i = 0; i < 15; i++) {
//       snakeData.bodySegments.add(position - Vector2(16.0 * 0.6 * (i + 1), 0));
//     }
//     snakes.add(snakeData);
//   }
//
//   void _updateSnakeAI(AiSnakeData snake, double dt) {
//     // This is the full AI logic for a single snake, performed centrally.
//     const visionRadius = 600.0;
//     const speed = 120.0;
//     const segmentSpacing = 16.0 * 0.6;
//     const rotationSpeed = 2 * pi;
//
//     // --- AI Decision Making ---
//     final distanceToPlayer = snake.position.distanceTo(player.position);
//     if (distanceToPlayer < visionRadius) {
//       if (snake.bodySegments.length > player.bodySegments.length) {
//         snake.targetDirection = (player.position - snake.position).normalized();
//       } else {
//         snake.targetDirection = (snake.position - player.position).normalized();
//       }
//     } else {
//       // Simple wander logic for now
//       if (_random.nextDouble() < 0.02) {
//         snake.targetDirection = Vector2.random(_random)..normalize();
//       }
//     }
//
//     // --- Movement ---
//     final targetAngle = snake.targetDirection.screenAngle();
//     final angleDiff = _getAngleDifference(snake.angle, targetAngle);
//     final rotationAmount = rotationSpeed * dt;
//     if (angleDiff.abs() < rotationAmount) {
//       snake.angle = targetAngle;
//     } else {
//       snake.angle += rotationAmount * angleDiff.sign;
//     }
//     final direction = Vector2(cos(snake.angle), sin(snake.angle));
//     snake.position.add(direction * speed * dt);
//     snake.position.clamp(
//       SlitherGame.playArea.topLeft.toVector2(),
//       SlitherGame.playArea.bottomRight.toVector2(),
//     );
//
//     // --- Body Following ---
//     Vector2 leaderPosition = snake.position;
//     for (int i = 0; i < snake.bodySegments.length; i++) {
//       final segment = snake.bodySegments[i];
//       final distanceToLeader = segment.distanceTo(leaderPosition);
//       if (distanceToLeader > segmentSpacing) {
//         final directionToLeader = (leaderPosition - segment).normalized();
//         final moveAmount = distanceToLeader - segmentSpacing;
//         segment.add(directionToLeader * moveAmount);
//       }
//       leaderPosition = segment;
//     }
//   }
//
//   List<Color> _getRandomSkin() {
//     return List.generate(6, (index) => Color((_random.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0));
//   }
//
//   double _getAngleDifference(double angle1, double angle2) {
//     var diff = (angle2 - angle1 + pi) % (2 * pi) - pi;
//     return diff < -pi ? diff + 2 * pi : diff;
//   }
// }

// lib/app/modules/game/components/ai/ai_manager.dart

// lib/app/modules/game/components/ai/ai_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';
import 'ai_snake_data.dart';

enum AiDifficulty { easy, medium, hard }

class AiManager extends Component with HasGameRef<SlitherGame> {
  final int numberOfSnakes = 100;
  final Random _random = Random();
  final FoodManager foodManager;
  final PlayerComponent player;
  final List<AiSnakeData> snakes = [];

  AiManager({required this.foodManager, required this.player});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    for (int i = 0; i < numberOfSnakes; i++) {
      _spawnSnake();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Get the camera's visible area, with a large buffer zone around it.
    final visibleRect = game.cameraComponent.visibleWorldRect.inflate(500);

    for (final snake in snakes) {
      // 1. Update the snake's bounding box first.
      _updateBoundingBox(snake);

      // 2. Only run the full, expensive update logic for snakes on or near the screen.
      if (visibleRect.overlaps(snake.boundingBox)) {
        _updateOnScreenSnake(snake, dt);
      } else {
        // For snakes far off-screen, run a new, super-fast, simplified update.
        _updateOffScreenSnake(snake, dt);
      }
    }
  }

  void _updateBoundingBox(AiSnakeData snake) {
    double minX = snake.position.x;
    double maxX = snake.position.x;
    double minY = snake.position.y;
    double maxY = snake.position.y;

    for (final segment in snake.bodySegments) {
      minX = min(minX, segment.x);
      maxX = max(maxX, segment.x);
      minY = min(minY, segment.y);
      maxY = max(maxY, segment.y);
    }
    snake.boundingBox = Rect.fromLTRB(
      minX - 16,
      minY - 16,
      maxX + 16,
      maxY + 16,
    );
  }

  // This is the new, super-fast update logic for off-screen snakes.
  void _updateOffScreenSnake(AiSnakeData snake, double dt) {
    // 1. Calculate the head's movement vector.
    final direction = Vector2(cos(snake.angle), sin(snake.angle));
    final moveVector = direction * snake.speed * dt;
    snake.position.add(moveVector);

    // 2. Move all body segments by the exact same amount.
    // This is a simple "teleport" that is extremely fast and keeps the body together.
    for (final segment in snake.bodySegments) {
      segment.add(moveVector);
    }

    // 3. We still clamp the head's position to keep it in the world.
    snake.position.clamp(
      SlitherGame.playArea.topLeft.toVector2(),
      SlitherGame.playArea.bottomRight.toVector2(),
    );
  }

  // This is the full, expensive update logic for on-screen snakes.
  void _updateOnScreenSnake(AiSnakeData snake, double dt) {
    double visionRadius = 600.0;
    double rotationSpeed = 3 * pi;
    const wallAvoidanceMargin = 300.0;

    // Difficulty tuning
    switch (snake.difficulty) {
      case AiDifficulty.easy:
        visionRadius *= 0.7;
        rotationSpeed *= 0.7;
        break;
      case AiDifficulty.medium:
        break;
      case AiDifficulty.hard:
        visionRadius *= 1.3;
        rotationSpeed *= 1.3;
        break;
    }

    // --- AI Decision Making ---
    final playArea = SlitherGame.playArea;
    bool isNearWall = false;
    if (snake.position.x < playArea.left + wallAvoidanceMargin) {
      snake.targetDirection = Vector2(1, 0); // Go right
      isNearWall = true;
    } else if (snake.position.x > playArea.right - wallAvoidanceMargin) {
      snake.targetDirection = Vector2(-1, 0); // Go left
      isNearWall = true;
    } else if (snake.position.y < playArea.top + wallAvoidanceMargin) {
      snake.targetDirection = Vector2(0, 1); // Go down
      isNearWall = true;
    } else if (snake.position.y > playArea.bottom - wallAvoidanceMargin) {
      snake.targetDirection = Vector2(0, -1); // Go up
      isNearWall = true;
    }

    if (!isNearWall) {
      final distanceToPlayer = snake.position.distanceTo(player.position);
      if (distanceToPlayer < visionRadius) {
        if (snake.bodySegments.length > player.bodySegments.length) {
          snake.targetDirection = (player.position - snake.position)
              .normalized();
        } else {
          snake.targetDirection = (snake.position - player.position)
              .normalized();
        }
      } else {
        if (_random.nextDouble() < 0.02) {
          snake.targetDirection = Vector2.random(_random)..normalize();
        }
      }
    }

    // --- Head Movement ---
    final targetAngle = snake.targetDirection.screenAngle();
    final angleDiff = _getAngleDifference(snake.angle, targetAngle);
    final rotationAmount = rotationSpeed * dt;
    if (angleDiff.abs() < rotationAmount) {
      snake.angle = targetAngle;
    } else {
      snake.angle += rotationAmount * angleDiff.sign;
    }
    final direction = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(direction * snake.speed * dt);
    snake.position.clamp(
      playArea.topLeft.toVector2(),
      playArea.bottomRight.toVector2(),
    );

    // --- Body Following ---
    if (snake.path.isEmpty ||
        snake.position.distanceTo(snake.path.first) > 3.0) {
      snake.path.insert(0, snake.position.clone());
    }
    for (int i = 0; i < snake.bodySegments.length; i++) {
      final totalDistance = (i + 1) * snake.segmentSpacing;
      final pointOnPath = _getPointOnPathAtDistance(snake, totalDistance);
      snake.bodySegments[i].setFrom(pointOnPath);
    }
    final maxPathLength = (snake.bodySegments.length + 5) * 20;
    if (snake.path.length > maxPathLength) {
      snake.path.removeRange(maxPathLength, snake.path.length);
    }

    // --- Collision Detection ---
    final eatDistance = (snake.headRadius * snake.headRadius) + 500;
    final List<FoodData> eatenFood = [];
    for (final food in foodManager.foodList) {
      if (snake.position.distanceToSquared(food.position) < eatDistance) {
        eatenFood.add(food);
      }
    }
    for (final food in eatenFood) {
      foodManager.removeFood(food);
      _growSnake(snake, food.growth);
      foodManager.spawnFood();
    }
  }

  void _spawnSnake() {
    final worldBounds = SlitherGame.worldBounds;
    final position = Vector2(
      _random.nextDouble() * worldBounds.width + worldBounds.left,
      _random.nextDouble() * worldBounds.height + worldBounds.top,
    );
    final initialDirection = Vector2.random(_random)..normalize();
    final double headRadius = 12.0 + _random.nextDouble() * 8.0;
    final snakeData = AiSnakeData(
      position: position,
      skinColors: _getRandomSkin(),
      targetDirection: initialDirection,
      headRadius: headRadius,
      bodyRadius: headRadius - 1.0,
      segmentSpacing: headRadius * 0.6,
      speed: 100.0 + _random.nextDouble() * 50.0,
      segmentCount: 10 + _random.nextInt(116),
      minRadius: headRadius,
      maxRadius: 40.0,
    );

    // Assign difficulty distribution: 85% easy, 13% medium, 2% hard
    final r = _random.nextDouble();
    if (r < 0.85) {
      snakeData.difficulty = AiDifficulty.easy;
    } else if (r < 0.98) {
      snakeData.difficulty = AiDifficulty.medium;
    } else {
      snakeData.difficulty = AiDifficulty.hard;
    }

    // Adjust stats per difficulty
    switch (snakeData.difficulty) {
      case AiDifficulty.easy:
        snakeData.speed *= 0.85;
        break;
      case AiDifficulty.medium:
        break;
      case AiDifficulty.hard:
        snakeData.speed *= 1.2;
        snakeData.maxRadius = 48.0;
        break;
    }
    for (int i = 0; i < snakeData.segmentCount; i++) {
      final segmentPos =
          position - Vector2(snakeData.segmentSpacing * (i + 1), 0);
      snakeData.bodySegments.add(segmentPos);
      snakeData.path.add(segmentPos);
    }
    snakes.add(snakeData);
  }

  void _growSnake(AiSnakeData snake, int amount) {
    final oldSegmentCount = snake.segmentCount;
    snake.segmentCount += amount;
    for (int i = 0; i < amount; i++) {
      snake.bodySegments.add(snake.bodySegments.last.clone());
    }
    if (snake.headRadius < snake.maxRadius) {
      final oldRadiusBonus = (oldSegmentCount / 25).floor();
      final newRadiusBonus = (snake.segmentCount / 25).floor();
      if (newRadiusBonus > oldRadiusBonus) {
        final radiusIncrease = (newRadiusBonus - oldRadiusBonus).toDouble();
        double newRadius = snake.headRadius + radiusIncrease;
        if (newRadius > snake.maxRadius) {
          newRadius = snake.maxRadius;
        }
        snake.headRadius = newRadius;
        snake.bodyRadius = newRadius - 1.0;
      }
    }
  }

  void killSnakeAndScatterFood(AiSnakeData snake) {
    for (final seg in snake.bodySegments) {
      foodManager.spawnFoodAt(seg);
    }
    foodManager.spawnFoodAt(snake.position);
    snakes.remove(snake);
  }

  void spawnNewSnake() {
    _spawnSnake();
  }

  Vector2 _getPointOnPathAtDistance(AiSnakeData snake, double distance) {
    final searchPath = [snake.position, ...snake.path];
    double distanceTraveled = 0;
    for (int i = 0; i < searchPath.length - 1; i++) {
      final p1 = searchPath[i];
      final p2 = searchPath[i + 1];
      final segmentLength = p1.distanceTo(p2);
      if (distanceTraveled + segmentLength >= distance) {
        final neededDist = distance - distanceTraveled;
        final direction = (p2 - p1).normalized();
        return p1 + direction * neededDist;
      }
      distanceTraveled += segmentLength;
    }
    return searchPath.last;
  }

  List<Color> _getRandomSkin() {
    return List.generate(
      6,
      (index) =>
          Color((_random.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
    );
  }

  double _getAngleDifference(double angle1, double angle2) {
    var diff = (angle2 - angle1 + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }
}
