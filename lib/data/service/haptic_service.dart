// lib/data/service/haptic_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class HapticService extends GetxService with WidgetsBindingObserver {
  final GetStorage _box = GetStorage();

  // Settings key
  static const String _hapticsEnabledKey = 'hapticsEnabled';

  // Reactive variable
  final RxBool isHapticsEnabled = true.obs;

  // Haptic intensity settings
  final RxDouble lightIntensity = 0.3.obs;
  final RxDouble mediumIntensity = 0.6.obs;
  final RxDouble heavyIntensity = 1.0.obs;

  // Throttling for repeated haptics (like eating food)
  DateTime? _lastLightHapticTime;
  DateTime? _lastMediumHapticTime;
  DateTime? _lastHeavyHapticTime;
  static const Duration _lightHapticCooldown = Duration(milliseconds: 50);
  static const Duration _mediumHapticCooldown = Duration(milliseconds: 100);
  static const Duration _heavyHapticCooldown = Duration(milliseconds: 200);

  // Global haptic flood protection
  final List<DateTime> _recentHapticTimestamps = [];
  static const Duration _globalWindow = Duration(milliseconds: 1000);
  static const int _maxHapticsInGlobalWindow = 10; // Prevent haptic spam

  @override
  Future<void> onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _setupListeners();
  }

  void _loadSettings() {
    isHapticsEnabled.value = _box.read(_hapticsEnabledKey) ?? true;
  }

  void _saveSettings() {
    _box.write(_hapticsEnabledKey, isHapticsEnabled.value);
  }

  void _setupListeners() {
    isHapticsEnabled.listen((_) => _saveSettings());
  }

  /// Global guard: detect if too many haptics happened recently
  bool _globalHapticAllowed() {
    if (!isHapticsEnabled.value) return false;

    final now = DateTime.now();
    _recentHapticTimestamps.removeWhere((t) => now.difference(t) > _globalWindow);

    if (_recentHapticTimestamps.length >= _maxHapticsInGlobalWindow) {
      debugPrint('HapticService: ⚠️ Global haptic rate limit reached');
      return false;
    }

    _recentHapticTimestamps.add(now);
    return true;
  }

  /// Light haptic feedback (subtle touches, UI interactions)
  Future<void> light({bool throttle = false}) async {
    if (!_globalHapticAllowed()) return;

    // Throttling check
    if (throttle) {
      final now = DateTime.now();
      if (_lastLightHapticTime != null &&
          now.difference(_lastLightHapticTime!) < _lightHapticCooldown) {
        return;
      }
      _lastLightHapticTime = now;
    }

    try {
      await HapticFeedback.vibrate();
      debugPrint('HapticService: Light haptic triggered');
    } catch (e) {
      debugPrint('HapticService: ❌ Light haptic error: $e');
    }
  }

  /// Medium haptic feedback (button presses, significant actions)
  Future<void> medium({bool throttle = false}) async {
    if (!_globalHapticAllowed()) return;

    // Throttling check
    if (throttle) {
      final now = DateTime.now();
      if (_lastMediumHapticTime != null &&
          now.difference(_lastMediumHapticTime!) < _mediumHapticCooldown) {
        return;
      }
      _lastMediumHapticTime = now;
    }

    try {
      await HapticFeedback.vibrate();
      debugPrint('HapticService: Medium haptic triggered');
    } catch (e) {
      debugPrint('HapticService: ❌ Medium haptic error: $e');
    }
  }

  /// Heavy haptic feedback (major events, deaths, victories)
  Future<void> heavy({bool throttle = false}) async {
    if (!_globalHapticAllowed()) return;

    // Throttling check
    if (throttle) {
      final now = DateTime.now();
      if (_lastHeavyHapticTime != null &&
          now.difference(_lastHeavyHapticTime!) < _heavyHapticCooldown) {
        return;
      }
      _lastHeavyHapticTime = now;
    }

    try {
      await HapticFeedback.vibrate();
      debugPrint('HapticService: Heavy haptic triggered');
    } catch (e) {
      debugPrint('HapticService: ❌ Heavy haptic error: $e');
    }
  }

  /// Selection click (subtle click feedback)
  Future<void> selectionClick({bool throttle = false}) async {
    if (!_globalHapticAllowed()) return;

    // Throttling check for selection clicks
    if (throttle) {
      final now = DateTime.now();
      if (_lastLightHapticTime != null &&
          now.difference(_lastLightHapticTime!) < _lightHapticCooldown) {
        return;
      }
      _lastLightHapticTime = now;
    }

    try {
      await HapticFeedback.vibrate();
      debugPrint('HapticService: Selection click triggered');
    } catch (e) {
      debugPrint('HapticService: ❌ Selection click error: $e');
    }
  }

  /// Vibration pattern for special events (like revive, victory)
  Future<void> vibrationPattern(List<int> pattern) async {
    if (!isHapticsEnabled.value) return;

    try {
      await HapticFeedback.vibrate();
      // Note: Custom patterns require platform-specific implementation
      debugPrint('HapticService: Vibration pattern triggered');
    } catch (e) {
      debugPrint('HapticService: ❌ Vibration pattern error: $e');
    }
  }

  /// Toggle haptics on/off
  void toggleHaptics() {
    isHapticsEnabled.value = !isHapticsEnabled.value;

    // Provide immediate feedback when toggling
    if (isHapticsEnabled.value) {
      Future.delayed(const Duration(milliseconds: 100), () => medium());
    }

    debugPrint('HapticService: Haptics ${isHapticsEnabled.value ? 'enabled' : 'disabled'}');
  }

  // 🎮 GAME-SPECIFIC HAPTIC METHODS

  /// Food eating feedback (throttled)
  Future<void> eatFood() => selectionClick(throttle: true);

  /// Snake growth feedback
  Future<void> grow() => light();

  /// Boost start feedback
  Future<void> boostStart() => selectionClick();

  /// Boost end feedback
  Future<void> boostEnd() => light();

  /// Button press feedback
  Future<void> buttonPress() => medium();

  /// Player death feedback
  Future<void> death() => heavy();

  /// Enemy kill feedback
  Future<void> kill() => medium();

  /// Revive success feedback
  Future<void> revive() => heavy();

  /// Collision feedback (when hitting something)
  Future<void> collision() => medium(throttle: true);

  /// UI navigation feedback
  Future<void> navigate() => light();

  /// Achievement/victory feedback
  Future<void> victory() => heavy();

  /// Warning feedback (danger, low health, etc.)
  Future<void> warning() => medium(throttle: true);

  /// Called when app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Clear haptic timestamps when app goes to background
      _recentHapticTimestamps.clear();
      debugPrint('HapticService: App backgrounded, cleared haptic timestamps');
    } else if (state == AppLifecycleState.resumed) {
      // Reset cooldowns when returning to foreground
      _lastLightHapticTime = null;
      _lastMediumHapticTime = null;
      _lastHeavyHapticTime = null;
      debugPrint('HapticService: App resumed, reset haptic cooldowns');
    }
  }

  /// Clean up resources
  void dispose() {
    _recentHapticTimestamps.clear();
    _lastLightHapticTime = null;
    _lastMediumHapticTime = null;
    _lastHeavyHapticTime = null;
    debugPrint('HapticService: 🔇 Disposed');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    dispose();
    super.onClose();
  }
}