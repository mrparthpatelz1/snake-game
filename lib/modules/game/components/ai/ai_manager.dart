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

    final visibleRect = game.cameraComponent.visibleWorldRect.inflate(500);

    for (final snake in snakes) {
      _updateBoundingBox(snake);

      if (visibleRect.overlaps(snake.boundingBox)) {
        _updateOnScreenSnake(snake, dt);
      } else {
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
    snake.boundingBox = Rect.fromLTRB(minX - 16, minY - 16, maxX + 16, maxY + 16);
  }

  void _updateOffScreenSnake(AiSnakeData snake, double dt) {
    final direction = Vector2(cos(snake.angle), sin(snake.angle));
    final moveVector = direction * snake.speed * dt;
    snake.position.add(moveVector);
    for (final segment in snake.bodySegments) {
      segment.add(moveVector);
    }
    snake.position.clamp(
      SlitherGame.playArea.topLeft.toVector2(),
      SlitherGame.playArea.bottomRight.toVector2(),
    );
  }

  void _updateOnScreenSnake(AiSnakeData snake, double dt) {
    double visionRadius = 600.0;
    double rotationSpeed = 3 * pi;
    const wallAvoidanceMargin = 300.0;

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

    final playArea = SlitherGame.playArea;
    bool isNearWall = false;
    if (snake.position.x < playArea.left + wallAvoidanceMargin) {
      snake.targetDirection = Vector2(1, 0);
      isNearWall = true;
    } else if (snake.position.x > playArea.right - wallAvoidanceMargin) {
      snake.targetDirection = Vector2(-1, 0);
      isNearWall = true;
    } else if (snake.position.y < playArea.top + wallAvoidanceMargin) {
      snake.targetDirection = Vector2(0, 1);
      isNearWall = true;
    } else if (snake.position.y > playArea.bottom - wallAvoidanceMargin) {
      snake.targetDirection = Vector2(0, -1);
      isNearWall = true;
    }

    if (!isNearWall) {
      final distanceToPlayer = snake.position.distanceTo(player.position);
      if (distanceToPlayer < visionRadius) {
        if (snake.bodySegments.length > player.bodySegments.length) {
          snake.targetDirection = (player.position - snake.position).normalized();
        } else {
          snake.targetDirection = (snake.position - player.position).normalized();
        }
      } else if (_random.nextDouble() < 0.02) {
        snake.targetDirection = Vector2.random(_random)..normalize();
      }
    }

    final targetAngle = snake.targetDirection.screenAngle();
    final angleDiff = _getAngleDifference(snake.angle, targetAngle);
    final rotationAmount = (3 * pi) * dt;
    snake.angle = (angleDiff.abs() < rotationAmount)
        ? targetAngle
        : snake.angle + rotationAmount * angleDiff.sign;

    final direction = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(direction * snake.speed * dt);
    snake.position.clamp(playArea.topLeft.toVector2(), playArea.bottomRight.toVector2());

    if (snake.path.isEmpty || snake.position.distanceTo(snake.path.first) > 3.0) {
      snake.path.insert(0, snake.position.clone());
    }
    for (int i = 0; i < snake.bodySegments.length; i++) {
      final totalDistance = (i + 1) * snake.segmentSpacing;
      snake.bodySegments[i].setFrom(_getPointOnPathAtDistance(snake, totalDistance));
    }
    final maxPathLength = (snake.bodySegments.length + 5) * 20;
    if (snake.path.length > maxPathLength) {
      snake.path.removeRange(maxPathLength, snake.path.length);
    }

    final eatDistanceSq = (snake.headRadius * snake.headRadius) + 500;
    final eatenFood = <FoodData>[];
    for (final food in foodManager.foodList) {
      if (snake.position.distanceToSquared(food.position) < eatDistanceSq) {
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

    final r = _random.nextDouble();
    snakeData.difficulty = r < 0.85
        ? AiDifficulty.easy
        : (r < 0.98 ? AiDifficulty.medium : AiDifficulty.hard);

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
      final segmentPos = position - Vector2(snakeData.segmentSpacing * (i + 1), 0);
      snakeData.bodySegments.add(segmentPos);
      snakeData.path.add(segmentPos);
    }
    snakes.add(snakeData);
  }

  void _growSnake(AiSnakeData snake, int amount) {
    final oldCount = snake.segmentCount;
    snake.segmentCount += amount;
    for (int i = 0; i < amount; i++) {
      snake.bodySegments.add(snake.bodySegments.last.clone());
    }
    if (snake.headRadius < snake.maxRadius) {
      final oldBonus = (oldCount / 25).floor();
      final newBonus = (snake.segmentCount / 25).floor();
      if (newBonus > oldBonus) {
        final inc = (newBonus - oldBonus).toDouble();
        snake.headRadius = (snake.headRadius + inc).clamp(snake.minRadius, snake.maxRadius);
        snake.bodyRadius = snake.headRadius - 1.0;
      }
    }
  }

  void killSnakeAndScatterFood(AiSnakeData snake) {
    // for (final seg in snake.bodySegments) {
    //   foodManager.spawnFoodAt(seg);
    // }
    // foodManager.spawnFoodAt(snake.position);
    // snakes.remove(snake);
    final random = Random();

    for (final seg in snake.bodySegments) {
      // Each segment drops 2–4 pellets
      int pelletCount = 2 + random.nextInt(3);

      for (int i = 0; i < pelletCount; i++) {
        // Random scatter radius (based on snake body size)
        double radius = snake.bodyRadius * (0.5 + random.nextDouble());

        // Random angle around the segment
        double angle = random.nextDouble() * 2 * pi;

        final offset = Vector2(
          seg.x + cos(angle) * radius,
          seg.y + sin(angle) * radius,
        );

        foodManager.spawnFoodAt(offset);
      }
    }

    // Extra food at snake head position
    foodManager.spawnFoodAt(snake.position);

    snakes.remove(snake);
  }

  void spawnNewSnake() => _spawnSnake();

  Vector2 _getPointOnPathAtDistance(AiSnakeData snake, double distance) {
    final searchPath = [snake.position, ...snake.path];
    double d = 0;
    for (int i = 0; i < searchPath.length - 1; i++) {
      final p1 = searchPath[i];
      final p2 = searchPath[i + 1];
      final segLen = p1.distanceTo(p2);
      if (d + segLen >= distance) {
        final needed = distance - d;
        final dir = (p2 - p1).normalized();
        return p1 + dir * needed;
      }
      d += segLen;
    }
    return searchPath.last;
  }

  List<Color> _getRandomSkin() {
    return List.generate(
      6,
          (index) => Color((_random.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
    );
  }

  double _getAngleDifference(double a, double b) {
    var diff = (b - a + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }
}
