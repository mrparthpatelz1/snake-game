// lib/app/modules/game/views/pause_menu.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../components/ui/menu_button.dart';
import 'game_screen.dart';

class PauseMenu extends StatelessWidget {
  final SlitherGame game;

  const PauseMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('PAUSED', style: TextStyle(fontSize: 24, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              MenuButton(
                text: 'RESUME',
                onPressed: () {
                  game.overlays.remove('pauseMenu');
                  game.resumeEngine();
                },
                gradientColors: const [Color(0xFFF9A825), Color(0xFFE65100)],
              ),
              const SizedBox(height: 12),
              MenuButton(
                text: 'REPLAY',
                onPressed: () {
                  Get.offAllNamed(Routes.GAME);
                },
                gradientColors: const [Color(0xFF66BB6A), Color(0xFF00796B)],
              ),
              const SizedBox(height: 12),
              MenuButton(
                text: 'HOME',
                onPressed: () {
                  Get.offAllNamed(Routes.HOME);
                },
                gradientColors: const [Color(0xFFBDBDBD), Color(0xFF616161)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- THIS IS THE FIX ---
// The constructor and properties for the button are now correctly restored.
// class _MenuButton extends StatelessWidget {
//   final String text;
//   final VoidCallback onPressed;
//   final List<Color> gradientColors;
//
//   const _MenuButton({
//     required this.text,
//     required this.onPressed,
//     required this.gradientColors,
//   });
// // --- END OF FIX ---
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(30),
//           border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
//           gradient: LinearGradient(
//             colors: gradientColors,
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.3),
//               blurRadius: 5,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 height: 25,
//                 decoration: BoxDecoration(
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(30),
//                     topRight: Radius.circular(30),
//                   ),
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.white.withValues(alpha: 0.3),
//                       Colors.white.withValues(alpha: 0.0),
//                     ],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                 ),
//               ),
//             ),
//             Text(
//               text,
//               style: const TextStyle(
//                 fontSize: 18,
//                 color: Colors.white,
//                 shadows: [
//                   Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.0, 1.0)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }