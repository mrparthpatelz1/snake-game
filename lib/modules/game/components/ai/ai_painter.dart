// lib/app/modules/game/components/ai/ai_painter.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'ai_manager.dart';

class AiPainter extends PositionComponent with HasGameRef {
  final AiManager aiManager;
  final CameraComponent cameraToFollow;

  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  AiPainter({required this.aiManager, required this.cameraToFollow});

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final visibleRect = cameraToFollow.visibleWorldRect;

    for (final snake in aiManager.snakes) {
      // Only draw the snake if its bounding box overlaps with the visible area.
      if (visibleRect.overlaps(snake.boundingBox)) {
        // Render body
        for (int i = snake.bodySegments.length - 1; i >= 0; i--) {
          final segmentPosition = snake.bodySegments[i];
          final color = snake.skinColors[i % snake.skinColors.length];
          _drawSegment(canvas, segmentPosition, snake.bodyRadius, color);
        }
        // Render head
        final headColor = snake.skinColors.first;
        _drawSegment(canvas, snake.position, snake.headRadius, headColor);
        _drawEyes(canvas, snake.position, snake.angle, snake.headRadius);
      }
    }
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