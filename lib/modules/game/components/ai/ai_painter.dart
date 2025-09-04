import 'dart:math' as math;

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
      if (!drawRect.overlaps(snake.boundingBox)) continue;

      drawn++;

      // Apply death animation scaling and opacity
      final currentScale = snake.scale;
      final currentOpacity = snake.opacity;

      // Skip rendering if completely invisible
      if (currentOpacity <= 0.0 || currentScale <= 0.0) continue;

      // Paint cycling by segment index
      for (int i = 0; i < snake.segmentCount; i++) {
        Offset segPos;
        double radius;

        if (i == 0) {
          // Always draw head from snake.position
          segPos = snake.position.toOffset();
          radius = snake.headRadius * currentScale; // Apply death animation scale
          headPaint.color = snake.skinColors[0].withOpacity(currentOpacity);
        } else if (i - 1 < snake.bodySegments.length) {
          segPos = snake.bodySegments[i - 1].toOffset();
          radius = snake.bodyRadius * currentScale; // Apply death animation scale
          headPaint.color = snake.skinColors[i % snake.skinColors.length].withOpacity(currentOpacity);
        } else {
          continue; // Skip if segment doesn't exist
        }

        // Don't draw segments that are too small
        if (radius > 0.5) {
          canvas.drawCircle(segPos, radius, headPaint);
        }
      }

      // Add death effect for dying snakes
      if (snake.isDead && snake.deathAnimationTimer > 0) {
        _renderDeathEffect(canvas, snake);
      }
    }

    if (drawn > 0) {
      debugPrint("Rendering snakes: $drawn");
    }
  }

  void _renderDeathEffect(Canvas canvas, AiSnakeData snake) {
    // Create a fading ring effect around the dying snake
    final progress = 1.0 - (snake.deathAnimationTimer / AiSnakeData.deathAnimationDuration);
    final ringRadius = snake.headRadius * (1.0 + progress * 2.0);
    final ringOpacity = (1.0 - progress) * 0.3 * snake.opacity;

    if (ringOpacity > 0.01) {
      final ringPaint = Paint()
        ..color = Colors.white.withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(snake.position.toOffset(), ringRadius, ringPaint);
    }

    // Add some particle-like effects
    _renderDeathParticles(canvas, snake, progress);
  }

  void _renderDeathParticles(Canvas canvas, AiSnakeData snake, double progress) {
    final particleCount = 8;
    final maxParticleDistance = snake.headRadius * 3;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final distance = progress * maxParticleDistance;

      final particleX = snake.position.x + (distance * math.cos(angle));
      final particleY = snake.position.y + (distance * math.sin(angle));
      final particlePos = Offset(particleX, particleY);

      final particleSize = (1.0 - progress) * 3.0;
      final particleOpacity = (1.0 - progress) * snake.opacity;

      if (particleSize > 0.5 && particleOpacity > 0.01) {
        final particlePaint = Paint()
          ..color = snake.skinColors[0].withOpacity(particleOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(particlePos, particleSize, particlePaint);
      }
    }
  }
}