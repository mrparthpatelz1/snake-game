// // lib/app/modules/game/components/world/tile_background.dart
//
// import 'package:flame/components.dart';
// import 'package:flutter/material.dart'; // Required for Canvas
// import '../../views/game_screen.dart'; // To get the world bounds
//
// class TileBackground extends PositionComponent with HasGameRef {
//   late final Sprite _sprite;
//   // The size of a single tile. You can adjust this.
//   static const double tileSize = 512.0;
//
//   @override
//   Future<void> onLoad() async {
//     super.onLoad();
//     _sprite = await game.loadSprite('background_tile.png');
//     priority = -10;
//   }
//
//   @override
//   void render(Canvas canvas) {
//     super.render(canvas);
//     // --- THIS IS THE DEFINITIVE FIX ---
//     // This logic now correctly covers the entire world with tiles.
//
//     final bounds = SlitherGame.worldBounds;
//     final spriteSize = Vector2.all(tileSize);
//
//     // Calculate the start and end columns and rows based on the entire world size.
//     final startCol = (bounds.left / spriteSize.x).floor();
//     final endCol = (bounds.right / spriteSize.x).ceil();
//     final startRow = (bounds.top / spriteSize.y).floor();
//     final endRow = (bounds.bottom / spriteSize.y).ceil();
//
//     // Loop through and draw a tile for every position in the world.
//     for (int row = startRow; row < endRow; row++) {
//       for (int col = startCol; col < endCol; col++) {
//         final position = Vector2(col * spriteSize.x, row * spriteSize.y);
//         _sprite.render(canvas, position: position, size: spriteSize);
//       }
//     }
//   }
// }

// lib/app/modules/game/components/world/tile_background.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../views/game_screen.dart';

class TileBackground extends PositionComponent with HasGameRef {
  final CameraComponent cameraToFollow;

  TileBackground({required this.cameraToFollow});

  Sprite? _sprite;
  static const double tileSize = 512.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      _sprite = await game.loadSprite('background_tile.png');
    } catch (e) {
      // If the sprite fails to load, create a simple colored rectangle
      print('Failed to load background_tile.png: $e');
      // We'll handle this in the render method
    }
    priority = -10;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final visibleRect = cameraToFollow.visibleWorldRect;
    final spriteSize = Vector2.all(tileSize);
    final worldBounds = SlitherGame.worldBounds;

    final intersectionRect = visibleRect.intersect(worldBounds);

    if (intersectionRect.width <= 0 || intersectionRect.height <= 0) {
      return;
    }

    final startCol = (intersectionRect.left / spriteSize.x).floor();
    final endCol = (intersectionRect.right / spriteSize.x).ceil();
    final startRow = (intersectionRect.top / spriteSize.y).floor();
    final endRow = (intersectionRect.bottom / spriteSize.y).ceil();

    for (int row = startRow; row < endRow; row++) {
      for (int col = startCol; col < endCol; col++) {
        final position = Vector2(col * spriteSize.x, row * spriteSize.y);
        
        if (_sprite != null) {
          _sprite!.render(canvas, position: position, size: spriteSize);
        } else {
          // Fallback: draw a simple colored rectangle
          final paint = Paint()
            ..color = const Color(0xFF1a1a2e)
            ..style = PaintingStyle.fill;
          
          canvas.drawRect(
            Rect.fromLTWH(position.x, position.y, spriteSize.x, spriteSize.y),
            paint,
          );
          
          // Add a subtle grid pattern
          final gridPaint = Paint()
            ..color = const Color(0xFF16213e).withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          
          canvas.drawRect(
            Rect.fromLTWH(position.x, position.y, spriteSize.x, spriteSize.y),
            gridPaint,
          );
        }
      }
    }
  }
}