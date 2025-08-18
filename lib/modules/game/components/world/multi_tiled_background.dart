import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class MultiTiledBackground extends Component with HasGameRef {
  static const double tileSize = 512.0;

  final List<List<String>> tileMap;
  final Set<String> tileTypes;
  final Map<String, ui.Image> tileImages = {};

  MultiTiledBackground({required this.tileMap})
      : tileTypes = tileMap.expand((row) => row).toSet();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Load and cache all needed tile images
    for (final type in tileTypes) {
      final sprite = await game.loadSprite('tiles/$type.png');
      tileImages[type] = sprite.image;
    }
    priority = -10;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final camera = game.camera;
    final view = camera.visibleWorldRect;

    final startCol = max(0, (view.left / tileSize).floor());
    final endCol = min(tileMap[0].length, (view.right / tileSize).ceil());
    final startRow = max(0, (view.top / tileSize).floor());
    final endRow = min(tileMap.length, (view.bottom / tileSize).ceil());

    for (int row = startRow; row < endRow; row++) {
      for (int col = startCol; col < endCol; col++) {
        final type = tileMap[row][col];
        final image = tileImages[type];
        if (image == null) continue;

        final dx = col * tileSize.toDouble();
        final dy = row * tileSize.toDouble();

        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(dx, dy, tileSize, tileSize),
          Paint(),
        );
      }
    }
  }
}
