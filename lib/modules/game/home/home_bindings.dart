// lib/app/modules/home/home_bindings.dart

import 'package:get/get.dart';

import '../../../data/service/audio_service.dart';
import '../controllers/home_controller.dart';
import '../../../data/service/settings_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SettingsService>(SettingsService(), permanent: true);

    // NEW: Ensure AudioService is available (should already be registered in main.dart)
    // if (!Get.isRegistered<AudioService>()) {
    //   Get.put<AudioService>(AudioService(), permanent: true);
    // }

    Get.put<HomeController>(HomeController(), permanent: true);
  }
}
