// lib/app/modules/home/home_bindings.dart

import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../../../data/service/settings_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SettingsService>(SettingsService(), permanent: true);
    Get.put<HomeController>(HomeController(), permanent: true);
  }
}
