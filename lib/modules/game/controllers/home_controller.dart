// lib/app/modules/home/controllers/home_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../data/service/score_service.dart';

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


  @override
  void onClose() {
    nicknameController.dispose();
    super.onClose();
  }
}