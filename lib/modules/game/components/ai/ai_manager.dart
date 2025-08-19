// lib/modules/game/components/ai/ai_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';
import 'ai_snake_data.dart';



class AiManager extends Component with HasGameReference<SlitherGame> {
  final int numberOfSnakes = 100;
  final Random _random = Random();
  final FoodManager foodManager;
  final PlayerComponent player;
  final List<AiSnakeData> snakes = [];

  AiManager({required this.foodManager, required this.player});

  late final List<Rect> _spawnZones;
  int _nextZoneIndex = 0;


  @override
  Future<void> onLoad() async {
    super.onLoad();
    for (int i = 0; i < numberOfSnakes; i++) {
      _initializeSpawnZones();
      _spawnSnake();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Get camera visible area for performance optimization
    final SlitherGame slitherGame = game;
    final visibleRect = slitherGame.cameraComponent.visibleWorldRect.inflate(500);

    for (final snake in snakes) {
      _updateBoundingBox(snake);

      // Always update snakes that are near boundaries, regardless of visibility
      if (_isNearAnyBoundary(snake.position, 1000.0) || visibleRect.overlaps(snake.boundingBox)) {
        _updateActiveSnake(snake, dt);
      } else {
        _updatePassiveSnake(snake, dt);
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
    snake.boundingBox = Rect.fromLTRB(minX - 32, minY - 32, maxX + 32, maxY + 32);
  }

  void _updatePassiveSnake(AiSnakeData snake, double dt) {
    // For off-screen snakes, use simple movement but with boundary checks

    // Critical: Check if snake is too close to boundary
    if (_isNearAnyBoundary(snake.position, 800.0)) {
      _updateActiveSnake(snake, dt); // Force active update for boundary snakes
      return;
    }

    // Simple movement for distant snakes
    final direction = Vector2(cos(snake.angle), sin(snake.angle));
    final moveVector = direction * snake.speed * dt;

    snake.position.add(moveVector);
    for (final segment in snake.bodySegments) {
      segment.add(moveVector);
    }
  }

  void _updateActiveSnake(AiSnakeData snake, double dt) {
    // Update AI state based on position and environment
    _determineAiState(snake);

    // Get target direction based on current state
    Vector2 targetDirection = _calculateTargetDirection(snake);

    // Apply the direction
    snake.targetDirection = targetDirection;

    // Move the snake
    _moveSnakeSmooth(snake, dt);

    // Update body following
    _updateSnakeBody(snake);

    // Check for food consumption
    _checkFoodConsumption(snake);
  }

  void _determineAiState(AiSnakeData snake) {
    final pos = snake.position;

    // Critical boundary check - highest priority
    if (_isNearAnyBoundary(pos, 600.0)) {
      snake.aiState = AiState.avoiding_boundary;
      return;
    }

    // If snake was avoiding boundary but now safe, seek center
    if (snake.aiState == AiState.avoiding_boundary && !_isNearAnyBoundary(pos, 800.0)) {
      snake.aiState = AiState.seeking_center;
      return;
    }

    // Check distance to center - if too far out, seek center
    final distanceFromCenter = pos.distanceTo(Vector2.zero());
    final worldSize = min(SlitherGame.worldBounds.width, SlitherGame.worldBounds.height);
    if (distanceFromCenter > worldSize * 0.3) {
      snake.aiState = AiState.seeking_center;
      return;
    }

    // Player interaction logic
    final distanceToPlayer = pos.distanceTo(player.position);
    if (distanceToPlayer < 500.0) {
      if (snake.bodySegments.length > player.bodySegments.length + 3) {
        snake.aiState = AiState.chasing;
      } else if (snake.bodySegments.length < player.bodySegments.length - 3) {
        snake.aiState = AiState.fleeing;
      } else {
        snake.aiState = AiState.wandering;
      }
      return;
    }

    // Default wandering behavior
    snake.aiState = AiState.wandering;
  }

  Vector2 _calculateTargetDirection(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.avoiding_boundary:
        return _getBoundaryAvoidanceDirection(snake);

      case AiState.seeking_center:
        return _getCenterSeekingDirection(snake);

      case AiState.chasing:
        return _getChaseDirection(snake);

      case AiState.fleeing:
        return _getFleeDirection(snake);

      case AiState.wandering:
        return _getWanderDirection(snake);
    }
  }

  Vector2 _getBoundaryAvoidanceDirection(AiSnakeData snake) {
    final pos = snake.position;
    final bounds = SlitherGame.playArea;
    Vector2 avoidanceForce = Vector2.zero();

    // Calculate repulsion from each boundary
    final leftDist = pos.x - bounds.left;
    final rightDist = bounds.right - pos.x;
    final topDist = pos.y - bounds.top;
    final bottomDist = bounds.bottom - pos.y;

    const safeDistance = 800.0;

    // Apply strong repulsion forces
    if (leftDist < safeDistance) {
      final force = (safeDistance - leftDist) / safeDistance;
      avoidanceForce.x += force * force; // Quadratic falloff for stronger close-range force
    }

    if (rightDist < safeDistance) {
      final force = (safeDistance - rightDist) / safeDistance;
      avoidanceForce.x -= force * force;
    }

    if (topDist < safeDistance) {
      final force = (safeDistance - topDist) / safeDistance;
      avoidanceForce.y += force * force;
    }

    if (bottomDist < safeDistance) {
      final force = (safeDistance - bottomDist) / safeDistance;
      avoidanceForce.y -= force * force;
    }

    // If no clear avoidance direction, head to center
    if (avoidanceForce.length < 0.1) {
      avoidanceForce = (Vector2.zero() - pos).normalized();
    }

    return avoidanceForce.normalized();
  }

  Vector2 _getCenterSeekingDirection(AiSnakeData snake) {
    final pos = snake.position;
    final centerDirection = (Vector2.zero() - pos).normalized();

    // Add some randomness to prevent all snakes following exact same path
    final randomOffset = Vector2(
      (_random.nextDouble() - 0.5) * 0.3,
      (_random.nextDouble() - 0.5) * 0.3,
    );

    return (centerDirection + randomOffset).normalized();
  }

  Vector2 _getChaseDirection(AiSnakeData snake) {
    final directionToPlayer = (player.position - snake.position).normalized();

    // Add prediction - where will player be?
    final playerVelocity = player.playerController.targetDirection;
    final predictedPlayerPos = player.position + playerVelocity * 50.0;
    final directionToPredicted = (predictedPlayerPos - snake.position).normalized();

    // Blend current and predicted positions
    return (directionToPlayer * 0.7 + directionToPredicted * 0.3).normalized();
  }

  Vector2 _getFleeDirection(AiSnakeData snake) {
    final fleeDirection = (snake.position - player.position).normalized();

    // Add perpendicular component for more natural fleeing
    final perpendicular = Vector2(-fleeDirection.y, fleeDirection.x);
    final randomPerp = perpendicular * ((_random.nextDouble() - 0.5) * 0.4);

    return (fleeDirection + randomPerp).normalized();
  }

  Vector2 _getWanderDirection(AiSnakeData snake) {
    // Look for nearby food first
    final nearestFood = _findNearestFood(snake.position, 300.0);
    if (nearestFood != null) {
      return (nearestFood.position - snake.position).normalized();
    }

    // Smooth wandering with occasional direction changes
    if (_random.nextDouble() < 0.008) { // Less frequent direction changes
      final currentDir = Vector2(cos(snake.angle), sin(snake.angle));
      final turnAngle = (_random.nextDouble() - 0.5) * pi * 0.6; // Max 108 degree turn

      final newDir = Vector2(
        currentDir.x * cos(turnAngle) - currentDir.y * sin(turnAngle),
        currentDir.x * sin(turnAngle) + currentDir.y * cos(turnAngle),
      );

      return newDir.normalized();
    }

    // Continue current direction with slight center bias
    final currentDir = Vector2(cos(snake.angle), sin(snake.angle));
    final centerBias = (Vector2.zero() - snake.position).normalized() * 0.1;

    return (currentDir + centerBias).normalized();
  }

  void _moveSnakeSmooth(AiSnakeData snake, double dt) {
    // Smooth rotation towards target
    final targetAngle = snake.targetDirection.screenAngle();
    final currentAngle = snake.angle;
    final angleDiff = _normalizeAngle(targetAngle - currentAngle);

    // Dynamic rotation speed based on how far we need to turn
    final baseRotationSpeed = 2.5 * pi;
    final urgencyMultiplier = snake.aiState == AiState.avoiding_boundary ? 2.0 : 1.0;
    final rotationSpeed = baseRotationSpeed * urgencyMultiplier;

    final maxRotation = rotationSpeed * dt;

    if (angleDiff.abs() <= maxRotation) {
      snake.angle = targetAngle;
    } else {
      snake.angle += maxRotation * angleDiff.sign;
    }

    // Move forward in the direction we're facing
    final moveDirection = Vector2(cos(snake.angle), sin(snake.angle));
    final moveDistance = snake.speed * dt;

    snake.position.add(moveDirection * moveDistance);

    // Critical: Hard boundary enforcement as last resort
    _enforceHardBoundaries(snake);
  }

  void _enforceHardBoundaries(AiSnakeData snake) {
    final bounds = SlitherGame.playArea;
    final margin = 50.0; // Small margin to prevent exact boundary touching

    bool hitBoundary = false;

    if (snake.position.x <= bounds.left + margin) {
      snake.position.x = bounds.left + margin;
      snake.angle = 0.0; // Face right
      snake.targetDirection = Vector2(1, 0);
      hitBoundary = true;
    } else if (snake.position.x >= bounds.right - margin) {
      snake.position.x = bounds.right - margin;
      snake.angle = pi; // Face left
      snake.targetDirection = Vector2(-1, 0);
      hitBoundary = true;
    }

    if (snake.position.y <= bounds.top + margin) {
      snake.position.y = bounds.top + margin;
      snake.angle = pi / 2; // Face down
      snake.targetDirection = Vector2(0, 1);
      hitBoundary = true;
    } else if (snake.position.y >= bounds.bottom - margin) {
      snake.position.y = bounds.bottom - margin;
      snake.angle = -pi / 2; // Face up
      snake.targetDirection = Vector2(0, -1);
      hitBoundary = true;
    }

    if (hitBoundary) {
      snake.aiState = AiState.seeking_center;
    }
  }

  bool _isNearAnyBoundary(Vector2 position, double threshold) {
    final bounds = SlitherGame.playArea;
    return position.x < bounds.left + threshold ||
        position.x > bounds.right - threshold ||
        position.y < bounds.top + threshold ||
        position.y > bounds.bottom - threshold;
  }

  double _normalizeAngle(double angle) {
    while (angle > pi) angle -= 2 * pi;
    while (angle < -pi) angle += 2 * pi;
    return angle;
  }

  void _updateSnakeBody(AiSnakeData snake) {
    // Update path tracking
    if (snake.path.isEmpty || snake.position.distanceTo(snake.path.first) > 2.0) {
      snake.path.insert(0, snake.position.clone());
    }

    // Update body segments to follow the path
    for (int i = 0; i < snake.bodySegments.length; i++) {
      final targetDistance = (i + 1) * snake.segmentSpacing;
      snake.bodySegments[i].setFrom(_getPointOnPath(snake, targetDistance));
    }

    // Limit path length for memory efficiency
    final maxPathLength = snake.bodySegments.length * 3 + 20;
    if (snake.path.length > maxPathLength) {
      snake.path.removeRange(maxPathLength, snake.path.length);
    }
  }

  Vector2 _getPointOnPath(AiSnakeData snake, double distance) {
    final fullPath = [snake.position, ...snake.path];

    if (fullPath.length < 2) return snake.position.clone();

    double accumulatedDistance = 0.0;

    for (int i = 0; i < fullPath.length - 1; i++) {
      final segmentStart = fullPath[i];
      final segmentEnd = fullPath[i + 1];
      final segmentLength = segmentStart.distanceTo(segmentEnd);

      if (accumulatedDistance + segmentLength >= distance) {
        final remainingDistance = distance - accumulatedDistance;
        final direction = (segmentEnd - segmentStart).normalized();
        return segmentStart + direction * remainingDistance;
      }

      accumulatedDistance += segmentLength;
    }

    return fullPath.last.clone();
  }

  void _checkFoodConsumption(AiSnakeData snake) {
    final eatRadius = snake.headRadius + 10.0;
    final eatRadiusSquared = eatRadius * eatRadius;
    final eatenFood = <FoodModel>[];

    for (final food in foodManager.foodList) {
      if (snake.position.distanceToSquared(food.position) <= eatRadiusSquared) {
        eatenFood.add(food);
      }
    }

    for (final food in eatenFood) {
      foodManager.removeFood(food);
      _growSnake(snake, food.growth);
      foodManager.spawnFood();
    }
  }

  FoodModel? _findNearestFood(Vector2 position, double maxDistance) {
    FoodModel? nearest;
    double nearestDistanceSquared = maxDistance * maxDistance;

    for (final food in foodManager.foodList) {
      final distanceSquared = position.distanceToSquared(food.position);
      if (distanceSquared < nearestDistanceSquared) {
        nearest = food;
        nearestDistanceSquared = distanceSquared;
      }
    }

    return nearest;
  }

  /// Call this once at startup to build your zone grid.
  void _initializeSpawnZones() {
    final bounds = SlitherGame.worldBounds;
    // Decide how many rows/columns you want, e.g., a 10×10 grid for 100 snakes.
    final gridSize = sqrt(numberOfSnakes).floor(); // e.g. 10
    final zoneWidth  = bounds.width  / gridSize;
    final zoneHeight = bounds.height / gridSize;

    _spawnZones = List.generate(gridSize * gridSize, (i) {
      final row = i ~/ gridSize;
      final col = i %  gridSize;
      return Rect.fromLTWH(
        bounds.left   + col * zoneWidth,
        bounds.top    + row * zoneHeight,
        zoneWidth,
        zoneHeight,
      );
    });

    _spawnZones.shuffle(_random);
  }

  /// Spawns snakes one per zone (or more evenly if fewer/more snakes than zones).
  void _spawnSnake() {
    // Pick the next zone in a round-robin fashion
    final zone = _spawnZones[_nextZoneIndex++ % _spawnZones.length];

    // Now choose a random point inside that zone:
    final x = zone.left   + _random.nextDouble() * zone.width;
    final y = zone.top    + _random.nextDouble() * zone.height;
    final position = Vector2(x, y);

    // The rest of your existing initialization...
    final initialDirection = Vector2.random(_random)..normalize();
    final headRadius = 12.0 + _random.nextDouble() * 6.0;
    final snakeData = AiSnakeData(
      position: position,
      skinColors: _getRandomSkin(),
      targetDirection: initialDirection,
      headRadius: headRadius,
      bodyRadius: headRadius - 1.0,
      segmentSpacing: headRadius * 0.6,
      speed: 80.0 + _random.nextDouble() * 40.0,
      segmentCount: 8 + _random.nextInt(12),
      minRadius: headRadius,
      maxRadius: 35.0,
    );
    // …
    snakes.add(snakeData);
  }

  void _growSnake(AiSnakeData snake, int amount) {
    final oldCount = snake.segmentCount;
    snake.segmentCount += amount;

    for (int i = 0; i < amount; i++) {
      snake.bodySegments.add(snake.bodySegments.last.clone());
    }

    // Update size based on growth
    if (snake.headRadius < snake.maxRadius) {
      final growthBonus = (snake.segmentCount / 20).floor() - (oldCount / 20).floor();
      if (growthBonus > 0) {
        snake.headRadius = min(snake.headRadius + growthBonus, snake.maxRadius);
        snake.bodyRadius = snake.headRadius - 1.0;
      }
    }
  }

  void killSnakeAndScatterFood(AiSnakeData snake) {
    // Scatter food from dead snake
    for (int i = 0; i < snake.bodySegments.length; i += 2) {
      final seg = snake.bodySegments[i];
      foodManager.spawnFoodAt(seg);
    }
    foodManager.spawnFoodAt(snake.position);

    snakes.remove(snake);
  }

  void spawnNewSnake() => _spawnSnake();

  List<Color> _getRandomSkin() {
    final baseHue = _random.nextDouble() * 360;
    return List.generate(6, (index) {
      final hue = (baseHue + index * 15) % 360;
      return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
    });
  }
}