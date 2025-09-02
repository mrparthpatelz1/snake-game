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
    final margin = 300.0;
    final drawRect = view.inflate(margin);

    int drawn = 0;
    final headPaint = Paint();

    for (final snake in aiManager.snakes) {
      if (snake.isDead) continue;
      if (!drawRect.overlaps(snake.boundingBox)) continue;

      drawn++;

      // Paint cycling by segment index
      for (int i = 0; i < snake.segmentCount; i++) {
        Offset segPos;

        if (i == 0) {
          // Always draw head from snake.position
          segPos = snake.position.toOffset();
          headPaint.color = snake.skinColors[0];
          canvas.drawCircle(segPos, snake.headRadius, headPaint);
        } else if (i - 1 < snake.bodySegments.length) {
          segPos = snake.bodySegments[i - 1].toOffset();
          headPaint.color = snake.skinColors[i % snake.skinColors.length];
          canvas.drawCircle(segPos, snake.bodyRadius, headPaint);
        }
      }
    }

    debugPrint("Rendering snakes: $drawn");
  }
}
