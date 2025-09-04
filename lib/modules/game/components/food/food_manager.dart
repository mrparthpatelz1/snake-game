// lib/modules/game/components/food/food_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';

class FoodManager {
  final Random _random = Random();
  final int foodCount = 100;
  final List<FoodModel> foodList = [];
  final double spawnRadius;
  final double maxDistance;
  final Rect worldBounds;
  int _updateCounter = 0;
  bool _initialFoodSpawned = false; // Track if initial food has been spawned

  final List<Color> _foodColors = [
    Colors.redAccent, Colors.greenAccent, Colors.blueAccent,
    Colors.purpleAccent, Colors.orangeAccent, Colors.cyanAccent, Colors.pinkAccent,
  ];

  FoodManager({
    required this.worldBounds,
    required this.spawnRadius,
    required this.maxDistance
  });

  void initialize(Vector2 playerPosition) {
    if (_initialFoodSpawned) return;

    // Spawn initial food immediately when game starts
    for (int i = 0; i < foodCount; i++) {
      spawnFood(playerPosition);
    }
    _initialFoodSpawned = true;
    print('Initial food spawned: ${foodList.length} items');
  }

  void update(double dt, Vector2 playerPosition) {
    _updateCounter++;

    // Update all food animations (including spawn animations)
    for (final food in foodList) {
      food.updateAnimations(dt);
    }

    print("Food list count: ${foodList.length}");

    if (_updateCounter < 60) return; // Only run cleanup logic once per second
    _updateCounter = 0;

    final initialCount = foodList.length;

    // Remove consumed food and food that is too far from the player
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

    // Spawn new food if needed
    int spawnedCount = 0;
    while (foodList.length < foodCount) {
      spawnFood(playerPosition);
      spawnedCount++;
    }

    if (removedCount > 0 || spawnedCount > 0) {
      print('Food Update -> Removed: $removedCount, Spawned: $spawnedCount, Total: ${foodList.length}');
    }
  }

  void spawnFood(Vector2 playerPosition) {
    final x = playerPosition.x + _random.nextDouble() * spawnRadius * 2 - spawnRadius;
    final y = playerPosition.y + _random.nextDouble() * spawnRadius * 2 - spawnRadius;

    final clampedX = x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
    final clampedY = y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);
    final position = Vector2(clampedX, clampedY);

    final color = _foodColors[_random.nextInt(_foodColors.length)];

    final double rand = _random.nextDouble();
    double radius;
    int growth;

    if (rand < 0.70) { // 70% chance for a small pallet
      radius = 6.0;
      growth = 1;
    } else if (rand < 0.90) { // 20% chance for a medium pallet
      radius = 10.0;
      growth = 3;
    } else { // 10% chance for a large pallet
      radius = 14.0;
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
    final color = _foodColors[_random.nextInt(_foodColors.length)];
    const radius = 6.0;
    const growth = 1;

    foodList.add(FoodModel(
      position: position,
      color: color,
      radius: radius,
      growth: growth,
    ));
  }

  // NEW: Spawn multiple food items with varied sizes (for snake death)
  void scatterFoodFromSnake(Vector2 snakePosition, double snakeHeadRadius, int segmentCount) {
    final baseFood = (segmentCount / 3).round().clamp(3, 15); // 3-15 food items
    final bonusFood = (snakeHeadRadius / 8).round(); // Bonus based on size
    final totalFood = baseFood + bonusFood;

    print('Scattering $totalFood food items from snake death (segments: $segmentCount, radius: $snakeHeadRadius)');

    for (int i = 0; i < totalFood; i++) {
      // Random position around the snake's death location
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * 100 + 20; // 20-120 pixels away
      final offsetX = cos(angle) * distance;
      final offsetY = sin(angle) * distance;

      final foodPosition = Vector2(
        snakePosition.x + offsetX,
        snakePosition.y + offsetY,
      );

      // Clamp to world bounds
      foodPosition.x = foodPosition.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
      foodPosition.y = foodPosition.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

      // Varied food sizes - bigger snakes drop bigger food
      double radius;
      int growth;
      final sizeRoll = _random.nextDouble();

      if (snakeHeadRadius > 25) { // Large snake
        if (sizeRoll < 0.3) {
          radius = 14.0; growth = 5; // Large food
        } else if (sizeRoll < 0.6) {
          radius = 10.0; growth = 3; // Medium food
        } else {
          radius = 6.0; growth = 1; // Small food
        }
      } else if (snakeHeadRadius > 18) { // Medium snake
        if (sizeRoll < 0.2) {
          radius = 14.0; growth = 5; // Large food
        } else if (sizeRoll < 0.5) {
          radius = 10.0; growth = 3; // Medium food
        } else {
          radius = 6.0; growth = 1; // Small food
        }
      } else { // Small snake
        if (sizeRoll < 0.1) {
          radius = 10.0; growth = 3; // Medium food
        } else {
          radius = 6.0; growth = 1; // Small food
        }
      }

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      foodList.add(FoodModel(
        position: foodPosition,
        color: color,
        radius: radius,
        growth: growth,
        skipSpawnAnimation: false, // Keep spawn animation for scattered food
      ));
    }
  }

  // Modified to start consumption animation instead of immediate removal
  void startConsumingFood(FoodModel food, Vector2 snakeHeadPosition) {
    food.startConsumption(snakeHeadPosition);
  }

  // Get list of food that can be eaten (not being consumed or spawning)
  List<FoodModel> get eatableFoodList =>
      foodList.where((food) => food.canBeEaten).toList();

  // Legacy method for backward compatibility - now starts consumption
  void removeFood(FoodModel food) {
    // For immediate removal (like when spawning from dead snakes)
    foodList.remove(food);
  }
}