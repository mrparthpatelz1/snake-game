// lib/app/modules/game/views/game_over_menu.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/service/score_service.dart';
import '../../../routes/app_routes.dart';
import '../components/ui/menu_button.dart';
import 'game_screen.dart';

class GameOverMenu extends StatelessWidget {
  final SlitherGame game;
  final ScoreService _scoreService = ScoreService();

  GameOverMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final score = game.playerController.segmentCount.value;
    final highScore = _scoreService.getHighScore();
    final kills = game.playerController.kills.value;
    final highKills = _scoreService.getHighKills();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade700, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(fontSize: 24, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Score: $score',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              Text(
                'High Score: $highScore',
                style: const TextStyle(fontSize: 20, color: Colors.amber),
              ),
              const SizedBox(height: 4),
              Text(
                'Kills: $kills',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              Text(
                'High Kills: $highKills',
                style: const TextStyle(fontSize: 20, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              MenuButton(
                text: 'REPLAY',
                onPressed: () => Get.offAllNamed(Routes.GAME),
                gradientColors: const [Color(0xFF66BB6A), Color(0xFF00796B)],
              ),
              const SizedBox(height: 12),
              MenuButton(
                text: 'HOME',
                onPressed: () => Get.offAllNamed(Routes.HOME),
                gradientColors: const [Color(0xFFBDBDBD), Color(0xFF616161)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
