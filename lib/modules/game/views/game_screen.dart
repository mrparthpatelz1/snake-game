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
import '../components/ai/ai_snake_data.dart';
import '../components/ai/ai_painter.dart';
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

  // Keep explicit references so we don’t rely on querying root children.
  late final World world;
  late final AiManager aiManager;
  late final PlayerComponent player;
  late final CameraComponent cameraComponent;

  JoystickComponent? joystick;
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

  double _accumulator = 0.0;
  static const double _fixedStep = 1 / 40; // 30 updates per second

  late AiPainter aiPainter;
  late FoodPainter foodPainter;
    final foodManager = FoodManager();

  @override
  Color backgroundColor() => Get.find<SettingsService>().backgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();


    player = PlayerComponent(foodManager: foodManager)..position = Vector2.zero();

    aiManager = AiManager(foodManager: foodManager, player: player);

    cameraComponent = CameraComponent()
      ..debugMode = false;

    final foodPainter = FoodPainter(
      foodManager: foodManager,
      cameraToFollow: cameraComponent,
    );
    final aiPainter = AiPainter(
      aiManager: aiManager,
      cameraToFollow: cameraComponent,
    );

    world = World(
      children: [
        TileBackground(cameraToFollow: cameraComponent),
        foodPainter,
        aiPainter,
        aiManager,
        player,
      ],
    )..debugMode = false;

    await add(world);

    cameraComponent.world = world;
    await add(cameraComponent);
    cameraComponent.follow(player);

    // Bound the camera to avoid showing beyond world edges.
    final halfViewportWidth = size.x / 2;
    final halfViewportHeight = size.y / 2;
    final cameraBounds = Rectangle.fromLTRB(
      worldBounds.left + halfViewportWidth,
      worldBounds.top + halfViewportHeight,
      worldBounds.right - halfViewportWidth,
      worldBounds.bottom - halfViewportHeight,
    );
    cameraComponent.setBounds(cameraBounds);

    // UI overlays anchored to viewport.
    final boostButton = BoostButton(position: Vector2(50, size.y - 120));
    final pauseButton = PauseButton(position: Vector2(size.x - 70, 50));
    final minimap = Minimap(player: player, aiManager: aiManager);
    cameraComponent.viewport.addAll([boostButton, pauseButton, minimap]);
  }

  @override
  void update(double dt) {
    super.update(dt);


    _accumulator += dt;

    while (_accumulator >= _fixedStep) {
    if (joystick != null && joystick!.intensity > 0) {
      playerController.targetDirection = joystick!.delta.normalized();
    }
      // Logic update tick
      aiManager.snakes.forEach((snake) => snake.savePreviousPosition());

      aiManager.update(_fixedStep); // Your AI logic update

      player.update(_fixedStep);
      foodManager.update(_fixedStep);

      _accumulator -= _fixedStep;

      _updateCount++;
      if (_updateCount % 3600 == 0) {
        print('Game update running. Update count: $_updateCount');
      }

      _checkCollisions();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final alpha = _accumulator / _fixedStep;

    // Pass interpolation alpha to painters for smooth rendering
    aiPainter.renderWithAlpha(canvas, alpha);
    foodPainter.renderWithAlpha(canvas, alpha);
    player.renderWithAlpha(canvas, alpha);
  }

  @override
  void onDragStart(DragStartEvent event) {
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
    joystick?..removeFromParent();
    joystick = null;
    super.onDragEnd(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    joystick?.onDragUpdate(event);
    super.onDragUpdate(event);
  }

  void _checkCollisions() {
    _collisionCallCount++;
    if (_collisionCallCount % 120 == 0) {
      print('_checkCollisions called $_collisionCallCount times');
    }

    // Early out if we somehow don’t have an AiManager (shouldn’t happen now).
    if (!aiManager.isMounted) {
      print('AiManager not mounted yet; skipping collisions.');
      return;
    }

    final playerHeadPos = player.position;
    final playerHeadRadius = playerController.headRadius.value;
    final playerBodyRadius = playerController.bodyRadius.value;

    _frameCount++;
    if (_frameCount % 60 == 0) {
      print(
        'Collision check: snakes=${aiManager.snakes.length} '
            'player=(${playerHeadPos.x.toStringAsFixed(1)}, ${playerHeadPos.y.toStringAsFixed(1)}) '
            'rHead=$playerHeadRadius',
      );
    }

    // Cull to only snakes close enough to matter.
    final visibleRect = cameraComponent.visibleWorldRect.inflate(300);

    final List<AiSnakeData> snakesToKill = [];

    int shown = 0;
    for (final snake in aiManager.snakes) {
      // Skip far snakes fast using their bounding boxes.
      if (!visibleRect.overlaps(snake.boundingBox)) continue;

      if (shown < 3 && _frameCount % 60 == 0) {
        print(
          'AI Snake ${++shown} pos=(${snake.position.x.toStringAsFixed(1)}, ${snake.position.y.toStringAsFixed(1)}) '
              'rHead=${snake.headRadius}',
        );
      }

      // 1) Head-to-head
      final headToHeadDistance = playerHeadPos.distanceTo(snake.position);
      final requiredHeadDistance = playerHeadRadius + snake.headRadius;

      if (headToHeadDistance <= requiredHeadDistance) {
        if (playerHeadRadius > snake.headRadius) {
          print('Player wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          snakesToKill.add(snake);
        } else if (playerHeadRadius < snake.headRadius) {
          print('AI wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          player.die();
          return;
        } else {
          print('Equal H2H — both die at r=$playerHeadRadius');
          snakesToKill.add(snake);
          player.die();
          return;
        }
        continue;
      }

      // 2) Player head vs AI body
      for (int i = 0; i < snake.bodySegments.length; i++) {
        final seg = snake.bodySegments[i];
        final bodyDistance = playerHeadPos.distanceTo(seg);
        final requiredBodyDistance = playerHeadRadius + snake.bodyRadius;
        if (bodyDistance <= requiredBodyDistance) {
          print('Player head hit AI body[$i]: d=$bodyDistance <= $requiredBodyDistance');
          player.die();
          return;
        }
      }

      // 3) AI head vs player body
      for (int i = 0; i < player.bodySegments.length; i++) {
        final seg = player.bodySegments[i];
        final bodyDistance = snake.position.distanceTo(seg);
        final requiredBodyDistance = snake.headRadius + playerBodyRadius;
        if (bodyDistance <= requiredBodyDistance) {
          print('AI head hit player body[$i]: d=$bodyDistance <= $requiredBodyDistance (AI dies)');
          snakesToKill.add(snake);
          break;
        }
      }
    }

    for (final snake in snakesToKill) {
      playerController.kills.value++;
      aiManager.killSnakeAndScatterFood(snake);
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
          'pauseMenu': (context, game) => PauseMenu(game: game as SlitherGame),
          'gameOver': (context, game) => GameOverMenu(game: game as SlitherGame),
        },
      ),
    );
  }
}
