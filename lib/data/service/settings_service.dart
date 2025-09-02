import 'package:flutter/material.dart';
import 'package:get/get.dart'; // You will need to add this import for RxInt
import 'package:get_storage/get_storage.dart';

class SettingsService {
  final GetStorage _box = GetStorage();

  // --- KEYS FOR STORAGE ---
  static const String _skinKey = 'selectedSkinIndex';
  static const String _bgColorKey = 'backgroundColorHex';
  // --- ADD THIS LINE ---
  static const String _headKey = 'selectedHeadIndex';

  // --- SKIN SETTINGS ---
  final List<List<Color>> allSkins = [ // Made this public for the customization screen
    [
      Colors.blue.shade400,
      Colors.lightGreen.shade400,
      Colors.yellow.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
      Colors.purple.shade400,
    ],
    [
      const Color(0xFF00E5FF),
      const Color(0xFF00B8D4),
      const Color(0xFF00ACC1),
      const Color(0xFF00838F),
      const Color(0xFF006064),
      const Color(0xFF004D40),
    ],
    [
      const Color(0xFFFFD54F),
      const Color(0xFFFFB74D),
      const Color(0xFFFF8A65),
      const Color(0xFFE57373),
      const Color(0xFFBA68C8),
      const Color(0xFF7986CB),
    ],
    [
      const Color(0xFFA5D6A7),
      const Color(0xFF81C784),
      const Color(0xFF66BB6A),
      const Color(0xFF4CAF50),
      const Color(0xFF43A047),
      const Color(0xFF388E3C),
    ],
    [
      const Color(0xFFFF8A80),
      const Color(0xFFFF5252),
      const Color(0xFFFF1744),
      const Color(0xFFD50000),
      const Color(0xFFB71C1C),
      const Color(0xFF880E4F),
    ],
  ];

  final RxInt selectedSkinIndex = 0.obs;

  void setSelectedSkinIndex(int index) {
    if (index >= 0 && index < allSkins.length) {
      selectedSkinIndex.value = index;
      _box.write(_skinKey, index);
    }
  }

  List<Color> get selectedSkin {
    final idx = selectedSkinIndex.value;
    if (idx < 0 || idx >= allSkins.length) return allSkins.first;
    return allSkins[idx];
  }

  // --- HEAD SETTINGS (NEW) ---

  final List<String> allHeads = [
    '01.png',
    '02.png',
    '03.png',
    '04.png',
    '05.png',
    '06.png',
    '07.png',
    '08.png',
  ];

  final RxInt selectedHeadIndex = 0.obs;

  void setSelectedHeadIndex(int index) {
    if (index >= 0 && index < allHeads.length) {
      selectedHeadIndex.value = index;
      _box.write(_headKey, index);
    }
  }

  String get selectedHead {
    final idx = selectedHeadIndex.value;
    if (idx < 0 || idx >= allHeads.length) return allHeads.first;
    return allHeads[idx];
  }

  // --- BACKGROUND SETTINGS ---
  Color get backgroundColor {
    final hex = _box.read(_bgColorKey);
    if (hex is int) return Color(hex);
    return Colors.lightBlueAccent;
  }

  void setBackgroundColor(Color color) {
    _box.write(_bgColorKey, color.value);
  }

  // --- INITIALIZATION ---
  // A method to load all settings from storage when the app starts.
  Future<void> init() async {
    // Load saved skin index
    selectedSkinIndex.value = _box.read(_skinKey) ?? 0;

    // Load saved head index
    selectedHeadIndex.value = _box.read(_headKey) ?? 0;
  }
}