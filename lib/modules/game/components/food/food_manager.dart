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

  final List<Color> _foodColors = [
    Colors.redAccent, Colors.greenAccent, Colors.blueAccent,
    Colors.purpleAccent, Colors.orangeAccent, Colors.cyanAccent, Colors.pinkAccent,
  ];

  FoodManager({
    required this.worldBounds,
    required this.spawnRadius,
    required this.maxDistance
  });

  void update(double dt, Vector2 playerPosition) {
    _updateCounter++;

    print("check here food list count<><><><><><><><><><><><><><>${foodList.length}");

    // Update food animations
    _updateFoodAnimations(dt);

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
      print('=========================Food Update -> Removed: $removedCount, Spawned: $spawnedCount, Total: ${foodList.length}');
    }
  }

  void _updateFoodAnimations(double dt) {
    for (final food in foodList) {
      food.updateConsumption(dt);
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

  // Modified to start consumption animation instead of immediate removal
  void startConsumingFood(FoodModel food, Vector2 snakeHeadPosition) {
    food.startConsumption(snakeHeadPosition);
  }

  // Get list of food that can be eaten (not being consumed)
  List<FoodModel> get eatableFoodList =>
      foodList.where((food) => food.canBeEaten).toList();

  // Legacy method for backward compatibility - now starts consumption
  void removeFood(FoodModel food) {
    // For immediate removal (like when spawning from dead snakes)
    foodList.remove(food);
  }
}