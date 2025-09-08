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
    final segmentPaint = Paint();

    for (final snake in aiManager.snakes) {
      if (!drawRect.overlaps(snake.boundingBox)) continue;

      drawn++;

      // Apply death animation scaling and opacity
      final currentScale = snake.scale;
      final currentOpacity = snake.opacity;

      // Skip rendering if completely invisible
      if (currentOpacity <= 0.0 || currentScale <= 0.0) continue;

      // FIXED: Render body segments first (from tail to neck)
      for (int i = snake.segmentCount - 1; i >= 1; i--) {
        if (i - 1 < snake.bodySegments.length) {
          final segPos = snake.bodySegments[i - 1].toOffset();
          final radius = snake.bodyRadius * currentScale;

          // Don't draw segments that are too small
          if (radius > 0.5) {
            segmentPaint.color = snake.skinColors[i % snake.skinColors.length].withOpacity(currentOpacity);

            // Add boost glow effect for boosting snakes
            if (snake.isBoosting) {
              _renderBoostGlow(canvas, segPos, radius, snake.skinColors[i % snake.skinColors.length], currentOpacity);
            }

            canvas.drawCircle(segPos, radius, segmentPaint);
          }
        }
      }

      // FIXED: Render head LAST (on top of body segments)
      final headPos = snake.position.toOffset();
      final headRadius = snake.headRadius * currentScale;

      if (headRadius > 0.5) {
        // Add boost glow for head if boosting
        if (snake.isBoosting) {
          _renderHeadBoostGlow(canvas, headPos, headRadius, snake.skinColors[0], currentOpacity);
        }

        // Draw head sprite
        canvas.save();
        canvas.translate(headPos.dx, headPos.dy);
        canvas.rotate(snake.angle + -math.pi /2); // Adjust rotation as needed
        canvas.scale(currentScale); // Apply death animation scaling

        snake.headSprite.render(
          canvas,
          position: Vector2.zero(),
          size: Vector2.all(headRadius * 2),
          anchor: Anchor.center,
        );
        canvas.restore();
      }

      // Add death effect for dying snakes
      if (snake.isDead && snake.deathAnimationTimer > 0) {
        _renderDeathEffect(canvas, snake);
      }
    }

    if (drawn > 0 && game.debugMode) {
      debugPrint("Rendering AI snakes: $drawn");
    }
  }

  // NEW: Render boost glow effect for body segments
  void _renderBoostGlow(Canvas canvas, Offset position, double radius, Color color, double opacity) {
    final glowRadius = radius * 1.3;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.4 * opacity),
          color.withOpacity(0.1 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: glowRadius));

    canvas.drawCircle(position, glowRadius, glowPaint);
  }

  // NEW: Render boost glow effect for head
  void _renderHeadBoostGlow(Canvas canvas, Offset position, double radius, Color color, double opacity) {
    final glowRadius = radius * 1.5;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.3 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: glowRadius));

    canvas.drawCircle(position, glowRadius, glowPaint);
  }

  void _renderDeathEffect(Canvas canvas, AiSnakeData snake) {
    // Check if this is a revenge death (longer animation duration)
    final isRevengeDeath = snake.deathAnimationTimer > AiSnakeData.deathAnimationDuration;

    // Create a fading ring effect around the dying snake
    final progress = 1.0 - (snake.deathAnimationTimer /
        (isRevengeDeath ? AiSnakeData.deathAnimationDuration * 1.5 : AiSnakeData.deathAnimationDuration));
    final ringRadius = snake.headRadius * (1.0 + progress * (isRevengeDeath ? 3.0 : 2.0));
    final ringOpacity = (1.0 - progress) * (isRevengeDeath ? 0.5 : 0.3) * snake.opacity;

    if (ringOpacity > 0.01) {
      final ringPaint = Paint()
        ..color = (isRevengeDeath ? Colors.red : Colors.white).withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isRevengeDeath ? 5.0 : 3.0;

      canvas.drawCircle(snake.position.toOffset(), ringRadius, ringPaint);

      // Add extra rings for revenge death
      if (isRevengeDeath) {
        final innerRingPaint = Paint()
          ..color = Colors.orange.withOpacity(ringOpacity * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(snake.position.toOffset(), ringRadius * 0.7, innerRingPaint);
      }
    }

    // Add some particle-like effects
    _renderDeathParticles(canvas, snake, progress, isRevengeDeath);
  }

  void _renderDeathParticles(Canvas canvas, AiSnakeData snake, double progress, [bool isRevenge = false]) {
    final particleCount = isRevenge ? 16 : 8;  // More particles for revenge
    final maxParticleDistance = snake.headRadius * (isRevenge ? 4 : 3);

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final distance = progress * maxParticleDistance;

      final particleX = snake.position.x + (distance * math.cos(angle));
      final particleY = snake.position.y + (distance * math.sin(angle));
      final particlePos = Offset(particleX, particleY);

      final particleSize = (1.0 - progress) * (isRevenge ? 5.0 : 3.0);
      final particleOpacity = (1.0 - progress) * snake.opacity;

      if (particleSize > 0.5 && particleOpacity > 0.01) {
        final particlePaint = Paint()
          ..color = (isRevenge ? Colors.redAccent : snake.skinColors[0]).withOpacity(particleOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(particlePos, particleSize, particlePaint);
      }
    }
  }
}