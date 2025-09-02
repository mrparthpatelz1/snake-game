import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'food_manager.dart';

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
        final floatScale =
            0.85 + 0.15 * (0.5 + 0.5 * math.sin(_animT * 4.0 + food.position.x * 0.01));
        final r = food.radius * floatScale;
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [food.color, food.color.withOpacity(1.0)],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: food.position.toOffset(), radius: r));
        canvas.drawCircle(food.position.toOffset(), r, paint);
      }
    }
  }
}
