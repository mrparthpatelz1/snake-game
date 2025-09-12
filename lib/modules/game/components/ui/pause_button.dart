// lib/app/modules/game/components/ui/pause_button.dart

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newer_version_snake/data/service/audio_service.dart';
import '../../views/game_screen.dart';

class PauseButton extends PositionComponent
    with TapCallbacks, HasGameRef<SlitherGame> {
  final Paint _paint = Paint()..color = Colors.white.withOpacity(0.3);
  final AudioService audioService = Get.find<AudioService>();

  PauseButton({required Vector2 position})
    : super(position: position, size: Vector2.all(60));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle((size / 2).toOffset(), size.x / 2, _paint);

    // Draw two vertical bars for the pause icon
    final barWidth = size.x * 0.15;
    final barHeight = size.y * 0.4;
    final barPaint = Paint()..color = Colors.white;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.x * 0.35, size.y * 0.5),
        width: barWidth,
        height: barHeight,
      ),
      barPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.x * 0.65, size.y * 0.5),
        width: barWidth,
        height: barHeight,
      ),
      barPaint,
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    // When tapped, pause the game engine and show the 'pauseMenu' overlay.
    game.pauseEngine();
    audioService.playButtonClick();
    game.overlays.add('pauseMenu');
  }
}
