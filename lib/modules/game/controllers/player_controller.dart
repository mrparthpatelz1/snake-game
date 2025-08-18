// lib/app/modules/game/controllers/player_controller.dart

import 'package:flame/components.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/service/settings_service.dart';

class PlayerController extends GetxController {
  // --- Configuration ---
  final RxDouble headRadius = 13.0.obs;
  final RxDouble bodyRadius = 13.0.obs;
  final double maxRadius = 35.0; // The maximum size the snake can reach.
  final double minRadius = 16.0;

  final double baseSpeed = 150.0;
  final double boostSpeed = 300.0; // Speed when boosting

  final int initialSegmentCount = 10;
  // The reactive segmentCount now starts with this value.
  late final RxInt segmentCount = initialSegmentCount.obs;
  late final double segmentSpacing = headRadius.value * 0.6;
  final RxBool isBoosting = false.obs;
  final RxInt kills = 0.obs;

  // --- State ---
  // The snake starts moving to the right. The joystick will change this.
  Vector2 targetDirection = Vector2(1, 0);

  late final List<Color> skinColors = Get.find<SettingsService>().selectedSkin;
}
