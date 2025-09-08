import 'package:get/get.dart';

class SettingsController extends GetxController {
  // Reactive variables to hold the state of each switch.
  // We'll initialize them to 'on' by default.
  final RxBool isSoundOn = true.obs;
  final RxBool isMusicOn = false.obs;
  final RxBool isHapticOn = true.obs;

  // Methods to toggle the state of each switch.
  void toggleSound() {
    isSoundOn.value = !isSoundOn.value;
    // TODO: Add logic here to actually mute/unmute sound
  }

  void toggleMusic() {
    isMusicOn.value = !isMusicOn.value;
    // TODO: Add logic here to actually mute/unmute music
  }

  void toggleHaptic() {
    isHapticOn.value = !isHapticOn.value;
    // TODO: Add logic here to enable/disable haptic feedback
  }
}