// lib/modules/game/components/food/food_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';

class FoodManager {
  final Random _random = Random();
  final int foodCount = 80;
  final List<FoodModel> foodList = [];
  final double spawnRadius;
  final double maxDistance;
  final Rect worldBounds;
  int _updateCounter = 0;
  bool _initialFoodSpawned = false;

  // Track total food to prevent lag
  static const int MAX_FOOD_LIMIT = 150; // Increased slightly for snake deaths
  static const int OPTIMAL_FOOD_COUNT = 80;

  final List<Color> _foodColors = [
    Colors.redAccent.shade400,
    Colors.greenAccent.shade400,
    Colors.blueAccent.shade400,
    Colors.purpleAccent.shade400,
    Colors.orangeAccent.shade400,
    Colors.cyanAccent.shade400,
    Colors.pinkAccent.shade400,
    Colors.yellowAccent.shade700,
    Colors.tealAccent.shade400,
    Colors.indigoAccent.shade400,
    Colors.limeAccent.shade400,
    Colors.amberAccent.shade400,
  ];

  FoodManager({
    required this.worldBounds,
    required this.spawnRadius,
    required this.maxDistance
  });

  void initialize(Vector2 playerPosition) {
    if (_initialFoodSpawned) return;

    for (int i = 0; i < foodCount; i++) {
      spawnFood(playerPosition);
    }
    _initialFoodSpawned = true;
    print('Initial food spawned: ${foodList.length} items');
  }

  void update(double dt, Vector2 playerPosition) {
    _updateCounter++;

    // Update all food animations
    for (final food in foodList) {
      food.updateAnimations(dt);
    }

    if (_updateCounter < 60) return;
    _updateCounter = 0;

    // Remove consumed food and distant food
    int removedCount = 0;
    foodList.removeWhere((food) {
      if (food.shouldBeRemoved) {
        removedCount++;
        return true;
      }
      if (food.state == FoodState.normal &&
          playerPosition.distanceTo(food.position) > maxDistance) {
        removedCount++;
        return true;
      }
      return false;
    });

    // Only spawn new food if below optimal count
    int spawnedCount = 0;
    while (foodList.length < OPTIMAL_FOOD_COUNT && foodList.length < MAX_FOOD_LIMIT) {
      spawnFood(playerPosition);
      spawnedCount++;
    }

    if (removedCount > 5 || spawnedCount > 5) {
      print('Food Update -> Removed: $removedCount, Spawned: $spawnedCount, Total: ${foodList.length}');
    }
  }

  void spawnFood(Vector2 playerPosition) {
    if (foodList.length >= MAX_FOOD_LIMIT) return;

    final x = playerPosition.x + _random.nextDouble() * spawnRadius * 2 - spawnRadius;
    final y = playerPosition.y + _random.nextDouble() * spawnRadius * 2 - spawnRadius;

    final clampedX = x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
    final clampedY = y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);
    final position = Vector2(clampedX, clampedY);

    final color = _foodColors[_random.nextInt(_foodColors.length)];

    final double rand = _random.nextDouble();
    double radius;
    int growth;

    if (rand < 0.70) {
      radius = 10.0;
      growth = 1;
    } else if (rand < 0.90) {
      radius = 15.0;
      growth = 3;
    } else {
      radius = 20.0;
      growth = 5;
    }

    foodList.add(FoodModel(
      position: position,
      color: color,
      radius: radius,
      growth: growth,
    ));
  }

  void spawnFoodAt(Vector2 position) {
    if (foodList.length >= MAX_FOOD_LIMIT) return;

    final color = _foodColors[_random.nextInt(_foodColors.length)];
    const radius = 10.0;
    const growth = 1;

    foodList.add(FoodModel(
      position: position,
      color: color,
      radius: radius,
      growth: growth,
    ));
  }

  // NEW METHOD: Scatter exactly 10-15 food pellets along AI snake body
  void scatterFoodFromAiSnakeBody(Vector2 snakeHeadPosition, double snakeHeadRadius,
      List<Vector2> bodySegments, bool isRevengeDeath) {

    // Decide food amount: 10-15 pellets (more for revenge)
    final foodAmount = isRevengeDeath
        ? 13 + _random.nextInt(3)  // 13-15 for revenge
        : 10 + _random.nextInt(6); // 10-15 normally

    // Check space available
    final currentFoodCount = foodList.length;
    final spaceAvailable = MAX_FOOD_LIMIT - currentFoodCount;
    final actualFoodAmount = min(foodAmount, spaceAvailable);

    if (actualFoodAmount <= 0) {
      print('Food limit reached, no food scattered from AI snake death');
      return;
    }

    print('AI Snake death: Scattering $actualFoodAmount food pellets along body');

    // Distribute food evenly along the snake's body
    final totalPositions = bodySegments.length;
    if (totalPositions == 0) {
      // If no body segments, scatter around head
      _scatterAroundPoint(snakeHeadPosition, actualFoodAmount, snakeHeadRadius);
      return;
    }

    // Calculate step to distribute food evenly
    final step = max(1, totalPositions ~/ actualFoodAmount);
    int foodSpawned = 0;

    // Place food along body segments
    for (int i = 0; i < totalPositions && foodSpawned < actualFoodAmount; i += step) {
      final segmentPos = bodySegments[i];

      // Add some randomness to position
      final angle = _random.nextDouble() * 2 * pi;
      final distance = 10 + _random.nextDouble() * 20; // 10-30 pixels from segment

      final foodPosition = Vector2(
        segmentPos.x + cos(angle) * distance,
        segmentPos.y + sin(angle) * distance,
      );

      // Clamp to world bounds
      foodPosition.x = foodPosition.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
      foodPosition.y = foodPosition.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

      // Determine food size
      final sizeRoll = _random.nextDouble();
      double radius;
      int growth;

      if (isRevengeDeath) {
        // Better food for revenge kills
        if (sizeRoll < 0.2) {
          radius = 20.0; growth = 5;
        } else if (sizeRoll < 0.5) {
          radius = 15.0; growth = 3;
        } else {
          radius = 10.0; growth = 1;
        }
      } else {
        // Normal distribution
        if (sizeRoll < 0.1) {
          radius = 20.0; growth = 5;
        } else if (sizeRoll < 0.25) {
          radius = 15.0; growth = 3;
        } else {
          radius = 10.0; growth = 1;
        }
      }

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      foodList.add(FoodModel(
        position: foodPosition,
        color: color,
        radius: radius,
        growth: growth,
        skipSpawnAnimation: false,
      ));

      foodSpawned++;
    }

    // If we couldn't place all food along body, scatter remaining around head
    if (foodSpawned < actualFoodAmount) {
      _scatterAroundPoint(snakeHeadPosition, actualFoodAmount - foodSpawned, snakeHeadRadius);
    }
  }

  // Helper method to scatter food around a point
  void _scatterAroundPoint(Vector2 center, int amount, double radius) {
    for (int i = 0; i < amount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = radius + _random.nextDouble() * radius;

      final position = Vector2(
        center.x + cos(angle) * distance,
        center.y + sin(angle) * distance,
      );

      position.x = position.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
      position.y = position.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      // Simple size distribution
      final sizeRoll = _random.nextDouble();
      double foodRadius;
      int foodGrowth;

      if (sizeRoll < 0.1) {
        foodRadius = 20.0; foodGrowth = 5;
      } else if (sizeRoll < 0.25) {
        foodRadius = 15.0; foodGrowth = 3;
      } else {
        foodRadius = 10.0; foodGrowth = 1;
      }

      foodList.add(FoodModel(
        position: position,
        color: color,
        radius: foodRadius,
        growth: foodGrowth,
        skipSpawnAnimation: false,
      ));
    }
  }

  // OLD METHOD: Keep for backward compatibility but redirect to new method
  void scatterFoodFromAiSnakeSlitherStyle(Vector2 snakeHeadPosition, double snakeHeadRadius,
      int segmentCount, List<Vector2> bodySegments) {
    // Redirect to new method with 10-15 food pellets
    scatterFoodFromAiSnakeBody(snakeHeadPosition, snakeHeadRadius, bodySegments, false);
  }

  // Player death food scattering
  void scatterFoodFromSnake(Vector2 snakePosition, double snakeHeadRadius, int segmentCount) {
    final baseFood = (segmentCount / 4).round().clamp(2, 10);
    final bonusFood = (snakeHeadRadius / 10).round();
    final totalFood = baseFood + bonusFood;

    // Check space available
    final spaceAvailable = MAX_FOOD_LIMIT - foodList.length;
    final actualFood = min(totalFood, spaceAvailable);

    print('Scattering $actualFood food items from player snake death');

    for (int i = 0; i < actualFood; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * 80 + 20;
      final offsetX = cos(angle) * distance;
      final offsetY = sin(angle) * distance;

      final foodPosition = Vector2(
        snakePosition.x + offsetX,
        snakePosition.y + offsetY,
      );

      foodPosition.x = foodPosition.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
      foodPosition.y = foodPosition.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

      double radius;
      int growth;
      final sizeRoll = _random.nextDouble();

      if (sizeRoll < 0.1) {
        radius = 20.0; growth = 5;
      } else if (sizeRoll < 0.25) {
        radius = 15.0; growth = 3;
      } else {
        radius = 10.0; growth = 1;
      }

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      foodList.add(FoodModel(
        position: foodPosition,
        color: color,
        radius: radius,
        growth: growth,
        skipSpawnAnimation: false,
      ));
    }
  }

  // Legacy method - redirect
  void scatterFoodFromAiSnake(Vector2 snakeHeadPosition, double snakeHeadRadius,
      int segmentCount, List<Vector2> bodySegments) {
    scatterFoodFromAiSnakeBody(snakeHeadPosition, snakeHeadRadius, bodySegments, false);
  }

  void startConsumingFood(FoodModel food, Vector2 snakeHeadPosition) {
    food.startConsumption(snakeHeadPosition);
  }

  List<FoodModel> get eatableFoodList =>
      foodList.where((food) => food.canBeEaten).toList();

  void removeFood(FoodModel food) {
    foodList.remove(food);
  }
}