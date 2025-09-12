// lib/modules/game/home/home_screen.dart

import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:newer_version_snake/data/service/haptic_service.dart';
import 'package:newer_version_snake/data/service/score_service.dart';
import '../../../routes/app_routes.dart';
import '../components/world/image_background.dart';
import '../controllers/home_controller.dart';
import '../../../data/service/settings_service.dart';
import '../../../data/service/audio_service.dart';  // NEW: Import audio service
import '../controllers/player_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioService audioService = Get.find<AudioService>();  // NEW: Get audio service
    final HapticService hapticService = Get.find<HapticService>();
    final screenPadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Color(0xFF0E143F),
      body: Stack(
        children: [
          // Settings Icon (Top Left)
          Positioned(
            top: screenPadding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () {
                // NEW: Play button click sound
                audioService.playButtonClick();
                hapticService.buttonPress();
                controller.openSettings();
              },
              child: Image.asset('assets/images/Settings.png', width: 60),
            ),
          ),

          // Main UI Content (Centered)
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Image
                  Image.asset(
                    'assets/images/Title.png',
                    width: Get.width * 0.9,
                  ),
                  const SizedBox(height: 40),

                  // User Name Input Field with custom background
                  _buildUsernameInput(),
                  const SizedBox(height: 20),
                  _buildHighScore(),
                  const SizedBox(height: 20),

                  // Custom Image Button for "Snake Skins"
                  _buildImageButton(
                    onTap: () {
                      // NEW: Play button click sound
                      audioService.playButtonClick();
                      hapticService.buttonPress();
                      Get.toNamed(Routes.CUSTOMIZATION);
                    },
                    buttonImage: 'assets/images/Snake Skin Btn.png',
                    iconImage: 'assets/images/Snake Skin Icon.png',
                    text: 'Snake Skins',
                  ),
                  const SizedBox(height: 15),

                  // Custom Image Button for "Background Skins"
                  _buildImageButton(
                    onTap: () {
                      // NEW: Play button click sound
                      audioService.playButtonClick();
                      hapticService.buttonPress();
                      _showBackgroundPicker();
                    },
                    buttonImage: 'assets/images/Background Skin Btn.png',
                    iconImage: 'assets/images/Background Skin Icon.png',
                    text: 'Background Skins',
                  ),
                  const SizedBox(height: 40),

                  // "Tap to Play" Image Button
                  GestureDetector(
                    onTap: () {
                      // NEW: Play button click sound and switch to game music
                      audioService.playButtonClick();
                      hapticService.buttonPress();
                      audioService.playMusic('game');
                      Get.toNamed(Routes.GAME);
                    },
                    child: Image.asset(
                      'assets/images/Tap to Play.png',
                      width: Get.width * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the username input field
  Widget _buildUsernameInput() {
    return Container(
      width: 300,
      height: 65,
      padding: const EdgeInsets.only(left: 80,right:20),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/User Name.png'),
          fit: BoxFit.contain,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller.nicknameController,
        textAlign: TextAlign.start,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: const InputDecoration(
          hintText: 'User name',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildHighScore() {
    ScoreService scoreService = ScoreService();
    String highScore = scoreService.getHighScore().toString();
    String highKill = scoreService.getHighKills().toString();
    return Container(
      width: 340,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 🔥 High Score Box
          _buildStatCard(
            title: "HIGH SCORE:",
            value: highScore,
            gradientColors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            shadowColor: Colors.orangeAccent,
          ),

          // ⚡ High Kills Box
          _buildStatCard(
            title: "HIGH KILLS:",
            value: highKill,
            gradientColors: [Color(0xFF00CFFF), Color(0xFF0055FF)],
            shadowColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required List<Color> gradientColors,
    required Color shadowColor,
  }) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.5),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(width: 3, color: Colors.white),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
                Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable helper widget for creating buttons with images
  Widget _buildImageButton({
    required VoidCallback onTap,
    required String buttonImage,
    required String iconImage,
    required String text,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        height: 75,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(buttonImage),
            fit: BoxFit.fill,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconImage, height: 40),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black54,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20), // Added for better centering
          ],
        ),
      ),
    );
  }

  void _showBackgroundPicker() {
    final AudioService audioService = Get.find<AudioService>();  // NEW: Get audio service
    final settings = Get.find<SettingsService>();
    final List<Color> choices = [
      Colors.lightBlueAccent,
      Colors.black,
      Colors.white10,
      Colors.green.shade700,
      Colors.deepPurple.shade600,
      Colors.red.shade600,
      Colors.orange.shade700,
      Colors.blueGrey.shade800,
    ];
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Wrap(
          runSpacing: 12,
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final c in choices)
              GestureDetector(
                onTap: () {
                  // NEW: Play button click sound
                  audioService.playButtonClick();
                  settings.setBackgroundColor(c);
                  Get.back();
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}