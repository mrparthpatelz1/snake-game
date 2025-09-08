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

  // IMPROVED: More vibrant food colors with better variety
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

    final clampedX = x.clamp(worldBounds.left + 20.0, worldBounds.right - 20.0);
    final clampedY = y.clamp(worldBounds.top + 20.0, worldBounds.bottom - 20.0);
    final position = Vector2(clampedX, clampedY);

    final color = _foodColors[_random.nextInt(_foodColors.length)];

    final double rand = _random.nextDouble();
    double radius;
    int growth;

    // IMPROVED: Increased sizes for all food types
    if (rand < 0.70) {
      radius = 10.0;  // Increased from 6.0
      growth = 1;
    } else if (rand < 0.90) {
      radius = 16.0;  // Increased from 10.0
      growth = 3;
    } else {
      radius = 22.0;  // Increased from 14.0
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
    const radius = 10.0;  // Increased from 6.0
    const growth = 1;

    foodList.add(FoodModel(
      position: position,
      color: color,
      radius: radius,
      growth: growth,
    ));
  }

  // IMPROVED: Better slither.io style food scattering for AI snakes
  void scatterFoodFromAiSnakeSlitherStyle(Vector2 snakeHeadPosition, double snakeHeadRadius,
      int segmentCount, List<Vector2> bodySegments) {
    // Calculate food amount based on snake size (similar to slither.io)
    final foodAmount = _calculateSlitherStyleFoodAmount(segmentCount, snakeHeadRadius);

    print('Scattering $foodAmount food items from AI snake (segments: $segmentCount, radius: ${snakeHeadRadius.toStringAsFixed(1)})');

    // IMPROVED: Create more natural distribution following the snake's body
    final allPositions = [snakeHeadPosition, ...bodySegments];
    final totalPositions = allPositions.length;

    // Calculate how many food items per position section
    final foodPerSection = foodAmount / totalPositions;
    int foodSpawned = 0;

    // Scatter food along the entire snake body path
    for (int i = 0; i < totalPositions && foodSpawned < foodAmount; i++) {
      final segmentPos = allPositions[i];

      // Calculate how many food items for this section
      final foodForThisSection = (foodPerSection * (1 + _random.nextDouble())).round().clamp(1, 4);

      for (int j = 0; j < foodForThisSection && foodSpawned < foodAmount; j++) {
        final foodPosition = _getSlitherStyleFoodPositionImproved(segmentPos, i, totalPositions, j, foodForThisSection);
        final foodData = _getSlitherStyleFoodSizeImproved(snakeHeadRadius, i, totalPositions);

        // Clamp to world bounds
        foodPosition.x = foodPosition.x.clamp(worldBounds.left + 20.0, worldBounds.right - 20.0);
        foodPosition.y = foodPosition.y.clamp(worldBounds.top + 20.0, worldBounds.bottom - 20.0);

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

    // Add some extra scattered food in a wider radius around the death location
    _addExtraScatteredFoodImproved(snakeHeadPosition, snakeHeadRadius, (foodAmount * 0.2).round());
  }

  // Calculate food amount like slither.io (more food = bigger snake)
  int _calculateSlitherStyleFoodAmount(int segmentCount, double headRadius) {
    final baseFood = (segmentCount * 0.35).round(); // 35% of segments become food
    final sizeBonus = ((headRadius - 12.0) * 0.4).round(); // Bonus for larger snakes
    return (baseFood + sizeBonus).clamp(6, 25); // Min 6, Max 25 food items (reduced to prevent lag)
  }

  // IMPROVED: Get slither.io style food position with more natural scattering
  Vector2 _getSlitherStyleFoodPositionImproved(Vector2 segmentPos, int segmentIndex, int totalSegments, int foodIndex, int totalFoodAtSegment) {
    // Create a more natural spread based on segment position
    final segmentProgress = segmentIndex / totalSegments; // 0.0 = head, 1.0 = tail

    if (totalFoodAtSegment == 1) {
      // Single food: random offset with bias towards the sides
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * 25 + 10; // 10-35 pixels
      final sideInfluence = sin(angle) * 5; // Add side bias

      return Vector2(
        segmentPos.x + cos(angle) * distance + sideInfluence,
        segmentPos.y + sin(angle) * distance,
      );
    } else {
      // Multiple food: create clusters with some randomness
      final baseAngle = (foodIndex / totalFoodAtSegment) * 2 * pi;
      final clusterVariation = (_random.nextDouble() - 0.5) * pi * 0.5; // ±45 degrees variation
      final angle = baseAngle + clusterVariation;

      // Distance varies based on position in snake (head = wider spread, tail = tighter)
      final baseDistance = 15 + (segmentProgress * 20); // 15-35 pixels
      final distance = baseDistance + (_random.nextDouble() - 0.5) * 10;

      return Vector2(
        segmentPos.x + cos(angle) * distance,
        segmentPos.y + sin(angle) * distance,
      );
    }
  }

  // IMPROVED: Get slither.io style food size with better distribution and increased sizes
  Map<String, dynamic> _getSlitherStyleFoodSizeImproved(double snakeHeadRadius, int segmentIndex, int totalSegments) {
    // Food size decreases from head to tail, but not linearly
    final positionFactor = 1.0 - (segmentIndex / totalSegments); // 1.0 at head, 0.0 at tail
    final sizeFactor = (positionFactor * 0.6) + 0.4; // 0.4 to 1.0 range (more balanced)

    final sizeRoll = _random.nextDouble();

    // Head area (first 25% of segments) - premium food with increased sizes
    if (positionFactor > 0.75) {
      if (snakeHeadRadius > 25) {
        if (sizeRoll < 0.4) return {'radius': 22.0, 'growth': 5}; // Large food (increased)
        if (sizeRoll < 0.7) return {'radius': 16.0, 'growth': 3}; // Medium food (increased)
        return {'radius': 10.0, 'growth': 1}; // Small food (increased)
      } else {
        if (sizeRoll < 0.25) return {'radius': 22.0, 'growth': 5}; // Large food
        if (sizeRoll < 0.55) return {'radius': 16.0, 'growth': 3}; // Medium food
        return {'radius': 10.0, 'growth': 1}; // Small food
      }
    }
    // Body area (middle 50% of segments) - mixed food with increased sizes
    else if (positionFactor > 0.25) {
      if (snakeHeadRadius > 20) {
        if (sizeRoll < 0.2) return {'radius': 22.0, 'growth': 5}; // Large food
        if (sizeRoll < 0.5) return {'radius': 16.0, 'growth': 3}; // Medium food
        return {'radius': 10.0, 'growth': 1}; // Small food
      } else {
        if (sizeRoll < 0.1) return {'radius': 16.0, 'growth': 3}; // Medium food
        return {'radius': 10.0, 'growth': 1}; // Small food
      }
    }
    // Tail area (last 25% of segments) - mostly small food with increased size
    else {
      if (sizeRoll < 0.05) return {'radius': 16.0, 'growth': 3}; // Medium food (rare)
      return {'radius': 10.0, 'growth': 1}; // Small food (common)
    }
  }

  // IMPROVED: Add extra scattered food with better distribution
  void _addExtraScatteredFoodImproved(Vector2 centerPos, double radius, int extraCount) {
    for (int i = 0; i < extraCount; i++) {
      // Create rings of food at different distances
      final ringIndex = i % 3; // 3 rings
      final ringRadius = radius * (1.5 + ringIndex * 0.5); // Rings at 1.5x, 2.0x, 2.5x radius

      final angle = _random.nextDouble() * 2 * pi;
      final distance = ringRadius + (_random.nextDouble() - 0.5) * radius * 0.3; // Add some randomness

      final position = Vector2(
        centerPos.x + cos(angle) * distance,
        centerPos.y + sin(angle) * distance,
      );

      // Clamp to world bounds
      position.x = position.x.clamp(worldBounds.left + 20.0, worldBounds.right - 20.0);
      position.y = position.y.clamp(worldBounds.top + 20.0, worldBounds.bottom - 20.0);

      final color = _foodColors[_random.nextInt(_foodColors.length)];

      // Extra food is mostly small with occasional medium (with increased sizes)
      final isLarger = _random.nextDouble() < 0.15; // Reduced chance
      final foodRadius = isLarger ? 16.0 : 10.0;  // Increased sizes
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

      foodPosition.x = foodPosition.x.clamp(worldBounds.left + 20.0, worldBounds.right - 20.0);
      foodPosition.y = foodPosition.y.clamp(worldBounds.top + 20.0, worldBounds.bottom - 20.0);

      double radius;
      int growth;
      final sizeRoll = _random.nextDouble();

      // Increased sizes for player death food
      if (snakeHeadRadius > 25) {
        if (sizeRoll < 0.3) { radius = 22.0; growth = 5; }  // Increased
        else if (sizeRoll < 0.6) { radius = 16.0; growth = 3; }  // Increased
        else { radius = 10.0; growth = 1; }  // Increased
      } else if (snakeHeadRadius > 18) {
        if (sizeRoll < 0.2) { radius = 22.0; growth = 5; }  // Increased
        else if (sizeRoll < 0.5) { radius = 16.0; growth = 3; }  // Increased
        else { radius = 10.0; growth = 1; }  // Increased
      } else {
        if (sizeRoll < 0.1) { radius = 16.0; growth = 3; }  // Increased
        else { radius = 10.0; growth = 1; }  // Increased
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

  // Legacy method - keeping for backward compatibility
  void scatterFoodFromAiSnake(Vector2 snakeHeadPosition, double snakeHeadRadius,
      int segmentCount, List<Vector2> bodySegments) {
    // Redirect to improved method
    scatterFoodFromAiSnakeSlitherStyle(snakeHeadPosition, snakeHeadRadius, segmentCount, bodySegments);
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