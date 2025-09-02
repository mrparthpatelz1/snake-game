// lib/modules/game/components/food/food_painter.dart

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'food_manager.dart';
import '../../../../data/models/food_model.dart';

class FoodPainter extends PositionComponent {
  final FoodManager foodManager;
  final CameraComponent cameraToFollow;
  double _animT = 0.0;

  FoodPainter({required this.foodManager, required this.cameraToFollow});

  @override
  void update(double dt) {
    super.update(dt);
    _animT += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final visibleRect = cameraToFollow.visibleWorldRect;

    for (final food in foodManager.foodList) {
      if (visibleRect.contains(food.position.toOffset())) {
        _renderFood(canvas, food);
      }
    }
  }

  void _renderFood(Canvas canvas, FoodModel food) {
    // Base floating animation
    final floatScale = 0.85 + 0.15 * (0.5 + 0.5 * math.sin(_animT * 4.0 + food.originalPosition.x * 0.01));

    // Apply consumption scaling and opacity
    final totalScale = floatScale * food.scale;
    final radius = food.radius * totalScale;

    // Create paint with animated opacity
    final baseColor = food.color.withOpacity(food.opacity);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor,
          baseColor.withOpacity(food.opacity * 0.7), // Slightly more transparent at edges
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: radius));

    // Add consumption effect - glowing when being consumed
    if (food.state == FoodState.consuming) {
      _renderConsumptionEffect(canvas, food, radius);
    }

    // Draw the main food
    canvas.drawCircle(food.position.toOffset(), radius, paint);

    // Add sparkle effect for larger food items during consumption
    if (food.state == FoodState.consuming && food.radius > 8.0) {
      _renderSparkleEffect(canvas, food, radius);
    }
  }

  void _renderConsumptionEffect(Canvas canvas, FoodModel food, double radius) {
    // Create a glowing outline effect
    final glowProgress = math.sin(food.consumeProgress * math.pi);
    final glowRadius = radius + (glowProgress * 8.0);

    final glowPaint = Paint()
      ..color = food.color.withOpacity(0.3 * glowProgress * food.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(food.position.toOffset(), glowRadius, glowPaint);

    // Add inner glow
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          food.color.withOpacity(0.6 * glowProgress * food.opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: radius * 1.5));

    canvas.drawCircle(food.position.toOffset(), radius * 1.5, innerGlowPaint);
  }

  void _renderSparkleEffect(Canvas canvas, FoodModel food, double radius) {
    // Create small sparkle particles around the food
    final sparkleCount = 6;
    final sparkleProgress = food.consumeProgress;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i / sparkleCount) * 2 * math.pi + (_animT * 2);
      final distance = radius * 1.5 * (1 - sparkleProgress);

      final sparkleX = food.position.x + math.cos(angle) * distance;
      final sparkleY = food.position.y + math.sin(angle) * distance;
      final sparklePos = Offset(sparkleX, sparkleY);

      final sparkleSize = 2.0 * (1 - sparkleProgress) * food.opacity;

      final sparklePaint = Paint()
        ..color = Colors.white.withOpacity(0.8 * food.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(sparklePos, sparkleSize, sparklePaint);
    }
  }
}