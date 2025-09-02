import 'dart:math';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newer_version_snake/modules/game/views/pause_menu.dart';
import 'package:newer_version_snake/modules/game/views/revive_overlay.dart';
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
import '../controllers/revive_controller.dart';
import 'game_over_menu.dart';

class SlitherGame extends FlameGame with DragCallbacks {
  final PlayerController playerController = Get.find<PlayerController>();

  late final World world;
  late final AiManager aiManager;
  late final PlayerComponent player;
  late final CameraComponent cameraComponent;
  late final AiPainter aiPainter;
  AiSnakeData? snakeThatKilledPlayer;

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

  @override
  Color backgroundColor() => Get.find<SettingsService>().backgroundColor;

  late final FoodManager foodManager;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // The game's canvas size is available here.
    // We calculate the visible world dimensions by dividing the canvas size by the zoom level.
    const zoom = 0.7;
    final visibleWidth = size.x / zoom;
    final visibleHeight = size.y / zoom;
    final screenDiagonal = sqrt(visibleWidth * visibleWidth + visibleHeight * visibleHeight);

    // Set spawn radius to be half the diagonal of the screen plus a 100px buffer
    final spawnRadius = (screenDiagonal / 2) + 100;
    // Set max distance to be larger, so food doesn't disappear at the edge of the screen
    final maxDistance = spawnRadius + 200;

    foodManager = FoodManager(
      worldBounds: worldBounds,
      spawnRadius: spawnRadius,
      maxDistance: maxDistance,
    );

    cameraComponent = CameraComponent()..debugMode = false;
    player = PlayerComponent(foodManager: foodManager)..position = Vector2.zero();
    aiManager = AiManager(foodManager: foodManager, player: player);

    final foodPainter = FoodPainter(
      foodManager: foodManager,
      cameraToFollow: cameraComponent,
    );
    aiPainter = AiPainter(
        aiManager: aiManager
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
    cameraComponent.viewfinder.zoom = zoom; // Apply the zoom level
    await add(cameraComponent);
    cameraComponent.follow(player);

    final halfViewportWidth = size.x / 2;
    final halfViewportHeight = size.y / 2;
    final cameraBounds = Rectangle.fromLTRB(
      worldBounds.left + halfViewportWidth,
      worldBounds.top + halfViewportHeight,
      worldBounds.right - halfViewportWidth,
      worldBounds.bottom - halfViewportHeight,
    );
    cameraComponent.setBounds(cameraBounds);

    final boostButton = BoostButton(position: Vector2(50, size.y - 120));
    final pauseButton = PauseButton(position: Vector2(size.x - 70, 50));
    final minimap = Minimap(player: player, aiManager: aiManager);
    cameraComponent.viewport.addAll([boostButton, pauseButton, minimap]);
  }

  void revivePlayer() {
    overlays.remove('revive');

    if (snakeThatKilledPlayer != null) {
      aiManager.killSnakeAndScatterFood(snakeThatKilledPlayer!);
      aiManager.spawnNewSnake();
      snakeThatKilledPlayer = null;
    }

    player.revive();
    playerController.hasUsedRevive.value = true;
    resumeEngine();
  }

  void handlePlayerDeath(AiSnakeData? killer) {
    pauseEngine();
    player.isDead = true;

    if (playerController.hasUsedRevive.value) {
      showGameOver();
    } else {
      snakeThatKilledPlayer = killer;
      overlays.add('revive');
    }
  }

  void showGameOver() {
    overlays.remove('revive');

    for (final segment in player.bodySegments) {
      foodManager.spawnFoodAt(segment.position);
    }
    player.removeFromParent();

    overlays.add('gameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

    foodManager.update(dt, player.position);

    if (joystick != null && joystick!.intensity > 0) {
      playerController.targetDirection = joystick!.delta.normalized();
    }

    _updateCount++;
    if (_updateCount % 3600 == 0) {
      print('Game update running. Update count: $_updateCount');
    }

    _checkCollisions();
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

    final visibleRect = cameraComponent.visibleWorldRect.inflate(300);
    final List<AiSnakeData> snakesToKill = [];

    int shown = 0;
    for (final snake in aiManager.snakes) {
      if (!visibleRect.overlaps(snake.boundingBox)) continue;

      if (shown < 3 && _frameCount % 60 == 0) {
        print(
          'AI Snake ${++shown} pos=(${snake.position.x.toStringAsFixed(1)}, ${snake.position.y.toStringAsFixed(1)}) '
              'rHead=${snake.headRadius}',
        );
      }

      final headToHeadDistance = playerHeadPos.distanceTo(snake.position);
      final requiredHeadDistance = playerHeadRadius + snake.headRadius;

      if (headToHeadDistance <= requiredHeadDistance) {
        if (playerHeadRadius > snake.headRadius) {
          print('Player wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          snakesToKill.add(snake);
        } else if (playerHeadRadius < snake.headRadius) {
          print('AI wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          handlePlayerDeath(snake);
          return;
        } else {
          print('Equal H2H — both die at r=$playerHeadRadius');
          snakesToKill.add(snake);
          handlePlayerDeath(snake);
          return;
        }
        continue;
      }

      for (int i = 0; i < snake.bodySegments.length; i++) {
        final seg = snake.bodySegments[i];
        final bodyDistance = playerHeadPos.distanceTo(seg);
        final requiredBodyDistance = playerHeadRadius + snake.bodyRadius;
        if (bodyDistance <= requiredBodyDistance) {
          print('Player head hit AI body[$i]: d=$bodyDistance <= $requiredBodyDistance');
          snakeThatKilledPlayer = snake;
          handlePlayerDeath(snake);
          return;
        }
      }

      for (int i = 0; i < player.bodySegments.length; i++) {
        final seg = player.bodySegments[i].position;
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
    final slitherGame = SlitherGame();

    return Scaffold(
      body: GameWidget(
        game: SlitherGame(),
        overlayBuilderMap: {
          'pauseMenu': (context, game) => PauseMenu(game: game as SlitherGame),
          'gameOver': (context, game) => GameOverMenu(game: game as SlitherGame, playerController: slitherGame.playerController,),
          'revive': (context, game) {
            Get.put(ReviveController(game: game as SlitherGame));
            return const ReviveOverlay();
          },
        },
      ),
    );
  }
}
