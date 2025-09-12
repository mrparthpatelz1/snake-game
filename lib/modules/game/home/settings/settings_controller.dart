// lib/modules/game/home/settings/settings_controller.dart

import 'package:get/get.dart';
import '../../../../data/service/audio_service.dart';
import '../../../../data/service/haptic_service.dart';

class SettingsController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();
  final HapticService _hapticService = Get.find<HapticService>();

  // Getters to expose audio service states
  RxBool get isSoundOn => _audioService.isSfxEnabled;
  RxBool get isMusicOn => _audioService.isMusicEnabled;
  RxBool get isHapticOn => _hapticService.isHapticsEnabled; // Placeholder for haptic setting

  // Methods to toggle the state of each switch with audio feedback
  void toggleSound() {
    _audioService.toggleSfx();
  }

  void toggleMusic() {
    _audioService.toggleMusic();
  }

  void toggleHaptic() {
    // Play button click sound when toggling haptic
    _hapticService.toggleHaptics();
    // For now, we'll just play the sound effect
  }

  // Play button click sound for any UI interaction
  void playButtonClick() {
    _audioService.playButtonClick();
  }
}