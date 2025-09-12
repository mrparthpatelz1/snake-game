// lib/data/service/audio_service.dart

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AudioService extends GetxService with WidgetsBindingObserver {
  final GetStorage _box = GetStorage();

  // Settings keys
  static const String _musicVolumeKey = 'musicVolume';
  static const String _sfxVolumeKey = 'sfxVolume';
  static const String _musicEnabledKey = 'musicEnabled';
  static const String _sfxEnabledKey = 'sfxEnabled';

  // Reactive variables
  final RxBool isMusicEnabled = true.obs;
  final RxBool isSfxEnabled = true.obs;
  final RxBool isHapticsEnabled = true.obs;
  final RxBool isMusicPlaying = false.obs;
  final RxDouble musicVolume = 0.7.obs;
  final RxDouble sfxVolume = 1.0.obs;

  String? _currentMusicTrack;

  // 🕒 Throttling for eat food sound
  DateTime? _lastEatWindow;
  int _eatCountInWindow = 0;
  static const int _maxEatSoundsPerWindow = 2;
  static const Duration _eatWindowDuration = Duration(milliseconds: 300);

  // Global SFX flood protection (sliding-window count)
  final List<DateTime> _recentSfxTimestamps = [];
  static const Duration _globalWindow = Duration(milliseconds: 800);
  static const int _maxSfxInGlobalWindow = 40; // tweakable (protects device)

  static const Map<String, String> _soundPaths = {
    'button_click': 'sfx/button_click.wav',
    'eat_food': 'sfx/eat_food.wav',
    'death': 'sfx/death.wav',
    'kill': 'sfx/kill.wav',
    'boost_on': 'sfx/boost_on.wav',
    'boost_off': 'sfx/boost_off.wav',
    'switch_on': 'sfx/switch_on.wav',
    'switch_off': 'sfx/switch_off.wav',
    'revive': 'sfx/revive.mp3',
    'game_over': 'sfx/game_over.mp3',
  };

  static const Map<String, String> _musicPaths = {
    'menu': 'music/game_music.mp3',
    'game': 'music/game_music.mp3',
  };

  // Store pools for fast playback
  final Map<String, AudioPool> _sfxPools = {};

  @override
  Future<void> onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this); // observe lifecycle
    _loadSettings();
    await _preloadAudio();
    _setupListeners();
  }

  Future<void> _preloadAudio() async {
    try {
      for (final entry in _soundPaths.entries) {
        // create pools for every sfx so we avoid creating players at runtime
        // maxPlayers tweakable per-sound; 3-6 is a good starting point
        _sfxPools[entry.key] = await FlameAudio.createPool(
          entry.value,
          maxPlayers: 4,
        );
      }

      // Preload music (cached)
      for (final file in _musicPaths.values) {
        await FlameAudio.audioCache.load(file);
      }

      debugPrint("AudioService: ✅ All audio preloaded with pools");
    } catch (e) {
      debugPrint("AudioService: ❌ Preload failed: $e");
    }
  }

  void _loadSettings() {
    isMusicEnabled.value = _box.read(_musicEnabledKey) ?? true;
    isSfxEnabled.value = _box.read(_sfxEnabledKey) ?? true;
    musicVolume.value = (_box.read(_musicVolumeKey) ?? 0.7).toDouble();
    sfxVolume.value = (_box.read(_sfxVolumeKey) ?? 1.0).toDouble();
  }

  void _saveSettings() {
    _box.write(_musicEnabledKey, isMusicEnabled.value);
    _box.write(_sfxEnabledKey, isSfxEnabled.value);
    _box.write(_musicVolumeKey, musicVolume.value);
    _box.write(_sfxVolumeKey, sfxVolume.value);
  }

  void _setupListeners() {
    isMusicEnabled.listen((enabled) {
      _saveSettings();
      if (!enabled) stopMusic();
    });
    isSfxEnabled.listen((_) => _saveSettings());
    musicVolume.listen((vol) {
      _saveSettings();
      try {
        FlameAudio.bgm.audioPlayer.setVolume(vol);
      } catch (_) {}
    });
    sfxVolume.listen((_) => _saveSettings());
  }

  /// Global guard: detect if too many sfx happened recently
  bool _globalSfxAllowed() {
    final now = DateTime.now();
    _recentSfxTimestamps.removeWhere((t) => now.difference(t) > _globalWindow);
    if (_recentSfxTimestamps.length >= _maxSfxInGlobalWindow) {
      // Too many SFX recently — skip new ones until window clears
      debugPrint('AudioService: ⚠️ Global SFX rate limit reached (${_recentSfxTimestamps.length})');
      return false;
    }
    _recentSfxTimestamps.add(now);
    return true;
  }

  /// Play SFX (always prefer pools). Use throttle=true for eat_food-like spammy sounds.
  Future<void> playSfx(String key, {bool throttle = false}) async {
    if (!isSfxEnabled.value) return;

    // if key unknown, return
    if (!_soundPaths.containsKey(key)) {
      debugPrint('AudioService: ❌ Unknown SFX key: $key');
      return;
    }

    // Global flood guard
    if (!_globalSfxAllowed()) return;

    // Eat-food throttling (per-window)
    if (throttle && key == 'eat_food') {
      final now = DateTime.now();
      if (_lastEatWindow == null || now.difference(_lastEatWindow!) > _eatWindowDuration) {
        _lastEatWindow = now;
        _eatCountInWindow = 0;
      }

      if (_eatCountInWindow >= _maxEatSoundsPerWindow) {
        // skip extra
        return;
      }
      _eatCountInWindow++;
    }

    try {
      final pool = _sfxPools[key];
      if (pool != null) {
        // start returns a Future<int> for the player index — we fire-and-forget
        pool.start(volume: sfxVolume.value).catchError((e) {
          debugPrint('AudioService: ❌ pool.start error for $key: $e');
        });
      } else {
        // fallback if pool missing
        FlameAudio.play(_soundPaths[key]!, volume: sfxVolume.value).catchError((e) {
          debugPrint('AudioService: ❌ FlameAudio.play error for $key: $e');
        });
      }
      // debug small success message optionally (comment out if too noisy)
      // debugPrint('AudioService: Played SFX $key');
    } catch (e) {
      debugPrint('AudioService: ❌ Error playing SFX $key: $e');
    }
  }

  /// Play music (looped)
  Future<void> playMusic(String key) async {
    final path = _musicPaths[key];
    if (path == null || !isMusicEnabled.value) return;

    _currentMusicTrack = key;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play(path, volume: musicVolume.value);
      isMusicPlaying.value = true;
      debugPrint('AudioService: ✅ Playing music: $key');
    } catch (e) {
      debugPrint('AudioService: ❌ Error playing music $key: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
      isMusicPlaying.value = false;
      debugPrint('AudioService: Music stopped');
    } catch (e) {
      debugPrint('AudioService: ❌ Error stopping music: $e');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await FlameAudio.bgm.pause();
      isMusicPlaying.value = false;
      debugPrint('AudioService: Music paused');
    } catch (e) {
      debugPrint('AudioService: ❌ Error pausing music: $e');
    }
  }

  Future<void> resumeMusic() async {
    try {
      if (isMusicEnabled.value && _currentMusicTrack != null) {
        await FlameAudio.bgm.resume();
        isMusicPlaying.value = true;
        debugPrint('AudioService: Music resumed');
      }
    } catch (e) {
      debugPrint('AudioService: ❌ Error resuming music: $e');
    }
  }

  void toggleMusic() {
    isMusicEnabled.value = !isMusicEnabled.value;
    playSfx(isMusicEnabled.value ? 'switch_on' : 'switch_off', throttle: true);
    if (isMusicEnabled.value && _currentMusicTrack != null) {
      playMusic(_currentMusicTrack!);
    } else {
      stopMusic();
    }
  }

  void toggleSfx() {
    isSfxEnabled.value = !isSfxEnabled.value;
    playSfx(isSfxEnabled.value ? 'switch_on' : 'switch_off', throttle: true);
  }

  void toggleHaptics() {
    isHapticsEnabled.value = !isHapticsEnabled.value;
    playSfx(isHapticsEnabled.value ? 'switch_on' : 'switch_off', throttle: true);
  }

  // 🎵 SPECIFIC MUSIC HELPERS
  // Future<void> playMenuMusic() => playMusic('menu');
  // Future<void> playGameMusic() => playMusic('game');

  // 🔊 SPECIFIC SFX HELPERS
  Future<void> playButtonClick() => playSfx('button_click');
  // Future<void> playEatFood() => playSfx('eat_food', throttle: true);
  Future<void> playDeath() => playSfx('death');
  Future<void> playKill() => playSfx('kill');
  Future<void> playBoostOn() => playSfx('boost_on');
  Future<void> playBoostOff() => playSfx('boost_off');
  Future<void> playRevive() => playSfx('revive');
  Future<void> playGameOver() => playSfx('game_over');

  // 🕒 Eat food sound cooldown
  DateTime? _lastEatSoundTime;
  static const Duration _eatSoundCooldown = Duration(milliseconds: 320);

  Future<void> playEatFood() async {
    if (!isSfxEnabled.value) return;

    final now = DateTime.now();

    // Cooldown check
    if (_lastEatSoundTime != null &&
        now.difference(_lastEatSoundTime!) < _eatSoundCooldown) {
      return; // skip if too soon
    }

    _lastEatSoundTime = now;

    // Play directly from pool
    final pool = _sfxPools['eat_food'];
    if (pool != null) {
      pool.start(volume: sfxVolume.value);
    } else {
      FlameAudio.play('sfx/eat_food.wav', volume: sfxVolume.value);
    }
  }

  /// Called when app lifecycle changes (background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // app not active — pause/stop audio and stop SFX flood
      debugPrint('AudioService: App lifecycle -> $state. Pausing audio.');
      try {
        pauseMusic();
      } catch (_) {}
      // optionally, prevent further SFX from playing while backgrounded
      // not changing isSfxEnabled persisted setting, just preventing playback now:
      _sfxTemporarilyDisabled = true;
    } else if (state == AppLifecycleState.resumed) {
      // resumed from background -> resume music if enabled
      debugPrint('AudioService: App lifecycle -> resumed. Resuming audio.');
      _sfxTemporarilyDisabled = false;
      if (isMusicEnabled.value && _currentMusicTrack != null) {
        resumeMusic();
      }
      // clear old timestamps so we don't incorrectly rate-limit right away
      _recentSfxTimestamps.clear();
    } else if (state == AppLifecycleState.detached) {
      // detached -> cleanup
      debugPrint('AudioService: App lifecycle -> detached. Disposing audio.');
      stopAllAndDispose();
    }
  }

  bool _sfxTemporarilyDisabled = false; // used during background to ignore playSfx calls

  /// Public method to stop all audio and dispose pools (call on app/game exit)
  void stopAllAndDispose() {
    try {
      stopMusic();
    } catch (_) {}
    // dispose audio pools
    for (final pool in _sfxPools.values) {
      try {
        pool.dispose();
      } catch (_) {}
    }
    _sfxPools.clear();

    // clear tracking fields
    _recentSfxTimestamps.clear();
    _lastEatWindow = null;
    _eatCountInWindow = 0;

    debugPrint('AudioService: 🔇 stopAllAndDispose completed.');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stopAllAndDispose();
    super.onClose();
  }
}
