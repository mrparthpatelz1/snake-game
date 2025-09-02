// lib/app/modules/customization/controllers/customization_controller.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../data/service/settings_service.dart';

// --- MODIFIED: Add a TickerProvider for the animation ---
class CustomizationController extends GetxController with GetSingleTickerProviderStateMixin {
  final settings = Get.find<SettingsService>();

  late final RxInt tempSelectedSkinIndex;
  late final RxInt tempSelectedHeadIndex;

  late final List<List<Color>> allSkins;
  late final List<String> allHeads;

  final Rx<ui.Image?> loadedHeadImage = Rx(null);

  // --- NEW: AnimationController to drive the movement ---
  late final AnimationController animationController;

  @override
  void onInit() {
    super.onInit();
    tempSelectedSkinIndex = settings.selectedSkinIndex;
    tempSelectedHeadIndex = settings.selectedHeadIndex;

    allSkins = settings.allSkins;
    allHeads = settings.allHeads;

    // Initialize the AnimationController to loop forever.
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadHeadImage(allHeads[tempSelectedHeadIndex.value]);
  }

  // --- NEW: Dispose the controller when the screen is closed ---
  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  Future<void> _loadHeadImage(String assetName) async {
    final ByteData data = await rootBundle.load('assets/images/$assetName');
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    loadedHeadImage.value = fi.image;
  }

  void selectSkin(int index) {
    tempSelectedSkinIndex.value = index;
  }



  void selectHead(int index) {
    tempSelectedHeadIndex.value = index;
    _loadHeadImage(allHeads[index]);
  }

  void saveChanges() {
    settings.setSelectedSkinIndex(tempSelectedSkinIndex.value);
    settings.setSelectedHeadIndex(tempSelectedHeadIndex.value);
    Get.back();
    Get.snackbar(
      'Saved!',
      'Your new look has been saved.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
}