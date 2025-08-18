// lib/app/modules/game/components/ui/boost_button.dart

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/player_controller.dart';

class BoostButton extends PositionComponent with TapCallbacks {
  final PlayerController playerController = Get.find<PlayerController>();

  // Paints for different states
  final Paint _paint = Paint()..color = Colors.white.withOpacity(0.3);
  final Paint _paintActive = Paint()..color = Colors.white.withOpacity(0.5);
  final Paint _paintDisabled = Paint()..color = Colors.grey.withOpacity(0.2);

  // Paints for the icon
  final Paint _iconPaint = Paint()..color = Colors.white;
  final Paint _iconPaintDisabled = Paint()..color = Colors.white.withOpacity(0.4);
  late final Path _lightningPath;

  BoostButton({required Vector2 position}) : super(position: position, size: Vector2.all(80));

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _lightningPath = _createLightningPath();
  }

  // This function creates the lightning bolt shape.
  Path _createLightningPath() {
    final path = Path();
    final w = size.x * 0.4;
    final h = size.y * 0.6;
    path.moveTo(size.x * 0.5 + w * 0.2, size.y * 0.5 - h * 0.5);
    path.lineTo(size.x * 0.5 - w * 0.3, size.y * 0.5 + h * 0.1);
    path.lineTo(size.x * 0.5 + w * 0.3, size.y * 0.5 + h * 0.1);
    path.lineTo(size.x * 0.5 - w * 0.2, size.y * 0.5 + h * 0.5);
    return path;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bool canBoost = playerController.segmentCount.value > playerController.initialSegmentCount;

    // Choose the correct paint based on the state.
    final currentBgPaint = canBoost
        ? (playerController.isBoosting.value ? _paintActive : _paint)
        : _paintDisabled;
    final currentIconPaint = canBoost ? _iconPaint : _iconPaintDisabled;

    // Draw the button background and the icon.
    canvas.drawCircle((size / 2).toOffset(), size.x / 2, currentBgPaint);
    canvas.drawPath(_lightningPath, currentIconPaint..style = PaintingStyle.stroke..strokeWidth = 5);
  }

  @override
  void onTapDown(TapDownEvent event) {
    playerController.isBoosting.value = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    playerController.isBoosting.value = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    playerController.isBoosting.value = false;
  }
}