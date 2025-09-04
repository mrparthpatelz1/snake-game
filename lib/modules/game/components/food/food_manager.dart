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
  bool _initialFoodSpawned = false;

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

    if (_updateCounter < 60) return; // Only run cleanup logic once per second
    _updateCounter = 0;

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

    if (removedCount > 5 || spawnedCount > 5) { // Reduce debug spam
      print('Food Update -> Removed: $removedCount, Spawned: $spawnedCount, Total: ${foodList.length}');
    }

    print("<><><><<>><><><><><><><><><><><><><><><><><><>><><><><><>${foodList.length}");
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

    if (rand < 0.70) {
      radius = 6.0;
      growth = 1;
    } else if (rand < 0.90) {
      radius = 10.0;
      growth = 3;
    } else {
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

  // NEW: Slither.io style food scattering for AI snakes
  void scatterFoodFromAiSnake(Vector2 snakeHeadPosition, double snakeHeadRadius,
      int segmentCount, List<Vector2> bodySegments) {
    // Calculate food amount based on snake size (similar to slither.io)
    final foodAmount = _calculateSlitherStyleFoodAmount(segmentCount, snakeHeadRadius);

    print('Scattering $foodAmount food items from AI snake (segments: $segmentCount, radius: ${snakeHeadRadius.toStringAsFixed(1)})');

    // Create a more natural distribution pattern
    final allSegments = [snakeHeadPosition, ...bodySegments];
    final segmentStep = max(1, (allSegments.length / (foodAmount * 0.8)).round()); // Use 80% of segments

    int foodSpawned = 0;
    for (int i = 0; i < allSegments.length && foodSpawned < foodAmount; i += segmentStep) {
      final segmentPos = allSegments[i];

      // Create 1-3 food items per selected segment
      final foodPerSegment = _random.nextInt(3) + 1;
      for (int j = 0; j < foodPerSegment && foodSpawned < foodAmount; j++) {
        final foodPosition = _getSlitherStyleFoodPosition(segmentPos, j, foodPerSegment);
        final foodData = _getSlitherStyleFoodSize(snakeHeadRadius, i, allSegments.length);

        // Clamp to world bounds
        foodPosition.x = foodPosition.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
        foodPosition.y = foodPosition.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

        final color = _foodColors[_random.nextInt(_foodColors.length)];

        foodList.add(FoodModel(
          position: foodPosition,
          color: color,
          radius: foodData['radius'],
          growth: foodData['growth'],
          skipSpawnAnimation: false,
        ));

        foodSpawned++;
      }
    }

    // Add some extra scattered food around the death area for visual effect
    _addExtraScatteredFood(snakeHeadPosition, snakeHeadRadius, (foodAmount * 0.3).round());
  }

  // Calculate food amount like slither.io (more food = bigger snake)
  int _calculateSlitherStyleFoodAmount(int segmentCount, double headRadius) {
    final baseFood = (segmentCount * 0.4).round(); // 40% of segments become food
    final sizeBonus = ((headRadius - 12.0) * 0.5).round(); // Bonus for larger snakes
    return (baseFood + sizeBonus).clamp(8, 35); // Min 8, Max 35 food items
  }

  // Get slither.io style food position with natural scattering
  Vector2 _getSlitherStyleFoodPosition(Vector2 segmentPos, int foodIndex, int totalFoodAtSegment) {
    if (totalFoodAtSegment == 1) {
      // Single food: small random offset
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * 15 + 5; // 5-20 pixels
      return Vector2(
        segmentPos.x + cos(angle) * distance,
        segmentPos.y + sin(angle) * distance,
      );
    } else {
      // Multiple food: spread them around the segment
      final baseAngle = (foodIndex / totalFoodAtSegment) * 2 * pi;
      final angleVariation = (_random.nextDouble() - 0.5) * pi * 0.4; // ±36 degrees variation
      final angle = baseAngle + angleVariation;
      final distance = _random.nextDouble() * 20 + 10; // 10-30 pixels
      return Vector2(
        segmentPos.x + cos(angle) * distance,
        segmentPos.y + sin(angle) * distance,
      );
    }
  }

  // Get slither.io style food size (head area = bigger food, tail = smaller food)
  Map<String, dynamic> _getSlitherStyleFoodSize(double snakeHeadRadius, int segmentIndex, int totalSegments) {
    // Food size decreases from head to tail
    final positionFactor = 1.0 - (segmentIndex / totalSegments); // 1.0 at head, 0.0 at tail
    final sizeFactor = (positionFactor * 0.7) + 0.3; // 0.3 to 1.0 range

    final sizeRoll = _random.nextDouble();

    if (snakeHeadRadius > 25 && sizeFactor > 0.7) { // Large snake, near head
      if (sizeRoll < 0.5) return {'radius': 14.0, 'growth': 5}; // Large food
      if (sizeRoll < 0.8) return {'radius': 10.0, 'growth': 3}; // Medium food
      return {'radius': 6.0, 'growth': 1}; // Small food
    } else if (snakeHeadRadius > 18 && sizeFactor > 0.5) { // Medium snake, middle sections
      if (sizeRoll < 0.3) return {'radius': 14.0, 'growth': 5}; // Large food
      if (sizeRoll < 0.6) return {'radius': 10.0, 'growth': 3}; // Medium food
      return {'radius': 6.0, 'growth': 1}; // Small food
    } else { // Small snake or tail sections
      if (sizeRoll < 0.15) return {'radius': 10.0, 'growth': 3}; // Medium food (rare)
      return {'radius': 6.0, 'growth': 1}; // Small food (common)
    }
  }

  // Add extra scattered food around death area for visual richness
  void _addExtraScatteredFood(Vector2 centerPos, double radius, int extraCount) {
    for (int i = 0; i < extraCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * radius * 2 + radius; // Spread around the snake
      final position = Vector2(
        centerPos.x + cos(angle) * distance,
        centerPos.y + sin(angle) * distance,
      );

      // Clamp to world bounds
      position.x = position.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
      position.y = position.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      // Extra food is mostly small with some medium
      final isLarger = _random.nextDouble() < 0.2;
      final foodRadius = isLarger ? 10.0 : 6.0;
      final foodGrowth = isLarger ? 3 : 1;

      foodList.add(FoodModel(
        position: position,
        color: color,
        radius: foodRadius,
        growth: foodGrowth,
        skipSpawnAnimation: false,
      ));
    }
  }

  // Keep the original method for player death (scatters randomly around position)
  void scatterFoodFromSnake(Vector2 snakePosition, double snakeHeadRadius, int segmentCount) {
    final baseFood = (segmentCount / 3).round().clamp(3, 15);
    final bonusFood = (snakeHeadRadius / 8).round();
    final totalFood = baseFood + bonusFood;

    print('Scattering $totalFood food items from player snake death');

    for (int i = 0; i < totalFood; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * 100 + 20;
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

      if (snakeHeadRadius > 25) {
        if (sizeRoll < 0.3) { radius = 14.0; growth = 5; }
        else if (sizeRoll < 0.6) { radius = 10.0; growth = 3; }
        else { radius = 6.0; growth = 1; }
      } else if (snakeHeadRadius > 18) {
        if (sizeRoll < 0.2) { radius = 14.0; growth = 5; }
        else if (sizeRoll < 0.5) { radius = 10.0; growth = 3; }
        else { radius = 6.0; growth = 1; }
      } else {
        if (sizeRoll < 0.1) { radius = 10.0; growth = 3; }
        else { radius = 6.0; growth = 1; }
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

  void startConsumingFood(FoodModel food, Vector2 snakeHeadPosition) {
    food.startConsumption(snakeHeadPosition);
  }

  List<FoodModel> get eatableFoodList =>
      foodList.where((food) => food.canBeEaten).toList();

  void removeFood(FoodModel food) {
    foodList.remove(food);
  }
}