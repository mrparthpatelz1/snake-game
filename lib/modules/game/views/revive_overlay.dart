// lib/modules/game/views/revive_overlay.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../controllers/revive_controller.dart';
import '../../../data/service/audio_service.dart';  // NEW: Import audio service

class ReviveOverlay extends GetView<ReviveController> {
  const ReviveOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioService audioService = Get.find<AudioService>();  // NEW: Audio service

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () {
                // NEW: Play button click sound and switch to menu music
                audioService.playButtonClick();
                // audioService.playMusic('menu');
                controller.onHome();
              },
              child: Image.asset('assets/images/home Btn.png', width: 60),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center, // ✅ Center everything
                    children: [
                      Image.asset('assets/images/Timer-BG.png'),
                      AnimatedBuilder(
                        animation: controller.animationController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (rect) {
                              return SweepGradient(
                                startAngle: 0.0,
                                endAngle: pi * 2,
                                stops: [
                                  0.0,
                                  controller.animationController.value,
                                  controller.animationController.value,
                                  1.0
                                ],
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                              ).createShader(rect);
                            },
                            child: Image.asset('assets/images/Timer-Progress.png'),
                          );
                        },
                      ),
                      Obx(
                            () => Text(
                          controller.countdown.value.toString(),
                          textAlign: TextAlign.center,
                          strutStyle: const StrutStyle(
                            fontSize: 64,
                            forceStrutHeight: true, // forces tight height
                            height: 1,              // remove extra spacing
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black54),
                            ],
                          ),
                        ),

                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
                _buildButton(
                  onTap: () {
                    // NEW: Play button click sound
                    audioService.playButtonClick();
                    controller.onRevive();
                  },
                  buttonAsset: 'assets/images/Revive Btn.png',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/Video Ad Icon.png', height: 30),
                      const SizedBox(width: 12),
                      const Text(
                        'REVIVE?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildButton(
                  onTap: () {
                    // NEW: Play button click sound
                    audioService.playButtonClick();
                    controller.onNext();
                  },
                  buttonAsset: 'assets/images/Next Btn.png',
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onTap,
    required String buttonAsset,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 70,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(buttonAsset),
            fit: BoxFit.contain,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}