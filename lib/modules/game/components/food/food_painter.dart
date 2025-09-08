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
    // Base floating animation with enhanced motion
    final floatIntensity = food.isSpawning ? 0.05 : 0.20;
    final floatScale = (1.0 - floatIntensity) + floatIntensity *
        (0.5 + 0.5 * math.sin(_animT * 3.5 + food.originalPosition.x * 0.01));

    // Apply all scaling factors
    final totalScale = floatScale * food.scale;
    final radius = food.radius * totalScale;

    if (radius <= 0) return; // Don't render if scale is 0

    // ENHANCED: Multi-layer gradient for better depth
    _renderFoodWithEnhancedGradient(canvas, food, radius);

    // Add special effects based on state
    switch (food.state) {
      case FoodState.spawning:
        _renderSpawnEffect(canvas, food, radius);
        break;
      case FoodState.consuming:
        _renderConsumptionEffect(canvas, food, radius);
        break;
      case FoodState.normal:
      // Add subtle pulse glow for larger food items
        if (food.radius > 15.0) {
          _renderPulseGlow(canvas, food, radius);
        }
        break;
      case FoodState.consumed:
      // No special effects needed
        break;
    }

    // Add sparkle effect for larger food items during consumption
    if (food.state == FoodState.consuming && food.radius > 12.0) {
      _renderSparkleEffect(canvas, food, radius);
    }

    // Add pulsing glow for spawning large food
    if (food.state == FoodState.spawning && food.radius > 12.0) {
      _renderSpawnGlow(canvas, food, radius);
    }
  }

  void _renderFoodWithEnhancedGradient(Canvas canvas, FoodModel food, double radius) {
    // LAYER 1: Outer glow for better visibility
    final glowRadius = radius * 1.4;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          food.color.withOpacity(0.0),
          food.color.withOpacity(0.15 * food.opacity),
          food.color.withOpacity(0.25 * food.opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: glowRadius));
    canvas.drawCircle(food.position.toOffset(), glowRadius, glowPaint);

    // LAYER 2: Main food body with enhanced gradient
    final baseColor = food.color.withOpacity(food.opacity);
    final mainPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3), // Offset center for 3D effect
        colors: [
          _lighten(baseColor, 0.3),  // Bright highlight
          baseColor,                  // Main color
          _darken(baseColor, 0.2),   // Shadow
          _darken(baseColor, 0.4),   // Deep shadow at edge
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: radius));
    canvas.drawCircle(food.position.toOffset(), radius, mainPaint);

    // LAYER 3: Inner highlight for glossy effect
    final highlightRadius = radius * 0.6;
    final highlightOffset = Offset(
      food.position.x - radius * 0.2,
      food.position.y - radius * 0.2,
    );
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.4 * food.opacity),
          Colors.white.withOpacity(0.15 * food.opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: highlightOffset, radius: highlightRadius));
    canvas.drawCircle(highlightOffset, highlightRadius, highlightPaint);

    // LAYER 4: Edge rim light for better definition
    final rimPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          _lighten(baseColor, 0.2).withOpacity(0.3 * food.opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.75, 0.9, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: radius));
    canvas.drawCircle(food.position.toOffset(), radius, rimPaint);
  }

  // Helper function to lighten a color
  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  // Helper function to darken a color
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  void _renderPulseGlow(Canvas canvas, FoodModel food, double radius) {
    // Subtle pulse for large food items
    final pulseProgress = (math.sin(_animT * 2.5) + 1) * 0.5;
    final pulseRadius = radius * (1.2 + pulseProgress * 0.1);
    final pulseOpacity = 0.1 * pulseProgress * food.opacity;

    final pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          food.color.withOpacity(pulseOpacity),
          Colors.transparent,
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: pulseRadius));

    canvas.drawCircle(food.position.toOffset(), pulseRadius, pulsePaint);
  }

  void _renderSpawnEffect(Canvas canvas, FoodModel food, double radius) {
    // Enhanced expanding ring effect during spawn
    final spawnProgress = food.spawnProgress;

    if (spawnProgress < 0.8) {
      final ringRadius = radius + (spawnProgress * 20.0);
      final ringOpacity = (0.8 - spawnProgress) * 0.4;

      // Double ring for better effect
      final ringPaint = Paint()
        ..color = food.color.withOpacity(ringOpacity * food.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(food.position.toOffset(), ringRadius, ringPaint);

      // Inner ring
      final innerRingPaint = Paint()
        ..color = Colors.white.withOpacity(ringOpacity * 0.5 * food.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(food.position.toOffset(), ringRadius * 0.7, innerRingPaint);
    }
  }

  void _renderConsumptionEffect(Canvas canvas, FoodModel food, double radius) {
    // Enhanced consumption effect with multiple layers
    final glowProgress = math.sin(food.consumeProgress * math.pi);

    // Outer glow
    final outerGlowRadius = radius + (glowProgress * 12.0);
    final outerGlowPaint = Paint()
      ..color = food.color.withOpacity(0.2 * glowProgress * food.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(food.position.toOffset(), outerGlowRadius, outerGlowPaint);

    // Inner glow
    final innerGlowRadius = radius + (glowProgress * 6.0);
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          food.color.withOpacity(0.8 * glowProgress * food.opacity),
          food.color.withOpacity(0.3 * glowProgress * food.opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: innerGlowRadius));

    canvas.drawCircle(food.position.toOffset(), innerGlowRadius, innerGlowPaint);
  }

  void _renderSparkleEffect(Canvas canvas, FoodModel food, double radius) {
    // Enhanced sparkle particles
    final sparkleCount = 8;
    final sparkleProgress = food.consumeProgress;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i / sparkleCount) * 2 * math.pi + (_animT * 2);
      final distance = radius * 2.0 * (1 - sparkleProgress);

      final sparkleX = food.position.x + math.cos(angle) * distance;
      final sparkleY = food.position.y + math.sin(angle) * distance;
      final sparklePos = Offset(sparkleX, sparkleY);

      final sparkleSize = 3.0 * (1 - sparkleProgress) * food.opacity;

      // Main sparkle
      final sparklePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(Rect.fromCircle(center: sparklePos, radius: sparkleSize));

      canvas.drawCircle(sparklePos, sparkleSize, sparklePaint);
    }
  }

  void _renderSpawnGlow(Canvas canvas, FoodModel food, double radius) {
    // Enhanced pulsing glow for spawning large food items
    final pulseProgress = (math.sin(_animT * 6.0) + 1) * 0.5;
    final glowRadius = radius * (1.2 + pulseProgress * 0.4);
    final glowOpacity = 0.3 * (1 - food.spawnProgress) * pulseProgress;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          food.color.withOpacity(glowOpacity * 0.5),
          food.color.withOpacity(glowOpacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: glowRadius));

    canvas.drawCircle(food.position.toOffset(), glowRadius, glowPaint);
  }
}