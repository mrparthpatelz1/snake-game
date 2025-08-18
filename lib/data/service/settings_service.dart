import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

class SettingsService {
  final GetStorage _box = GetStorage();

  static const String _skinKey = 'selectedSkinIndex';
  static const String _bgColorKey = 'backgroundColorHex';

  // A curated set of skins (palettes). Each palette is 6 colors head->tail.
  final List<List<Color>> _skins = [
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

  int get selectedSkinIndex => _box.read(_skinKey) ?? 0;
  void setSelectedSkinIndex(int index) => _box.write(_skinKey, index);

  List<Color> get selectedSkin {
    final idx = selectedSkinIndex;
    if (idx < 0 || idx >= _skins.length) return _skins.first;
    return _skins[idx];
  }

  List<List<Color>> get allSkins => _skins;

  // Background color selection; default matches current game color.
  Color get backgroundColor {
    final hex = _box.read(_bgColorKey);
    if (hex is int) return Color(hex);
    return Colors.lightBlueAccent;
  }

  void setBackgroundColor(Color color) {
    _box.write(_bgColorKey, color.value);
  }
}

