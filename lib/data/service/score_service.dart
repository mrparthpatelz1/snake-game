// lib/app/data/services/score_service.dart

import 'package:get_storage/get_storage.dart';

class ScoreService {
  final _box = GetStorage();
  final _key = 'highScore';
  final _killsKey = 'highKills';

  // Reads the high score from local storage. Defaults to 0 if it doesn't exist.
  int getHighScore() {
    return _box.read(_key) ?? 0;
  }

  // Saves a new high score to local storage.
  Future<void> saveHighScore(int score) {
    return _box.write(_key, score);
  }

  int getHighKills() {
    return _box.read(_killsKey) ?? 0;
  }

  Future<void> saveHighKills(int kills) {
    return _box.write(_killsKey, kills);
  }
}
