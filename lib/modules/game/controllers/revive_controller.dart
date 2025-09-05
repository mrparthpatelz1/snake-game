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
      duration: Duration(seconds: countdown.value),
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

  // FIXED: Proper revive handling
  void onRevive() {
    _timer.cancel();
    animationController.stop();


    _adService.showRewardedAd(
      onReward: () {
          game.revivePlayer();
      },
    );
  }

  // FIXED: Handle revive failure gracefully
  void _handleReviveFailure() {
    print('Revive failed, showing game over...');
    Get.delete<ReviveController>();
    game.overlays.remove('revive');
    game.showGameOver();
  }

  void onNext() {
    _timer.cancel();
    Get.delete<ReviveController>();
    game.showGameOver();
  }

  void onHome() {
    _timer.cancel();
    Get.delete<ReviveController>();
    game.overlays.remove('revive');
    game.resumeEngine();
    Get.offAllNamed(Routes.HOME);
  }
}