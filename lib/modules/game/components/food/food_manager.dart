// lib/app/modules/game/components/food/food_manager.dart

// import 'dart';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';

class FoodManager {
  final Random _random = Random();
  final int foodCount = 300; // Adjusted to 300 as requested
  final List<FoodModel> foodList = [];
  final double spawnRadius;
  final double maxDistance;
  final Rect worldBounds;
  int _updateCounter = 0;

  final List<Color> _foodColors = [
    Colors.redAccent, Colors.greenAccent, Colors.blueAccent,
    Colors.purpleAccent, Colors.orangeAccent, Colors.cyanAccent, Colors.pinkAccent,
  ];

  FoodManager({required this.worldBounds, required this.spawnRadius, required this.maxDistance}) {
    // Initial food spawn is now handled in the first update call
  }

  void update(double dt, Vector2 playerPosition) {
    _updateCounter++;
    if (_updateCounter < 60) return; // Only run this logic once per second (approx)
    _updateCounter = 0;

    final initialCount = foodList.length;
    // print('Before removal: $initialCount');

    // Remove food that is too far from the player
    int removedCount = 0;
    foodList.removeWhere((food) {
      if (playerPosition.distanceTo(food.position) > maxDistance) {
        removedCount++;
        return true;
      }
      return false;
    });

    final countAfterRemoval = foodList.length;
    // if (removedCount > 0) {
    //   print('Removed: $removedCount food items. Count is now: $countAfterRemoval');
    // }

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

  void removeFood(FoodModel food) {
    foodList.remove(food);
  }
}