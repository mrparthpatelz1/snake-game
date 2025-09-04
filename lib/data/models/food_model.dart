// lib/data/models/food_model.dart

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum FoodState {
  spawning,   // NEW: Just spawned - growing from 0 to full size
  normal,     // Normal state, can be eaten
  consuming,  // Being consumed - animating towards snake
  consumed    // Fully consumed - ready for removal
}

class FoodModel {
  final Vector2 originalPosition;
  Vector2 position;
  final Color color;
  final double radius;
  final int growth;

  // Animation properties
  FoodState state = FoodState.spawning; // Start in spawning state
  Vector2? targetPosition; // Position to animate towards (snake head)
  double consumeProgress = 0.0; // 0.0 = start, 1.0 = fully consumed
  double scale = 0.0; // Start at 0 for spawn animation
  double opacity = 1.0; // For fade out effect
  double spawnProgress = 0.0; // 0.0 = just spawned, 1.0 = fully spawned

  // Animation timing
  static const double consumeAnimationDuration = 0.4; // seconds
  static const double spawnAnimationDuration = 0.3; // seconds for spawn animation

  FoodModel({
    required Vector2 position,
    required this.color,
    required this.radius,
    required this.growth,
    bool skipSpawnAnimation = false, // Allow skipping spawn animation
  }) : originalPosition = position.clone(),
        position = position.clone() {
    if (skipSpawnAnimation) {
      state = FoodState.normal;
      scale = 1.0;
      spawnProgress = 1.0;
    }
  }

  // Start the consumption animation towards a target position (snake head)
  void startConsumption(Vector2 target) {
    if (state != FoodState.normal) return;

    state = FoodState.consuming;
    targetPosition = target.clone();
    consumeProgress = 0.0;
  }

  // Update all animations
  void updateAnimations(double dt) {
    switch (state) {
      case FoodState.spawning:
        _updateSpawnAnimation(dt);
        break;
      case FoodState.consuming:
        _updateConsumption(dt);
        break;
      case FoodState.normal:
      case FoodState.consumed:
      // No animation needed
        break;
    }
  }

  // Update spawn animation
  void _updateSpawnAnimation(double dt) {
    spawnProgress += dt / spawnAnimationDuration;

    if (spawnProgress >= 1.0) {
      spawnProgress = 1.0;
      state = FoodState.normal;
      scale = 1.0;
      return;
    }

    // Smooth bounce-in effect
    double easedProgress = _easeOutBack(spawnProgress);
    scale = easedProgress;
  }

  // Update the consumption animation
  void _updateConsumption(double dt) {
    if (targetPosition == null) return;

    // Increase progress
    consumeProgress += dt / consumeAnimationDuration;

    if (consumeProgress >= 1.0) {
      consumeProgress = 1.0;
      state = FoodState.consumed;
      return;
    }

    // Smooth easing curve (ease-in-out)
    double easedProgress = _easeInOutCubic(consumeProgress);

    // Animate position towards target (manual lerp implementation)
    position = _lerpVector2(originalPosition, targetPosition!, easedProgress);

    // Animate scale (shrink as it gets consumed)
    scale = 1.0 - (easedProgress * 0.6); // Shrink to 40% of original size

    // Animate opacity (fade out near the end)
    if (easedProgress > 0.7) {
      double fadeProgress = (easedProgress - 0.7) / 0.3;
      opacity = 1.0 - fadeProgress;
    }
  }

  // Helper method to lerp between two Vector2 points
  Vector2 _lerpVector2(Vector2 start, Vector2 end, double t) {
    return Vector2(
      start.x + (end.x - start.x) * t,
      start.y + (end.y - start.y) * t,
    );
  }

  // Smooth easing function for consumption
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }

  // Bounce-in easing for spawn animation
  double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
  }

  // Check if the food is ready to be removed
  bool get shouldBeRemoved => state == FoodState.consumed;

  // Check if the food can be eaten (fully spawned and not being consumed)
  bool get canBeEaten => state == FoodState.normal;

  // Check if the food is currently spawning
  bool get isSpawning => state == FoodState.spawning;

  // Reset the food to normal state (if needed)
  void reset() {
    state = FoodState.normal;
    position = originalPosition.clone();
    targetPosition = null;
    consumeProgress = 0.0;
    spawnProgress = 1.0;
    scale = 1.0;
    opacity = 1.0;
  }
}

// Helper function for pow calculation
double pow(double base, double exponent) {
  if (exponent == 0) return 1.0;
  if (exponent == 1) return base;
  if (exponent == 2) return base * base;
  if (exponent == 3) return base * base * base;

  // For other cases, use a simple approximation
  double result = 1.0;
  int exp = exponent.abs().round();
  for (int i = 0; i < exp; i++) {
    result *= base;
  }
  return exponent < 0 ? 1.0 / result : result;
}