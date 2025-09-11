// lib/data/service/audio_service.dart

import 'package:flame/cache.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AudioService extends GetxService {
  final GetStorage _box = GetStorage();

  // Settings keys
  static const String _musicVolumeKey = 'musicVolume';
  static const String _sfxVolumeKey = 'sfxVolume';
  static const String _musicEnabledKey = 'musicEnabled';
  static const String _sfxEnabledKey = 'sfxEnabled';

  // Reactive variables for settings
  final RxBool isMusicEnabled = true.obs;
  final RxBool isSfxEnabled = true.obs;
  final RxDouble musicVolume = 0.7.obs;
  final RxDouble sfxVolume = 1.0.obs;

  // Current music state
  final RxBool isMusicPlaying = false.obs;
  String? _currentMusicTrack;

  // Sound effect paths
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

  // Music paths
  static const Map<String, String> _musicPaths = {
    'menu': 'music/game_music.mp3',
    'game': 'music/game_music.mp3',
  };

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeAudio();
    _loadSettings();
    _setupListeners();
  }

  Future<void> _initializeAudio() async {
    try {
      // Pre-cache all audio files for better performance
      await _preloadAudioFiles();
      debugPrint('AudioService: Flame audio initialized and files preloaded');
    } catch (e) {
      debugPrint('AudioService: Error initializing: $e');
    }
  }

  Future<void> _preloadAudioFiles() async {
    // Preload sound effects
    for (final soundPath in _soundPaths.values) {
      try {
        await FlameAudio.audioCache.load(soundPath);
      } catch (e) {
        debugPrint('AudioService: Failed to preload SFX: $soundPath - $e');
      }
    }

    // Preload music files
    for (final musicPath in _musicPaths.values) {
      try {
        await FlameAudio.audioCache.load(musicPath);
      } catch (e) {
        debugPrint('AudioService: Failed to preload music: $musicPath - $e');
      }
    }
  }

  void _loadSettings() {
    isMusicEnabled.value = _box.read(_musicEnabledKey) ?? true;
    isSfxEnabled.value = _box.read(_sfxEnabledKey) ?? true;
    musicVolume.value = _box.read(_musicVolumeKey)?.toDouble() ?? 0.7;
    sfxVolume.value = _box.read(_sfxVolumeKey)?.toDouble() ?? 1.0;

    debugPrint('AudioService: Settings loaded - Music: ${isMusicEnabled.value}, SFX: ${isSfxEnabled.value}');
  }

  void _setupListeners() {
    // Handle music enable/disable
    isMusicEnabled.listen((enabled) {
      _saveSettings();
      if (enabled && _currentMusicTrack != null) {
        playMusic(_currentMusicTrack!);
      } else if (!enabled) {
        stopMusic();
      }
    });

    isSfxEnabled.listen((_) => _saveSettings());
    musicVolume.listen((_) => _saveSettings());
    sfxVolume.listen((_) => _saveSettings());
  }

  void _saveSettings() {
    _box.write(_musicEnabledKey, isMusicEnabled.value);
    _box.write(_sfxEnabledKey, isSfxEnabled.value);
    _box.write(_musicVolumeKey, musicVolume.value);
    _box.write(_sfxVolumeKey, sfxVolume.value);
  }

  // Public methods for controlling audio

  /// Toggle music on/off
  void toggleMusic() {
    isMusicEnabled.value = !isMusicEnabled.value;
    playSfx('switch_${isMusicEnabled.value ? 'on' : 'off'}');
    debugPrint('AudioService: Music toggled to ${isMusicEnabled.value}');
  }

  /// Toggle sound effects on/off
  void toggleSfx() {
    isSfxEnabled.value = !isSfxEnabled.value;
    _saveSettings();
    // Play the toggle sound if SFX was just enabled
    if (isSfxEnabled.value) {
      playSfx('switch_on');
    }
    debugPrint('AudioService: SFX toggled to ${isSfxEnabled.value}');
  }

  /// Play background music
  Future<void> playMusic(String musicKey) async {
    if (!_musicPaths.containsKey(musicKey)) {
      debugPrint('AudioService: Music key "$musicKey" not found');
      return;
    }

    try {
      _currentMusicTrack = musicKey;

      if (!isMusicEnabled.value) {
        debugPrint('AudioService: Music disabled, not playing $musicKey');
        return;
      }

      // Stop current music first
      await stopMusic();

      // Play new music with volume
      await FlameAudio.bgm.play(
        _musicPaths[musicKey]!,
        volume: musicVolume.value,
      );

      isMusicPlaying.value = true;
      debugPrint('AudioService: Playing music: $musicKey at volume ${musicVolume.value}');
    } catch (e) {
      debugPrint('AudioService: Error playing music $musicKey: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
      isMusicPlaying.value = false;
      debugPrint('AudioService: Music stopped');
    } catch (e) {
      debugPrint('AudioService: Error stopping music: $e');
    }
  }

  /// Pause background music
  Future<void> pauseMusic() async {
    try {
      await FlameAudio.bgm.pause();
      isMusicPlaying.value = false;
      debugPrint('AudioService: Music paused');
    } catch (e) {
      debugPrint('AudioService: Error pausing music: $e');
    }
  }

  /// Resume background music
  Future<void> resumeMusic() async {
    try {
      if (isMusicEnabled.value) {
        await FlameAudio.bgm.resume();
        isMusicPlaying.value = true;
        debugPrint('AudioService: Music resumed');
      }
    } catch (e) {
      debugPrint('AudioService: Error resuming music: $e');
    }
  }

  /// Play a sound effect
  Future<void> playSfx(String sfxKey) async {
    if (!isSfxEnabled.value) return;

    if (!_soundPaths.containsKey(sfxKey)) {
      debugPrint('AudioService: SFX key "$sfxKey" not found');
      return;
    }

    try {
      await FlameAudio.play(
        _soundPaths[sfxKey]!,
        volume: sfxVolume.value,
      );
      debugPrint('AudioService: Playing SFX: $sfxKey at volume ${sfxVolume.value}');
    } catch (e) {
      debugPrint('AudioService: Error playing SFX $sfxKey: $e');
      // Graceful fallback - continue without sound
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    musicVolume.value = volume.clamp(0.0, 1.0);
    // Update current playing music volume
    if (isMusicPlaying.value && _currentMusicTrack != null) {
      await playMusic(_currentMusicTrack!);
    }
  }

  /// Set SFX volume (0.0 to 1.0)
  Future<void> setSfxVolume(double volume) async {
    sfxVolume.value = volume.clamp(0.0, 1.0);
  }

  // Convenience methods for common sounds
  void playButtonClick() => playSfx('button_click');
  void playEatFood() => playSfx('eat_food');
  void playDeath() => playSfx('death');
  void playKill() => playSfx('kill');
  void playBoostOn() => playSfx('boost_on');
  void playBoostOff() => playSfx('boost_off');
  void playRevive() => playSfx('revive');
  void playGameOver() => playSfx('game_over');

  /// Clear all cached audio (useful for memory management)
  Future<void> clearCache() async {
    try {
      await FlameAudio.audioCache.clearAll();
      debugPrint('AudioService: Audio cache cleared');
    } catch (e) {
      debugPrint('AudioService: Error clearing cache: $e');
    }
  }

  @override
  void onClose() {
    // Flame audio cleanup is handled automatically
    super.onClose();
  }
}