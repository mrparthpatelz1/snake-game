// lib/app/modules/home/controllers/home_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../data/service/score_service.dart';
import '../home/settings/settings_controller.dart';
import '../home/settings/settings_overlay.dart';

class HomeController extends GetxController {
  // A controller to manage the text input for the nickname.
  final TextEditingController nicknameController = TextEditingController();
  final ScoreService _scoreService = ScoreService();

  // A reactive variable to hold the high score.
  final RxInt highScore = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // When the controller starts, load the high score.
    highScore.value = _scoreService.getHighScore();
  }

  // --- NEW METHOD ---
  void openSettings() {
    Get.put(SettingsController());
    Get.dialog(const SettingsOverlay());
  }

  @override
  void onClose() {
    nicknameController.dispose();
    super.onClose();
  }
}