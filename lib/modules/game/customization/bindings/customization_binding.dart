// lib/app/modules/customization/bindings/customization_binding.dart

import 'package:get/get.dart';

import '../controllers/customization_controller.dart';

class CustomizationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomizationController>(
          () => CustomizationController(),
    );
  }
}