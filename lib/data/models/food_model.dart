// lib/app/modules/game/components/food/food_data.dart

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

// This is NOT a component. It's just a simple class to hold data.
class FoodData {
  final Vector2 position;
  final Color color;
  final double radius;
  final int growth;

  FoodData({
    required this.position,
    required this.color,
    required this.radius,
    required this.growth,
  });
}