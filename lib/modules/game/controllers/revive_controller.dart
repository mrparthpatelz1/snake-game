// lib/app/modules/game/controllers/revive_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/service/ad_service.dart';
import '../../../routes/app_routes.dart';
import '../views/game_screen.dart'; // Your SlitherGame class

class ReviveController extends GetxController with GetSingleTickerProviderStateMixin {
  final SlitherGame game;
  ReviveController({required this.game});


  final AdService _adService = Get.find<AdService>();

  late final Timer _timer;
  late final AnimationController animationController;


  final RxInt countdown = 10.obs;

  @override
  void onInit() {
    super.onInit();


    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: countdown.value ),
    )..reverse(from: 1.0);


    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown.value > 0) {
        countdown.value--;
      } else {
        timer.cancel();
        animationController.stop();
        onNext();
      }
    });
  }

  @override
  void onClose() {
    _timer.cancel();
    animationController.dispose();
    super.onClose();
  }

  // --- UI Actions (no change here) ---
  void onRevive() {
    // When reviving, we must cancel the timer and dispose the controller
    // before the game continues.
    _timer.cancel();


    _adService.showRewardedAd(
      onReward: () {
        game.revivePlayer();
      },
    );
  }

  void onNext() {
    _timer.cancel();
    game.showGameOver();
  }



  void onHome() {
    _timer.cancel();
    game.resumeEngine();
    Get.offAllNamed(Routes.HOME);
  }
}