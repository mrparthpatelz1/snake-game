// lib/modules/game/views/game_screen.dart

import 'dart:math';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for haptics
import 'package:get/get.dart';
import 'package:newer_version_snake/modules/game/views/pause_menu.dart';
import 'package:newer_version_snake/modules/game/views/revive_overlay.dart';
import '../../../data/service/haptic_service.dart';
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
  final HapticService _hapticService = Get.find<HapticService>();


  late final World world;
  late final AiManager aiManager;
  late final PlayerComponent player;
  late final CameraComponent cameraComponent;
  late final AiPainter aiPainter;
  AiSnakeData? snakeThatKilledPlayer;
  bool _gameInitialized = false; // Track if game has been fully initialized

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

    const zoom = 0.6;
    final visibleWidth = size.x / zoom;
    final visibleHeight = size.y / zoom;
    final screenDiagonal = sqrt(visibleWidth * visibleWidth + visibleHeight * visibleHeight);

    final spawnRadius = (screenDiagonal / 2) + 100;
    final maxDistance = spawnRadius + 100;

    foodManager = FoodManager(
      worldBounds: worldBounds,
      spawnRadius: spawnRadius,
      maxDistance: maxDistance,
    );

    cameraComponent = CameraComponent()..debugMode = false;
    player = PlayerComponent(foodManager: foodManager)..position = Vector2.zero();

    // UPDATED: Initialize AI manager with reduced snake count (20 instead of 30)
    aiManager = AiManager(
      foodManager: foodManager,
      player: player,
      numberOfSnakes: 20, // Reduced from 30
    );

    final foodPainter = FoodPainter(
      foodManager: foodManager,
      cameraToFollow: cameraComponent,
    );
    aiPainter = AiPainter(aiManager: aiManager);

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
    cameraComponent.viewfinder.zoom = zoom;
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

    // Initialize food immediately after everything is set up
    _initializeFood();
  }

  void _initializeFood() {
    // Initialize food immediately when the game starts
    foodManager.initialize(player.position);
    _gameInitialized = true;
    print('Game initialized with food spawned at start');
  }

  void revivePlayer() {
    overlays.remove('revive');

    if (snakeThatKilledPlayer != null && !snakeThatKilledPlayer!.isDead) {
      // Kill the AI snake that killed the player with special revenge death
      print('Revive: Executing revenge kill on AI snake');

      // Use special revenge kill method for bonus food and effects
      aiManager.killSnakeAsRevenge(snakeThatKilledPlayer!);

      // Add bonus kills to player's score
      playerController.kills.value++;

      // Strong haptic feedback for revenge
      _hapticService.victory();

      // Spawn a replacement AI snake after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (aiManager.isMounted) {
          aiManager.spawnNewSnake();
          print('Revive: Spawned replacement AI snake');
        }
      });

      snakeThatKilledPlayer = null;
    }

    player.revive();
    playerController.hasUsedRevive.value = true;
    resumeEngine();

    // Optional: Show a message to the player
    print('🎮 PLAYER REVIVED! Revenge executed! 🎮');
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

    // Scatter food from player death using the new method
    foodManager.scatterFoodFromSnake(
        player.position,
        playerController.headRadius.value,
        player.bodySegments.length
    );

    player.removeFromParent();
    overlays.add('gameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Only update food and game logic after initialization
    if (_gameInitialized) {
      foodManager.update(dt, player.position);
    }

    if (joystick != null && joystick!.intensity > 0) {
      playerController.targetDirection = joystick!.delta.normalized();
    }

    _updateCount++;
    if (_updateCount % 3600 == 0) {
      final aiStats = 'AI: ${aiManager.aliveSnakeCount}/${aiManager.totalSnakeCount}';
      final foodStats = 'Food: ${foodManager.foodList.length}';
      print('Game update running. Update: $_updateCount | $aiStats | $foodStats');
    }

    // Enhanced collision detection - Player vs AI only
    // AI vs AI collisions are now handled in AiManager
    _checkPlayerVsAiCollisions();
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

  // IMPROVED: Optimized collision detection with haptic feedback
  void _checkPlayerVsAiCollisions() {
    _collisionCallCount++;

    if (!aiManager.isMounted) {
      if (_collisionCallCount % 120 == 0) {
        print('AiManager not mounted yet; skipping collisions.');
      }
      return;
    }

    if (player.isDead) return;

    final playerHeadPos = player.position;
    final playerHeadRadius = playerController.headRadius.value;
    final playerBodyRadius = playerController.bodyRadius.value;

    _frameCount++;
    if (_frameCount % 300 == 0) { // Reduced debug frequency
      print(
        'Player collision check: AI snakes=${aiManager.aliveSnakeCount} '
            'player=(${playerHeadPos.x.toStringAsFixed(0)}, ${playerHeadPos.y.toStringAsFixed(0)}) '
            'rHead=${playerHeadRadius.toStringAsFixed(1)}',
      );
    }

    // Only check visible AI snakes for performance
    final visibleRect = cameraComponent.visibleWorldRect.inflate(300);
    final List<AiSnakeData> snakesToKill = [];

    int checkedSnakes = 0;
    for (final snake in aiManager.snakes) {
      if (snake.isDead) continue;
      if (!visibleRect.overlaps(snake.boundingBox)) continue;

      checkedSnakes++;

      // Player head vs AI head collision
      final headToHeadDistance = playerHeadPos.distanceTo(snake.position);
      final requiredHeadDistance = playerHeadRadius + snake.headRadius;

      if (headToHeadDistance <= requiredHeadDistance) {
        if (playerHeadRadius > snake.headRadius + 1.0) {
          // Player wins - ADD HAPTIC FEEDBACK
          _hapticService.kill();
          print('Player wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          snakesToKill.add(snake);
          player.onAiSnakeKilled(); // Trigger haptic in player component
        } else if (playerHeadRadius < snake.headRadius - 1.0) {
          // AI wins - DEATH HAPTIC is handled in player.die()
          print('AI wins H2H: $playerHeadRadius vs ${snake.headRadius}');
          handlePlayerDeath(snake);
          return;
        } else {
          // Equal size - both die
          _hapticService.collision(); // Different haptic for mutual destruction
          print('Equal H2H — both die at r=$playerHeadRadius');
          snakesToKill.add(snake);
          handlePlayerDeath(snake);
          return;
        }
        continue;
      }

      // Player head vs AI body collision
      for (int i = 0; i < snake.bodySegments.length; i++) {
        final seg = snake.bodySegments[i];
        final bodyDistance = playerHeadPos.distanceTo(seg);
        final requiredBodyDistance = playerHeadRadius + snake.bodyRadius;

        if (bodyDistance <= requiredBodyDistance) {
          print('Player head hit AI body[$i]: d=${bodyDistance.toStringAsFixed(1)} <= ${requiredBodyDistance.toStringAsFixed(1)}');
          // DEATH HAPTIC is handled in player.die()
          handlePlayerDeath(snake);
          return;
        }
      }

      // AI head vs Player body collision
      for (int i = 0; i < player.bodySegments.length; i++) {
        final seg = player.bodySegments[i].position;
        final bodyDistance = snake.position.distanceTo(seg);
        final requiredBodyDistance = snake.headRadius + playerBodyRadius;

        if (bodyDistance <= requiredBodyDistance) {
          // Player wins - ADD HAPTIC FEEDBACK
          _hapticService.kill();
          print('AI head hit player body[$i]: d=${bodyDistance.toStringAsFixed(1)} <= ${requiredBodyDistance.toStringAsFixed(1)} (AI dies)');
          snakesToKill.add(snake);
          player.onAiSnakeKilled(); // Trigger haptic in player component
          break;
        }
      }
    }

    // Process killed snakes - now they die with animation
    for (final snake in snakesToKill) {
      playerController.kills.value++;
      snake.isDead = true; // This will trigger death animation in AiManager
      aiManager.spawnNewSnake(); // Spawn replacement
    }

    if (_frameCount % 300 == 0 && checkedSnakes > 0) {
      print('Checked $checkedSnakes visible AI snakes for player collisions');
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
        game: slitherGame,
        overlayBuilderMap: {
          'pauseMenu': (context, game) => PauseMenu(game: game as SlitherGame),
          'gameOver': (context, game) => GameOverMenu(
            game: game as SlitherGame,
            playerController: slitherGame.playerController,
          ),
          'revive': (context, game) {
            Get.put(ReviveController(game: game as SlitherGame));
            return const ReviveOverlay();
          },
        },
      ),
    );
  }
}