// lib/app/modules/game/views/pause_menu.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import 'game_screen.dart';

class PauseMenu extends StatelessWidget {
  final SlitherGame game;
  const PauseMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        body: Center(
          child: Container(
            width: 320,
            height: 200,
            decoration: BoxDecoration(
                // color: Colors.red,
                image: DecorationImage(
                    image: AssetImage(
                  'assets/images/Pause Popup_pause.png',
                ))),
            child: Column(
              children: [
                SizedBox(height: 33,),
                Text(
                  'PAUSE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ImageButton(
                      path: 'assets/images/Replay Btn_pause.png',
                      onTap: () => Get.offAllNamed(Routes.GAME),
                    ),
                    SizedBox(width: 10),
                    _ImageButton(
                      path: 'assets/images/Resume Btn_pause.png',
                      onTap: () {
                        game.overlays.remove('pauseMenu');
                        game.resumeEngine();
                      },
                    ),
                    SizedBox(width: 10),
                    _ImageButton(
                      path: 'assets/images/Home Btn_pause.png',
                      onTap: () => Get.offAllNamed(Routes.HOME),
                    ),
                  ],
                ),
              ],
            )
          ),
        ));
  }
}

class _ImageButton extends StatelessWidget {
  final String path;
  final VoidCallback onTap;

  const _ImageButton({
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Image.asset(
          path,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
