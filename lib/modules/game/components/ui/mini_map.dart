// lib/app/modules/game/components/ui/minimap.dart

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../views/game_screen.dart';
import '../ai/ai_manager.dart';
import '../player/player_component.dart';

class Minimap extends PositionComponent with HasGameRef {
  final PlayerComponent player;
  final AiManager aiManager;

  Minimap({required this.player, required this.aiManager});

  // --- Paints for drawing ---
  final Paint _backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);
  final Paint _playerPaint = Paint()..color = Colors.blue;
  final Paint _aiPaint = Paint()..color = Colors.red;
  final Paint _borderPaint = Paint()
    ..color = Colors.white.withOpacity(0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Set the size and position of the minimap on the screen.
    size = Vector2.all(200);
    position = Vector2(game.size.x - size.x - 20, 20); // Top right corner
    priority = 100; // Ensure it's drawn on top
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw the background and border.
    canvas.drawRect(size.toRect(), _backgroundPaint);
    canvas.drawRect(size.toRect(), _borderPaint);

    final worldBounds = SlitherGame.worldBounds;
    // Calculate the scaling factor to fit the world onto the minimap.
    final scaleX = size.x / worldBounds.width;
    final scaleY = size.y / worldBounds.height;

    // --- Helper function to convert world coordinates to minimap coordinates ---
    Offset toMinimapPosition(Vector2 worldPosition) {
      final mapX = (worldPosition.x - worldBounds.left) * scaleX;
      final mapY = (worldPosition.y - worldBounds.top) * scaleY;
      return Offset(mapX, mapY);
    }

    // --- Draw AI Snakes ---
    for (final snake in aiManager.snakes) {
      canvas.drawCircle(toMinimapPosition(snake.position), 2, _aiPaint);
    }

    // --- Draw Player ---
    // The player is drawn last to appear on top.
    canvas.drawCircle(toMinimapPosition(player.position), 3, _playerPaint);
  }
}
