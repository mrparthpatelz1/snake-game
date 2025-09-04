// lib/modules/game/components/food/food_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';

class FoodManager {
  final Random _random = Random();
  static const int TARGET_FOOD_COUNT = 200; // Maintain exactly this many food items
  final List<FoodModel> foodList = [];
  final double spawnRadius;
  final double maxDistance;
  final Rect worldBounds;

  // Performance counters
  int _updateCounter = 0;
  int _maintenanceCounter = 0;

  // Food spawning animation queue for dead snakes
  final List<_FoodSpawnAnimation> _spawnAnimations = [];

  final List<Color> _foodColors = [
    Colors.redAccent, Colors.greenAccent, Colors.blueAccent,
    Colors.purpleAccent, Colors.orangeAccent, Colors.cyanAccent, Colors.pinkAccent,
  ];

  FoodManager({
    required this.worldBounds,
    required this.spawnRadius,
    required this.maxDistance
  }) {
    // Initialize with target food count
    _initializeFood();
  }

  // Initialize the world with food
  void _initializeFood() {
    print('Initializing ${TARGET_FOOD_COUNT} food items...');

    for (int i = 0; i < TARGET_FOOD_COUNT; i++) {
      _createRandomFood();
    }

    print('Food initialization complete: ${foodList.length} items created');
  }

  void update(double dt, Vector2 playerPosition) {
    _updateCounter++;
    _maintenanceCounter++;

    // Update food animations
    _updateFoodAnimations(dt);

    // Update spawn animations
    _updateSpawnAnimations(dt);

    // Periodic maintenance (every 2 seconds)
    if (_maintenanceCounter >= 120) {
      _maintenanceCounter = 0;
      _performMaintenance(playerPosition);
    }
  }

  void _updateFoodAnimations(double dt) {
    for (final food in foodList) {
      food.updateConsumption(dt);
    }
  }

  void _updateSpawnAnimations(double dt) {
    _spawnAnimations.removeWhere((animation) {
      animation.update(dt);
      if (animation.isComplete) {
        // Spawn the actual food when animation completes
        _spawnFoodAtPosition(animation.position);
        return true;
      }
      return false;
    });
  }

  // Periodic maintenance to ensure proper food count
  void _performMaintenance(Vector2 playerPosition) {
    final initialCount = foodList.length;

    // Remove consumed food and food too far from player
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

    // Calculate how much food we need to reach target
    final currentCount = foodList.length;
    final needed = TARGET_FOOD_COUNT - currentCount;

    // Spawn new food to maintain target count
    int spawnedCount = 0;
    for (int i = 0; i < needed; i++) {
      _spawnFoodNear(playerPosition);
      spawnedCount++;
    }

    if (removedCount > 0 || spawnedCount > 0) {
      print('Food maintenance: Removed: $removedCount, Spawned: $spawnedCount, Total: ${foodList.length}');
    }
  }

  // Create random food anywhere in the world (for initialization)
  void _createRandomFood() {
    final x = worldBounds.left + _random.nextDouble() * worldBounds.width;
    final y = worldBounds.top + _random.nextDouble() * worldBounds.height;
    final position = Vector2(x, y);
    _createFoodAt(position);
  }

  // Spawn food near player (for maintenance)
  void _spawnFoodNear(Vector2 playerPosition) {
    final angle = _random.nextDouble() * pi * 2;
    final distance = _random.nextDouble() * spawnRadius;
    final x = playerPosition.x + cos(angle) * distance;
    final y = playerPosition.y + sin(angle) * distance;

    final clampedX = x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
    final clampedY = y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);
    final position = Vector2(clampedX, clampedY);

    _createFoodAt(position);
  }

  // Create food at specific position
  void _createFoodAt(Vector2 position) {
    final color = _foodColors[_random.nextInt(_foodColors.length)];
    final double rand = _random.nextDouble();
    double radius;
    int growth;

    if (rand < 0.70) { // 70% chance for small food
      radius = 6.0;
      growth = 1;
    } else if (rand < 0.90) { // 20% chance for medium food
      radius = 10.0;
      growth = 3;
    } else { // 10% chance for large food
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

  // CHANGED: No longer spawn new food when eaten
  void startConsumingFood(FoodModel food, Vector2 snakeHeadPosition) {
    food.startConsumption(snakeHeadPosition);
    // Do NOT spawn new food here - let maintenance handle it
  }

  // NEW: Scatter food from dead snake with animation (like Slither.io)
  void scatterFoodFromDeadSnake(List<Vector2> snakeSegments, Vector2 headPosition, {int maxFood = 70}) {
    print('Scattering food from dead snake: ${snakeSegments.length} segments');

    // Add head position as first food
    _addFoodScatterAnimation(headPosition, isHead: true);

    // Scatter food from body segments (every 2nd segment to avoid too much food)
    int scattered = 1; // Count the head
    for (int i = 0; i < snakeSegments.length && scattered < maxFood; i += 2) {
      _addFoodScatterAnimation(snakeSegments[i]);
      scattered++;
    }

    print('Added $scattered food scatter animations');
  }

  void _addFoodScatterAnimation(Vector2 position, {bool isHead = false}) {
    // Add some randomness to scatter position
    final scatterRadius = isHead ? 30.0 : 20.0;
    final angle = _random.nextDouble() * pi * 2;
    final distance = _random.nextDouble() * scatterRadius;

    final scatteredPos = Vector2(
      position.x + cos(angle) * distance,
      position.y + sin(angle) * distance,
    );

    // Clamp to world bounds
    scatteredPos.x = scatteredPos.x.clamp(worldBounds.left + 14.0, worldBounds.right - 14.0);
    scatteredPos.y = scatteredPos.y.clamp(worldBounds.top + 14.0, worldBounds.bottom - 14.0);

    _spawnAnimations.add(_FoodSpawnAnimation(
      position: scatteredPos,
      isFromHead: isHead,
    ));
  }

  void _spawnFoodAtPosition(Vector2 position) {
    final color = _foodColors[_random.nextInt(_foodColors.length)];
    // Dead snake food is always small for balance
    const radius = 6.0;
    const growth = 1;

    foodList.add(FoodModel(
      position: position,
      color: color,
      radius: radius,
      growth: growth,
    ));
  }

  // Get list of food that can be eaten (not being consumed)
  List<FoodModel> get eatableFoodList =>
      foodList.where((food) => food.canBeEaten).toList();

  // Legacy method for backward compatibility - REMOVED immediate spawning
  void removeFood(FoodModel food) {
    foodList.remove(food);
    // Do NOT spawn new food - let maintenance handle food count
  }

  // Get current food statistics
  Map<String, int> get foodStats => {
    'total': foodList.length,
    'normal': foodList.where((f) => f.state == FoodState.normal).length,
    'consuming': foodList.where((f) => f.state == FoodState.consuming).length,
    'consumed': foodList.where((f) => f.state == FoodState.consumed).length,
    'animations': _spawnAnimations.length,
  };
}

// Animation class for food spawning from dead snakes
class _FoodSpawnAnimation {
  final Vector2 position;
  final bool isFromHead;
  double _progress = 0.0;
  double _scale = 0.0;
  static const double ANIMATION_DURATION = 0.5;

  _FoodSpawnAnimation({
    required this.position,
    this.isFromHead = false,
  });

  void update(double dt) {
    _progress += dt / ANIMATION_DURATION;
    if (_progress > 1.0) _progress = 1.0;

    // Bouncy scale animation
    if (_progress < 0.7) {
      _scale = _progress / 0.7;
    } else {
      // Slight bounce effect
      final bounceProgress = (_progress - 0.7) / 0.3;
      _scale = 1.0 + sin(bounceProgress * pi) * 0.2;
    }
  }

  bool get isComplete => _progress >= 1.0;
  double get scale => _scale.clamp(0.0, 1.2);
}