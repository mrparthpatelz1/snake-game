import 'package:get/get.dart';
import '../../data/service/audio_service.dart';
import '../../data/service/settings_service.dart';
import 'controllers/player_controller.dart';

// This binding ensures that the PlayerController is created and available
// to the GameScreen and its children (like the FlameGame instance).
class GameBinding extends Bindings {
  @override
  void dependencies() {
    // Settings service used for skins/background selection
    Get.put<SettingsService>(SettingsService(), permanent: true);
    // Use lazyPut to create the controller instance only when it's first needed.

    // NEW: Ensure AudioService is available (should already be registered in main.dart)
    // if (!Get.isRegistered<AudioService>()) {
    //   Get.put<AudioService>(AudioService(), permanent: true);
    // }

    Get.lazyPut<PlayerController>(() => PlayerController());
  }
}
