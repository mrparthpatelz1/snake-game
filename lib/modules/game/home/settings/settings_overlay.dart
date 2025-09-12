import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newer_version_snake/modules/game/home/settings/settings_controller.dart';

import '../../../../data/service/audio_service.dart';

class SettingsOverlay extends GetView<SettingsController> {
  const SettingsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioService audioService = Get.find<AudioService>();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        height: 450,
        width: Get.width,
        decoration: const BoxDecoration(
          // color: Colors.red,
          image: DecorationImage(
            image: AssetImage('assets/images/Settings Popup.png'),
            fit: BoxFit.contain,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                const SizedBox(height: 73),
                const Text(
                  'SETTINGS',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 40),
                _buildSettingRow(
                  iconAsset: 'assets/images/SFX.png',
                  label: 'Sound',
                  value: controller.isSoundOn,
                  onToggle: controller.toggleSound,
                ),
                const SizedBox(height: 15),
                _buildSettingRow(
                  iconAsset: 'assets/images/Music.png',
                  label: 'Music',
                  value: controller.isMusicOn,
                  onToggle: controller.toggleMusic,
                ),
                const SizedBox(height: 15),
                _buildSettingRow(
                  iconAsset: 'assets/images/Haptic.png',
                  label: 'Haptics',
                  value: controller.isHapticOn,
                  onToggle: controller.toggleHaptic,
                ),
                const SizedBox(height: 10),
                // _buildCreditsButton(),
              ],
            ),
            Positioned(
              top: 50,
              right: 35,
              child: GestureDetector(
                onTap: () => {audioService.playButtonClick(),Get.back()},
                child: Image.asset('assets/images/Close Btn.png', width: 35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required String iconAsset,
    required String label,
    required RxBool value,
    required VoidCallback onToggle,
  }) {
    return Container(
      width: 240,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/Settings Options BG.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(iconAsset, height: 30),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          AnimatedSwitch(value: value, onToggle: onToggle),
        ],
      ),
    );
  }

  Widget _buildCreditsButton() {
    return GestureDetector(
      onTap: () => Get.snackbar('Credits', 'Credits button pressed!'),
      child: Container(
        width: 200,
        height: 60,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Credit Btn.png'),
            fit: BoxFit.contain,
          ),
        ),
        child: const Center(
          child: Text('CREDITS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// --- CORRECTED AnimatedSwitch Widget ---
class AnimatedSwitch extends StatelessWidget {
  final RxBool value;
  final VoidCallback onToggle;
  const AnimatedSwitch({super.key, required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: SizedBox(
        width: 90,
        height: 45,
        child: Obx(
              () => Stack(
            alignment: Alignment.center,
            children: [
              // 1. The Background Image (On/Off)
              Image.asset(
                value.value ? 'assets/images/On.png' : 'assets/images/Off.png',
                fit: BoxFit.contain,
                width: 90,
                height: 45,
              ),
              // 2. The Animated Knob
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: value.value ? Alignment.centerRight : Alignment.centerLeft,
                // This container holds the cropped knob image
                child: SizedBox(
                  width: 90,
                  height: 45,
                  child: ClipRect(
                    child: Align(
                      // This trick ensures we only see the knob part of the image
                      alignment: value.value ? Alignment.centerRight : Alignment.centerLeft,
                      widthFactor: 0.5,
                      child: Image.asset(
                        value.value ? 'assets/images/On.png' : 'assets/images/Off.png',
                        fit: BoxFit.contain,
                        height: 45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}