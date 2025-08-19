// lib/app/modules/game/components/food/food_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';
import '../../views/game_screen.dart';

class FoodManager {
  final Random _random = Random();
  final int foodCount = 20000;
  final List<FoodModel> foodList = [];

  final List<Color> _foodColors = [
    Colors.redAccent, Colors.greenAccent, Colors.blueAccent,
    Colors.purpleAccent, Colors.orangeAccent, Colors.cyanAccent, Colors.pinkAccent,
  ];

  FoodManager() {
    for (int i = 0; i < foodCount; i++) {
      spawnFood();
    }
  }

  @override
  void update(double dt) {
  }

  void spawnFood() {
    final worldBounds = SlitherGame.worldBounds;
    final position = Vector2(
      _random.nextDouble() * worldBounds.width + worldBounds.left,
      _random.nextDouble() * worldBounds.height + worldBounds.top,
    );

    final color = _foodColors[_random.nextInt(_foodColors.length)];

    // --- THIS IS THE FIX ---
    // We now have the correct random chances for small, medium, or large pallets.
    final double rand = _random.nextDouble();
    double radius;
    int growth;

    if (rand < 0.70) { // 70% chance for a small pallet
      radius = 6.0;
      growth = 1;
    } else if (rand < 0.90) { // 20% chance for a medium pallet (70% + 20% = 90%)
      radius = 10.0;
      growth = 3;
    } else { // 10% chance for a large pallet
      radius = 14.0;
      growth = 5;
    }
    // --- END OF FIX ---

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