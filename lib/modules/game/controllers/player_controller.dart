// // lib/app/modules/game/controllers/player_controller.dart
//
// import 'package:flame/components.dart';
// import 'package:get/get.dart';
// import 'package:flutter/material.dart';
// import '../../../data/service/settings_service.dart';
//
// class PlayerController extends GetxController {
//   // --- Configuration ---
//   final RxDouble headRadius = 13.0.obs;
//   final RxDouble bodyRadius = 13.0.obs;
//   final double maxRadius = 35.0; // The maximum size the snake can reach.
//   final double minRadius = 16.0;
//
//   final double baseSpeed = 150.0;
//   final double boostSpeed = 300.0; // Speed when boosting
//
//   final int initialSegmentCount = 10;
//   // The reactive segmentCount now starts with this value.
//   late final RxInt segmentCount = initialSegmentCount.obs;
//   late final double segmentSpacing = headRadius.value * 0.6;
//   final RxBool isBoosting = false.obs;
//   final RxInt kills = 0.obs;
//
//   // --- State ---
//   // The snake starts moving to the right. The joystick will change this.
//   Vector2 targetDirection = Vector2(1, 0);
//
//   late final List<Color> skinColors = Get.find<SettingsService>().selectedSkin;
//
//   // inside PlayerController
//   Vector2 get currentDir {
//     // Use your existing movement/aim direction.
//     // If you already store a Vector2 targetDirection, return its normalized copy.
//     if (targetDirection.length2 == 0) return Vector2.zero();
//     return targetDirection.normalized();
//   }
// }

// lib/app/modules/game/controllers/player_controller.dart

import 'package:flame/components.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/service/settings_service.dart';

class PlayerController extends GetxController {
  // --- Snake size ---
  final RxDouble headRadius = 16.0.obs;
  final RxDouble bodyRadius = 16.0.obs;
  final double maxRadius = 50.0;
  final double minRadius = 16.0;

  // --- Speed ---
  final double baseSpeed = 150.0;
  final double boostSpeed = 300.0;

  // --- Length ---
  final int initialSegmentCount = 10;
  late final RxInt segmentCount = initialSegmentCount.obs;


  // double get segmentSpacing {
  //   final baseSpacing = headRadius.value * 0.7;
  //   // When boosting, reduce spacing by half to make the body look tighter.
  //   return isBoosting.value ? baseSpacing * 1.1 : baseSpacing;
  // }

  // --- Status ---
  final RxBool isBoosting = false.obs;
  final RxInt kills = 0.obs;
  final RxBool hasUsedRevive = false.obs;

  // --- Food growth system ---
  final RxInt foodScore = 0.obs;       // total food collected
  final int foodPerSegment = 5;        // every 5 food -> +1 segment
  final int foodPerRadius = 1000;      // every 1000 food -> +1 px radius

  // --- Direction ---
  Vector2 targetDirection = Vector2(1, 0);

  // --- Skins ---
  late final List<Color> skinColors = Get.find<SettingsService>().selectedSkin;

  Vector2 get currentDir {
    if (targetDirection.length2 == 0) return Vector2.zero();
    return targetDirection.normalized();
  }

  void reset() {
    foodScore.value = 0;
    segmentCount.value = initialSegmentCount;
    headRadius.value = minRadius;
    bodyRadius.value = minRadius;
    kills.value = 0;
    hasUsedRevive.value = false; // Reset the revive flag
  }
}

