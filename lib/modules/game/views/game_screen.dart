// // lib/app/modules/game/views/game_screen.dart
//
// import 'package:flame/game.dart';
// import 'package:flame/components.dart';
// import 'package:flame/events.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../components/player/player_component.dart';
// import '../controllers/player_controller.dart';
//
// class SlitherGame extends FlameGame with DragCallbacks {
//   final PlayerController playerController = Get.find<PlayerController>();
//   JoystickComponent? joystick;
//
//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();
//     final player = PlayerComponent();
//     add(player);
//
//     // This is the standard and most reliable way to make the camera follow.
//     camera.follow(player);
//   }
//
//   @override
//   void update(double dt) {
//     super.update(dt);
//     // On every frame, check if the joystick exists and is being used.
//     if (joystick != null && joystick!.intensity > 0) {
//       // If so, update the player's direction using the joystick's `delta`.
//       playerController.targetDirection = joystick!.delta.normalized();
//     }
//   }
//
//   @override
//   void onDragStart(DragStartEvent event) {
//     if (joystick == null) {
//       joystick = JoystickComponent(
//         knob: CircleComponent(
//           radius: 25,
//           paint: Paint()..color = Colors.white.withValues(alpha: 0.5),
//         ),
//         background: CircleComponent(
//           radius: 70,
//           paint: Paint()..color = Colors.grey.withValues(alpha: 0.3),
//         ),
//         position: event.canvasPosition,
//       );
//       camera.viewport.add(joystick!);
//     }
//     super.onDragStart(event);
//   }
//
//   @override
//   void onDragEnd(DragEndEvent event) {
//     if (joystick != null) {
//       joystick!.removeFromParent();
//       joystick = null;
//     }
//     super.onDragEnd(event);
//   }
//
//   @override
//   void onDragUpdate(DragUpdateEvent event) {
//     joystick?.onDragUpdate(event);
//     super.onDragUpdate(event);
//   }
// }
//
// // The GameScreen widget remains unchanged.
// class GameScreen extends StatelessWidget {
//   const GameScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GameWidget(
//         game: SlitherGame(),
//       ),
//     );
//   }
// }

// lib/app/modules/game/views/game_screen.dart

// lib/app/modules/game/views/game_screen.dart

import 'dart:math';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newer_version_snake/modules/game/views/pause_menu.dart';
import '../../../data/service/settings_service.dart';
import '../components/ai/ai_manager.dart';
import '../components/ai/ai_painter.dart';
import '../components/ai/ai_snake_data.dart';
import '../components/food/food_painter.dart';
import '../components/player/player_component.dart';
import '../components/ui/boost_button.dart';
import '../components/ui/mini_map.dart';
import '../components/ui/pause_button.dart';
import '../components/world/image_background.dart';
import '../controllers/player_controller.dart';
import '../components/food/food_manager.dart';
import 'game_over_menu.dart';

class SlitherGame extends FlameGame with DragCallbacks {
  final PlayerController playerController = Get.find<PlayerController>();
  JoystickComponent? joystick;
  late final PlayerComponent player;
  late final CameraComponent cameraComponent;
  static int _frameCount = 0;
  static int _collisionCallCount = 0;
  static int _updateCount = 0;

  static final worldBounds = Rect.fromLTRB(-10800, -10800, 10800, 10800);

  static const double padding = 20.0;
  static final playArea = Rect.fromLTRB(
    worldBounds.left + padding,
    worldBounds.top + padding,
    worldBounds.right - padding,
    worldBounds.bottom - padding,
  );

  @override
  Color backgroundColor() {
    // Background color is configurable in settings; default matches previous color
    return Get.find<SettingsService>().backgroundColor;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final foodManager = FoodManager();

    player = PlayerComponent(foodManager: foodManager);
    player.position = Vector2.zero();

    final aiManager = AiManager(foodManager: foodManager, player: player);

    cameraComponent = CameraComponent()..debugMode = true;

    final foodPainter = FoodPainter(
      foodManager: foodManager,
      cameraToFollow: cameraComponent,
    );
    final aiPainter = AiPainter(
      aiManager: aiManager,
      cameraToFollow: cameraComponent,
    );

    final world = World(
      children: [
        TileBackground(cameraToFollow: cameraComponent),
        foodPainter,
        aiPainter,
        aiManager,
        player,
      ],
    )..debugMode = true;
    await add(world);

    cameraComponent.world = world;
    await add(cameraComponent);
    cameraComponent.follow(player);

    // --- THIS IS THE DEFINITIVE FIX ---
    // 1. Calculate half of the screen's width and height.
    final halfViewportWidth = size.x / 2;
    final halfViewportHeight = size.y / 2;

    // 2. Create a new, smaller rectangle for the camera's bounds.
    final cameraBounds = Rectangle.fromLTRB(
      worldBounds.left + halfViewportWidth,
      worldBounds.top + halfViewportHeight,
      worldBounds.right - halfViewportWidth,
      worldBounds.bottom - halfViewportHeight,
    );

    // 3. Set the camera's bounds to this new, smaller rectangle.
    cameraComponent.setBounds(cameraBounds);
    // --- END OF FIX ---

    // --- ADD THE BOOST BUTTON ---
    // We add the button to the camera's viewport so it stays fixed on the screen.
    final boostButton = BoostButton(
      position: Vector2(50, size.y - 120), // Positioned in the bottom right
    );
    cameraComponent.viewport.add(boostButton);

    // --- ADD THE PAUSE BUTTON ---
    final pauseButton = PauseButton(
      position: Vector2(size.x - 70, 50), // Positioned in the top right
    );
    cameraComponent.viewport.add(pauseButton);

    // --- ADD THE MINIMAP ---
    final minimap = Minimap(player: player, aiManager: aiManager);
    cameraComponent.viewport.addAll([boostButton, minimap]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // If joystick is active, steer toward its delta like virtual stick
    if (joystick != null && joystick!.intensity > 0) {
      playerController.targetDirection = joystick!.delta.normalized();
    }

    // Debug: Check if update is running
    _updateCount++;
    if (_updateCount % 3600 == 0) {
      // Every 60 seconds at 60fps
      print('Game update running. Update count: $_updateCount');
    }

    _checkCollisions();
  }

  @override
  void onDragStart(DragStartEvent event) {
    // Slither-like movement: virtual joystick for continuous steering
    // Optional visual joystick for user feedback
    if (joystick == null) {
      joystick = JoystickComponent(
        knob: CircleComponent(
          radius: 20,
          paint: Paint()..color = Colors.white.withOpacity(0.5),
        ),
        background: CircleComponent(
          radius: 55,
          paint: Paint()..color = Colors.grey.withOpacity(0.3),
        ),
        position: event.canvasPosition,
      );
      cameraComponent.viewport.add(joystick!);
    }
    super.onDragStart(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (joystick != null) {
      joystick!.removeFromParent();
      joystick = null;
    }
    super.onDragEnd(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Visual joystick feedback continues to move with drag
    joystick?.onDragUpdate(event);
    super.onDragUpdate(event);
  }

  void _checkCollisions() {
    // Debug: Check if method is being called
    _collisionCallCount++;
    if (_collisionCallCount % 120 == 0) {
      // Every 2 seconds at 60fps
      print('_checkCollisions called $_collisionCallCount times');
    }

    // Player head vs AI body segments; AI head vs player body segments
    final aiManagers = children.query<AiManager>();
    if (aiManagers.isEmpty) {
      print('No AI Manager found! Collision detection skipped.');
      return; // Safety check: no AI manager yet
    }
    final aiManager = aiManagers.first;

    final playerHeadPos = player.position;
    final playerHeadRadius = playerController.headRadius.value;
    final playerBodyRadius = playerController.bodyRadius.value;

    // Debug: Check if collision detection is being called
    _frameCount++;
    if (_frameCount % 60 == 0) {
      print('Collision check running. AI snakes: ${aiManager.snakes.length}');
      print(
        'Player position: ${playerHeadPos.x.toStringAsFixed(1)}, ${playerHeadPos.y.toStringAsFixed(1)}',
      );
      print('Player radius: $playerHeadRadius');
    }

    // Precompute bounding rect to skip distant snakes
    final visibleRect = cameraComponent.visibleWorldRect.inflate(200);

    // Create a list to track snakes to remove (to avoid concurrent modification)
    final List<AiSnakeData> snakesToKill = [];

    int checkedSnakes = 0;
    for (final snake in aiManager.snakes) {
      checkedSnakes++;

      // Debug: Show first few AI snake positions
      if (checkedSnakes <= 3 && _frameCount % 60 == 0) {
        print(
          'AI Snake $checkedSnakes - Position: ${snake.position.x.toStringAsFixed(1)}, ${snake.position.y.toStringAsFixed(1)}, Radius: ${snake.headRadius}',
        );
      }

      // 1) HEAD-TO-HEAD COLLISION: Check if player head hits AI head
      final double headToHeadDistance = playerHeadPos.distanceTo(
        snake.position,
      );
      final double requiredHeadDistance = playerHeadRadius + snake.headRadius;

      if (headToHeadDistance <= requiredHeadDistance) {
        // Head-to-head collision - larger radius wins
        if (playerHeadRadius > snake.headRadius) {
          // Player wins - kill the AI snake
          print(
            'Player wins head-to-head! Player radius: $playerHeadRadius, AI radius: ${snake.headRadius}',
          );
          snakesToKill.add(snake);
        } else if (playerHeadRadius < snake.headRadius) {
          // AI wins - player dies
          print(
            'AI wins head-to-head! Player radius: $playerHeadRadius, AI radius: ${snake.headRadius}',
          );
          player.die();
          return;
        } else {
          // Equal radius - both die (or you could make it random)
          print(
            'Equal head-to-head collision! Both die. Radius: $playerHeadRadius',
          );
          snakesToKill.add(snake);
          player.die();
          return;
        }
        continue; // Skip body collision checks for this snake
      }

      // 2) HEAD-TO-BODY COLLISION: Player head vs AI body segments
      // Check collision with AI snake body segments
      for (int i = 0; i < snake.bodySegments.length; i++) {
        final seg = snake.bodySegments[i];
        final bodyDistance = playerHeadPos.distanceTo(seg);
        final requiredBodyDistance = playerHeadRadius + snake.bodyRadius;

        if (bodyDistance <= requiredBodyDistance) {
          print(
            'Player head hit AI body segment $i! Distance: $bodyDistance, Required: $requiredBodyDistance',
          );
          print(
            'Player radius: $playerHeadRadius, AI body radius: ${snake.bodyRadius}',
          );
          player.die();
          return;
        }
      }

      // 3) HEAD-TO-BODY COLLISION: AI head vs player body segments
      for (int i = 0; i < player.bodySegments.length; i++) {
        final seg = player.bodySegments[i];
        final bodyDistance = snake.position.distanceTo(seg);
        final requiredBodyDistance = snake.headRadius + playerBodyRadius;

        if (bodyDistance <= requiredBodyDistance) {
          // AI head hit player body - AI dies
          print(
            'AI head hit player body segment $i! AI dies. Distance: $bodyDistance, Required: $requiredBodyDistance',
          );
          snakesToKill.add(snake);
          break;
        }
      }
    }

    // Kill marked snakes and award kills
    for (final snake in snakesToKill) {
      playerController.kills.value++;
      aiManager.killSnakeAndScatterFood(snake);
      // Spawn a new snake to maintain population
      aiManager.spawnNewSnake();
    }
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: SlitherGame(),
        overlayBuilderMap: {
          'pauseMenu': (context, game) {
            return PauseMenu(game: game as SlitherGame);
          },
          'gameOver': (context, game) =>
              GameOverMenu(game: game as SlitherGame),
        },
      ),
    );
  }
}
