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
  @override
  late final World world;
  late final AiManager aiManager;
  late final PlayerComponent player;
  late final CameraComponent cameraComponent;

  JoystickComponent? joystick;

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
      for (var snake in aiManager.snakes) {
        snake.savePreviousPosition();
      }

      aiManager.update(_fixedStep); // Your AI logic update

      player.update(_fixedStep);
      foodManager.update(_fixedStep);

      _accumulator -= _fixedStep;

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
          paint: Paint()..color = Colors.white.withAlpha(128),
        ),
        background: CircleComponent(
          radius: 55,
          paint: Paint()..color = Colors.grey.withAlpha(77),
        ),
        position: event.canvasPosition,
      );
      cameraComponent.viewport.add(joystick!);
    }
    super.onDragStart(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    joystick?.removeFromParent();
    joystick = null;
    super.onDragEnd(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    joystick?.onDragUpdate(event);
    super.onDragUpdate(event);
  }

  void _checkCollisions() {
    // Early out if we somehow don’t have an AiManager (shouldn’t happen now).
    if (!aiManager.isMounted) {
      return;
    }

    final playerHeadPos = player.position;
    final playerHeadRadius = playerController.headRadius.value;
    final playerBodyRadius = playerController.bodyRadius.value;

    // Cull to only snakes close enough to matter.
    final visibleRect = cameraComponent.visibleWorldRect.inflate(300);

    final List<AiSnakeData> snakesToKill = [];

    for (final snake in aiManager.snakes) {
      // Skip far snakes fast using their bounding boxes.
      if (!visibleRect.overlaps(snake.boundingBox)) continue;

      // 1) Head-to-head
      final headToHeadDistance = playerHeadPos.distanceTo(snake.position);
      final requiredHeadDistance = playerHeadRadius + snake.headRadius;

      if (headToHeadDistance <= requiredHeadDistance) {
        if (playerHeadRadius > snake.headRadius) {
          snakesToKill.add(snake);
        } else if (playerHeadRadius < snake.headRadius) {
          player.die();
          return;
        } else {
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
