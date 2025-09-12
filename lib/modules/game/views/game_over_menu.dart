// lib/modules/game/views/game_over_menu.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/service/score_service.dart';
import '../../../data/service/audio_service.dart';  // NEW: Import audio service
import '../../../routes/app_routes.dart';
import 'game_screen.dart';
import '../controllers/player_controller.dart';

class GameOverMenu extends StatelessWidget {
  final SlitherGame game;
  final PlayerController playerController;
  final ScoreService _scoreService = ScoreService();
  final AudioService _audioService = Get.find<AudioService>();  // NEW: Audio service

  GameOverMenu({super.key, required this.game, required this.playerController});

  @override
  Widget build(BuildContext context) {
    // Save the final scores and retrieve the high scores
    final currentScore = playerController.foodScore.value;
    final currentKills = playerController.kills.value;

    if (currentScore > _scoreService.getHighScore()) {
      _scoreService.saveHighScore(currentScore);
    }
    if (currentKills > _scoreService.getHighKills()) {
      _scoreService.saveHighKills(currentKills);
    }

    // NEW: Play game over sound and switch to menu music
    _audioService.playGameOver();
    Future.delayed(const Duration(milliseconds: 500), () {
      // _audioService.playMusic('menu');
    });

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Stack(
        children: [
          // --- HOME BUTTON (Top Left) ---
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () {
                // NEW: Play button click sound
                _audioService.stopMusic();
                _audioService.playButtonClick();
                game.resumeEngine(); // Always resume engine before navigating away
                Get.offAllNamed(Routes.HOME);
              },
              child: Image.asset('assets/images/home Btn.png', width: 60),
            ),
          ),
          // --- MAIN CONTENT ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- GAME OVER TEXT ---
                Text(
                  'GAME OVER!',
                  style: TextStyle(
                    color: Colors.pinkAccent,
                    fontSize: 48,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 5,
                        color: Colors.white, // Outline color
                      ),
                      Shadow(
                        offset: Offset(-1, 1),
                        blurRadius: 5,
                        color: Colors.white,
                      ),
                      Shadow(
                        offset: Offset(1, -1),
                        blurRadius: 5,
                        color: Colors.white,
                      ),
                      Shadow(
                        offset: Offset(-1, -1),
                        blurRadius: 5,
                        color: Colors.white,
                      ),
                    ],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // --- SCORE POPUP ---
                Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/Score Popup.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 55),
                      const Text(
                        'AWESOME!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 35),
                      _buildScoreRow('Your Score', currentScore.toString()),
                      const SizedBox(height: 15),
                      _buildScoreRow('Kills', currentKills.toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- HOME BUTTON ---
                GestureDetector(
                  onTap: () {
                    // NEW: Play button click sound
                    _audioService.stopMusic();
                    _audioService.playButtonClick();
                    game.resumeEngine();
                    Get.offAllNamed(Routes.HOME);
                  },
                  child: Container(
                    width: 280,
                    height: 70,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/Replay Btn.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'HOME',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for a consistent score row style
  Widget _buildScoreRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.brown,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.brown,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}