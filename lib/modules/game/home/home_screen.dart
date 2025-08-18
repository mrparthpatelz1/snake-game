// lib/app/modules/home/views/home_screen.dart

import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../components/world/image_background.dart';
import '../controllers/home_controller.dart';
import '../../../data/service/settings_service.dart';

// --- THIS IS THE FIX ---
// The BackgroundGame class is now correctly defined at the top level of the file,
// outside of the HomeScreen widget class.
class BackgroundGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // We need a camera to pass to the background.
    final cameraComponent = CameraComponent(world: world);
    await addAll([world, cameraComponent]);
    world.add(TileBackground(cameraToFollow: cameraComponent));
  }
}
// --- END OF FIX ---

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The GameWidget will now be able to find and render our BackgroundGame.
          Positioned.fill(child: GameWidget(game: BackgroundGame())),
          // The rest of the UI remains the same.
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Slither.io Clone',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  Obx(
                    () => Text(
                      'High Score: ${controller.highScore.value}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: controller.nicknameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: 'Enter your nickname',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _showSkinPicker,
                      child: const Text('CHANGE SKIN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _showBackgroundPicker,
                      child: const Text('CHANGE BACKGROUND'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        Get.toNamed(Routes.GAME);
                      },
                      child: const Text(
                        'PLAY',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  void _showSkinPicker() {
    final settings = Get.find<SettingsService>();
    final skins = settings.allSkins;
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
          children: [
            for (int i = 0; i < skins.length; i++)
              GestureDetector(
                onTap: () {
                  settings.setSelectedSkinIndex(i);
                  Get.back();
                },
                child: Container(
                  width: 140,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                    gradient: LinearGradient(colors: skins[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBackgroundPicker() {
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
          children: [
            for (final c in choices)
              GestureDetector(
                onTap: () {
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
