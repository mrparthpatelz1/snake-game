// lib/modules/game/components/ai/ai_painter.dart

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../../views/game_screen.dart';
import 'ai_snake_data.dart';
import 'ai_manager.dart';

class AiPainter extends Component with HasGameReference<SlitherGame> {
  final AiManager aiManager;

  AiPainter({required this.aiManager});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final view = game.cameraComponent.visibleWorldRect;
    final margin = 200.0;
    final drawRect = view.inflate(margin);

    int drawn = 0;
    final segmentPaint = Paint();

    for (final snake in aiManager.snakes) {
      if (snake.isDead) continue;
      if (!drawRect.overlaps(snake.boundingBox)) continue;

      drawn++;

      // FIXED: Render body segments FIRST (so they appear under the head)
      for (int i = 1; i < snake.segmentCount; i++) { // Start from 1 to skip head
        if (i - 1 < snake.bodySegments.length) {
          final segPos = snake.bodySegments[i - 1].toOffset();
          segmentPaint.color = snake.skinColors[i % snake.skinColors.length];

          // Add gradient effect to body segments
          final gradient = RadialGradient(
            colors: [
              segmentPaint.color,
              segmentPaint.color.withOpacity(0.8),
            ],
            stops: const [0.6, 1.0],
          );

          segmentPaint.shader = gradient.createShader(
              Rect.fromCircle(center: segPos, radius: snake.bodyRadius)
          );

          canvas.drawCircle(segPos, snake.bodyRadius, segmentPaint);
        }
      }

      // FIXED: Render head LAST (so it appears on top of body)
      final headPos = snake.position.toOffset();
      segmentPaint.color = snake.skinColors[0]; // Head uses first color

      // Special gradient for head to make it more prominent
      final headGradient = RadialGradient(
        colors: [
          segmentPaint.color.withOpacity(1.0),
          segmentPaint.color.withOpacity(0.7),
        ],
        stops: const [0.5, 1.0],
      );

      segmentPaint.shader = headGradient.createShader(
          Rect.fromCircle(center: headPos, radius: snake.headRadius)
      );

      canvas.drawCircle(headPos, snake.headRadius, segmentPaint);

      // Optional: Add a small highlight to the head for better visibility
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
          Offset(headPos.dx - snake.headRadius * 0.3, headPos.dy - snake.headRadius * 0.3),
          snake.headRadius * 0.2,
          highlightPaint
      );
    }

    if (drawn > 0) {
      debugPrint("Rendering AI snakes: $drawn (head over body)");
    }
  }
}