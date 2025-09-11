// lib/modules/game/home/settings/settings_controller.dart

import 'package:get/get.dart';
import '../../../../data/service/audio_service.dart';

class SettingsController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  // Getters to expose audio service states
  RxBool get isSoundOn => _audioService.isSfxEnabled;
  RxBool get isMusicOn => _audioService.isMusicEnabled;
  RxBool get isHapticOn => true.obs; // Placeholder for haptic setting

  // Methods to toggle the state of each switch with audio feedback
  void toggleSound() {
    _audioService.toggleSfx();
  }

  void toggleMusic() {
    _audioService.toggleMusic();
  }

  void toggleHaptic() {
    // Play button click sound when toggling haptic
    _audioService.playButtonClick();
    // TODO: Add logic here to enable/disable haptic feedback
    // For now, we'll just play the sound effect
  }

  // Additional methods for volume control (if needed)
  void setMusicVolume(double volume) {
    _audioService.setMusicVolume(volume);
  }

  void setSfxVolume(double volume) {
    _audioService.setSfxVolume(volume);
  }

  // Play button click sound for any UI interaction
  void playButtonClick() {
    _audioService.playButtonClick();
  }
}