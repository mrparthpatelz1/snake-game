import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'ai_manager.dart';

class AiPainter extends PositionComponent with HasGameReference {
  final AiManager aiManager;
  final CameraComponent cameraToFollow;

  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  AiPainter({required this.aiManager, required this.cameraToFollow});

  void renderWithAlpha(Canvas canvas, double alpha) {
    super.render(canvas);
    final visibleRect = cameraToFollow.visibleWorldRect;

    for (final snake in aiManager.snakes) {
      if (!visibleRect.overlaps(snake.boundingBox)) continue;

      snake.interpolatePosition(alpha);

      // Body
      for (int i = snake.bodySegments.length - 1; i >= 0; i--) {
        final segPos = snake.bodySegments[i];
        final color = snake.skinColors[i % snake.skinColors.length];
        _drawSegment(canvas, segPos, snake.bodyRadius, color);
      }
      // Head
      final headColor = snake.skinColors.first;
      _drawSegment(canvas, snake.position, snake.headRadius, headColor);
      _drawEyes(canvas, snake.position, snake.angle, snake.headRadius);
    }
    render(canvas);
  }
  @override
  void render(Canvas canvas) {
    // Optionally call renderWithAlpha with alpha = 1.0 (fully updated) for default behavior
    renderWithAlpha(canvas, 1.0);
  }

  void _drawSegment(Canvas canvas, Vector2 position, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0.5)],
      ).createShader(Rect.fromCircle(center: position.toOffset(), radius: radius));
    canvas.drawCircle(position.toOffset(), radius, paint);
  }

  void _drawEyes(Canvas canvas, Vector2 headPosition, double headAngle, double headRadius) {
    final eyeRadius = headRadius * 0.25;
    final pupilRadius = eyeRadius * 0.5;
    final eyeDistance = headRadius * 0.6;

    final rightEyePos = headPosition + Vector2(cos(headAngle + pi / 4) * eyeDistance, sin(headAngle + pi / 4) * eyeDistance);
    canvas.drawCircle(rightEyePos.toOffset(), eyeRadius, _eyePaint);
    canvas.drawCircle(rightEyePos.toOffset(), pupilRadius, _pupilPaint);

    final leftEyePos = headPosition + Vector2(cos(headAngle - pi / 4) * eyeDistance, sin(headAngle - pi / 4) * eyeDistance);
    canvas.drawCircle(leftEyePos.toOffset(), eyeRadius, _eyePaint);
    canvas.drawCircle(leftEyePos.toOffset(), pupilRadius, _pupilPaint);
  }
}
