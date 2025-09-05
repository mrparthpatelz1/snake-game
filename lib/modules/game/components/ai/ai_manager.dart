// lib/modules/game/components/ai/ai_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/service/settings_service.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';
import 'ai_snake_data.dart';

class AiManager extends Component with HasGameReference<SlitherGame> {
  final Random _random = Random();
  final FoodManager foodManager;
  final PlayerComponent player;
  final SettingsService _settingsService = Get.find<SettingsService>();

  final int numberOfSnakes;
  final List<AiSnakeData> snakes = [];
  final List<AiSnakeData> _dyingSnakes = []; // Track snakes that are dying

  late final List<Rect> _spawnZones;
  int _nextZoneIndex = 0;
  int _nextId = 0;

  // Performance optimization counters
  int _frameCount = 0;
  int _cleanupCounter = 0;
  static const int CLEANUP_INTERVAL = 120; // Clean up every 2 seconds at 60fps
  static const double MAX_DISTANCE_FROM_PLAYER = 1000.0; // Remove snakes beyond this distance

  AiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 20, // Reduced from 30 to 20
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _initializeSpawnZones();
    _spawnAllSnakes();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _frameCount++;

    final visibleRect = game.cameraComponent.visibleWorldRect.inflate(400);
    int activeCount = 0;
    int passiveCount = 0;

    // Update all alive snakes
    for (final snake in snakes) {
      if (snake.isDead) continue;

      _updateSnakeMovement(snake, dt);

      final isNearPlayer = _isNearPlayer(snake, 600);
      final onScreen = visibleRect.overlaps(snake.boundingBox);

      if (onScreen || isNearPlayer) {
        _updateActiveSnake(snake, dt);
        activeCount++;
      } else {
        _lightPassiveUpdate(snake, dt);
        passiveCount++;
      }
    }

    // Update dying snakes (death animation)
    _updateDyingSnakes(dt);

    // FIXED: More thorough AI vs AI collision detection every frame
    _checkAiVsAiCollisionsImproved(visibleRect);

    // Process newly dead snakes
    final newlyDead = snakes.where((s) => s.isDead && !_dyingSnakes.contains(s)).toList();
    for (final snake in newlyDead) {
      _startDeathAnimation(snake);
    }

    // Periodic cleanup and maintenance
    _cleanupCounter++;
    if (_cleanupCounter >= CLEANUP_INTERVAL) {
      _cleanupCounter = 0;
      _performPeriodicCleanup();
    }

    // Ensure minimum snakes around player
    _ensureMinSnakesAroundPlayer();

    if (_frameCount % 180 == 0) { // Debug every 3 seconds
      debugPrint(
        "AI Stats - Active: $activeCount | Passive: $passiveCount | Total: ${snakes.length} | Dying: ${_dyingSnakes.length}",
      );
    }
  }

  void _startDeathAnimation(AiSnakeData snake) {
    print('Starting death animation for snake with ${snake.segmentCount} segments and radius ${snake.headRadius}');

    // Add to dying snakes list
    _dyingSnakes.add(snake);

    // Set death animation properties
    snake.deathAnimationTimer = AiSnakeData.deathAnimationDuration;
    snake.originalScale = 1.0;

    // Scatter food using improved method
    foodManager.scatterFoodFromAiSnakeSlitherStyle(
        snake.position,
        snake.headRadius,
        snake.segmentCount,
        snake.bodySegments
    );

    // Additional visual feedback
    print('Snake death: scattering food along body path at position (${snake.position.x.toStringAsFixed(1)}, ${snake.position.y.toStringAsFixed(1)})');
  }

  void _updateDyingSnakes(double dt) {
    final List<AiSnakeData> toRemove = [];

    for (final snake in _dyingSnakes) {
      snake.deathAnimationTimer -= dt;

      // Update death animation scale (shrink over time)
      final progress = 1.0 - (snake.deathAnimationTimer / AiSnakeData.deathAnimationDuration);
      snake.scale = (1.0 - progress).clamp(0.0, 1.0);

      // Also fade out
      snake.opacity = snake.scale;

      if (snake.deathAnimationTimer <= 0) {
        toRemove.add(snake);
      }
    }

    // Remove finished death animations
    for (final snake in toRemove) {
      _dyingSnakes.remove(snake);
      snakes.remove(snake);
      print('Death animation completed, snake removed');
    }
  }

  // FIXED: Improved AI vs AI collision detection - more thorough
  void _checkAiVsAiCollisionsImproved(Rect visibleRect) {
    final visibleSnakes = snakes.where((s) =>
    !s.isDead && visibleRect.overlaps(s.boundingBox)).toList();

    for (int i = 0; i < visibleSnakes.length; i++) {
      final snake1 = visibleSnakes[i];
      if (snake1.isDead) continue;

      for (int j = i + 1; j < visibleSnakes.length; j++) {
        final snake2 = visibleSnakes[j];
        if (snake2.isDead) continue;

        // Check all possible collisions thoroughly
        _checkCollisionBetweenAiSnakesImproved(snake1, snake2);
      }
    }
  }

  // FIXED: More thorough collision detection
  void _checkCollisionBetweenAiSnakesImproved(AiSnakeData snake1, AiSnakeData snake2) {
    // Head vs Head collision
    final headDistance = snake1.position.distanceTo(snake2.position);
    final requiredHeadDistance = snake1.headRadius + snake2.headRadius;

    if (headDistance <= requiredHeadDistance) {
      if (snake1.headRadius > snake2.headRadius + 2.0) {
        // Snake1 wins
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 4);
      } else if (snake2.headRadius > snake1.headRadius + 2.0) {
        // Snake2 wins
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 4);
      } else {
        // Push snakes apart instead of both dying
        final pushDirection = (snake1.position - snake2.position).normalized();
        snake1.position += pushDirection * 15;
        snake2.position -= pushDirection * 15;
      }
      return;
    }

    // FIXED: More thorough body collision detection
    // Snake1 head vs Snake2 body - check ALL segments
    for (int i = 0; i < snake2.bodySegments.length; i++) {
      final segment = snake2.bodySegments[i];
      final distance = snake1.position.distanceTo(segment);
      final requiredDistance = snake1.headRadius + snake2.bodyRadius + 1.0; // Small buffer

      if (distance <= requiredDistance) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, (snake2.segmentCount ~/ 5) + 2);
        return;
      }
    }

    // Snake2 head vs Snake1 body - check ALL segments
    for (int i = 0; i < snake1.bodySegments.length; i++) {
      final segment = snake1.bodySegments[i];
      final distance = snake2.position.distanceTo(segment);
      final requiredDistance = snake2.headRadius + snake1.bodyRadius + 1.0; // Small buffer

      if (distance <= requiredDistance) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, (snake1.segmentCount ~/ 5) + 2);
        return;
      }
    }

    // ADDITIONAL: Body vs Body collision check (prevent snakes passing through each other)
    for (int i = 0; i < snake1.bodySegments.length; i += 2) { // Check every 2nd segment for performance
      final seg1 = snake1.bodySegments[i];
      for (int j = 0; j < snake2.bodySegments.length; j += 2) {
        final seg2 = snake2.bodySegments[j];
        final distance = seg1.distanceTo(seg2);
        final requiredDistance = snake1.bodyRadius + snake2.bodyRadius + 3.0; // Larger buffer for body

        if (distance <= requiredDistance) {
          // Push segments apart to prevent overlap
          final pushDirection = (seg1 - seg2).normalized();
          if (pushDirection.length2 > 0) {
            final pushAmount = (requiredDistance - distance) * 0.5;
            seg1.add(pushDirection * pushAmount);
            seg2.add(pushDirection * -pushAmount);
          }
        }
      }
    }
  }

  // Periodic cleanup for performance optimization
  void _performPeriodicCleanup() {
    final playerPos = player.position;
    int removedCount = 0;

    // Remove snakes that are too far from player
    snakes.removeWhere((snake) {
      if (snake.isDead) return false; // Dead snakes are handled separately

      final distance = snake.position.distanceTo(playerPos);
      if (distance > MAX_DISTANCE_FROM_PLAYER) {
        removedCount++;
        return true;
      }
      return false;
    });

    if (removedCount > 0) {
      debugPrint("Cleaned up $removedCount distant AI snakes for performance");
    }

    // More conservative garbage collection
    if (snakes.length > 35) {
      final excess = snakes.length - 30;
      final toRemove = snakes
          .where((s) => !s.isDead)
          .where((s) => s.position.distanceTo(playerPos) > 1000)
          .take(excess)
          .toList();

      for (final snake in toRemove) {
        snakes.remove(snake);
      }

      if (toRemove.isNotEmpty) {
        debugPrint("Removed ${toRemove.length} excess AI snakes");
      }
    }
  }

  void _updateSnakeMovement(AiSnakeData snake, double dt) {
    final moveSpeed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;
    final moveDir = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position += moveDir * moveSpeed * dt;

    snake.bodySegments.insert(0, snake.position.clone());

    while (snake.bodySegments.length > snake.segmentCount) {
      snake.bodySegments.removeLast();
    }

    snake.rebuildBoundingBox();
  }

  void _initializeSpawnZones() {
    const m = 300.0;
    final b = SlitherGame.worldBounds.deflate(m);
    final grid = (sqrt(numberOfSnakes)).ceil().clamp(1, 10);
    final w = b.width / grid, h = b.height / grid;

    _spawnZones = List.generate(grid * grid, (i) {
      final r = i ~/ grid, c = i % grid;
      return Rect.fromLTWH(b.left + c * w, b.top + r * h, w, h);
    })..shuffle(_random);
  }

  void _spawnAllSnakes() {
    for (int i = 0; i < numberOfSnakes; i++) {
      _spawnSnake();
    }
  }

  void _spawnSnake() {
    if (_spawnZones.isEmpty) return;

    final zone = _spawnZones[_nextZoneIndex++ % _spawnZones.length];
    final x = zone.left + _random.nextDouble() * zone.width;
    final y = zone.top + _random.nextDouble() * zone.height;
    final pos = Vector2(x, y);
    _spawnSnakeAt(pos);
  }

  void _spawnSnakeAt(Vector2 pos) async {
    final initCount = 12 + _random.nextInt(18);
    final baseSpeed = 60.0 + _random.nextDouble() * 25.0;

    // Use random player skins for AI snakes
    final randomSkin = _getRandomPlayerSkin();

    // Use random head images for AI snakes
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    final snake = AiSnakeData(
        position: pos,
        skinColors: randomSkin,
        targetDirection: Vector2.random(_random).normalized(),
        segmentCount: initCount,
        segmentSpacing: 13.0 * 0.6,
        baseSpeed: 60,
        boostSpeed: 130,
        minRadius: 12.0,
        maxRadius: 40.0,
        headSprite: headSprite
    );

    final bonus = (initCount / 25).floor().toDouble();
    snake.headRadius = (12.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;

    snake.bodySegments.clear();
    snake.path.clear();
    for (int i = 0; i < initCount; i++) {
      final offset = snake.targetDirection * snake.segmentSpacing * (i + 1);
      final p = pos - offset;
      snake.bodySegments.add(p.clone());
      snake.path.add(p.clone());
    }

    snake.aiState = AiState.wandering;
    snakes.add(snake);
    _updateBoundingBox(snake);
  }

  // Get random player skin for AI snakes
  List<Color> _getRandomPlayerSkin() {
    final allSkins = _settingsService.allSkins;
    if (allSkins.isEmpty) {
      return _getBasicRandomSkin();
    }

    final randomSkinIndex = _random.nextInt(allSkins.length);
    return List<Color>.from(allSkins[randomSkinIndex]);
  }

  List<Color> _getBasicRandomSkin() {
    final baseHue = _random.nextDouble() * 360;
    return List.generate(6, (i) {
      final h = (baseHue + i * 15) % 360;
      return HSVColor.fromAHSV(1, h, 0.8, 0.9).toColor();
    });
  }

  // Enhanced spawning to ensure snakes spawn outside visible area
  void _ensureMinSnakesAroundPlayer() {
    const minActive = 12;
    const maxActive = 20;
    const spawnRadius = 900.0;
    const safeZone = 420.0;
    const offscreenMargin = 150.0;

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius).length;

    if (near >= minActive && near <= maxActive) return;

    if (near < minActive) {
      final need = (minActive - near).clamp(0, 3);
      final visible = game.cameraComponent.visibleWorldRect.inflate(-offscreenMargin);

      for (int i = 0; i < need; i++) {
        Vector2? spawnPos = _findOffscreenSpawnPosition(safeZone, spawnRadius, visible);

        if (spawnPos != null) {
          _spawnSnakeAt(spawnPos);
          print('Spawned AI snake at offscreen position: (${spawnPos.x.toStringAsFixed(0)}, ${spawnPos.y.toStringAsFixed(0)})');
        }
      }
    }
  }

  // Find a spawn position that's outside the visible area
  Vector2? _findOffscreenSpawnPosition(double safeZone, double spawnRadius, Rect visibleArea) {
    const maxAttempts = 10;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final ang = _random.nextDouble() * pi * 2;
      final dist = safeZone + _random.nextDouble() * (spawnRadius - safeZone);
      final spawnPos = player.position + Vector2(cos(ang), sin(ang)) * dist;

      if (!visibleArea.contains(spawnPos.toOffset()) &&
          SlitherGame.worldBounds.contains(spawnPos.toOffset())) {
        return spawnPos;
      }
    }

    // Fallback: spawn at edge of visible area
    final edgeAngles = [0, pi/2, pi, 3*pi/2];
    final edgeAngle = edgeAngles[_random.nextInt(edgeAngles.length)];
    final edgeDistance = spawnRadius * 0.8;
    final fallbackPos = player.position + Vector2(cos(edgeAngle), sin(edgeAngle)) * edgeDistance;

    fallbackPos.x = fallbackPos.x.clamp(SlitherGame.worldBounds.left, SlitherGame.worldBounds.right);
    fallbackPos.y = fallbackPos.y.clamp(SlitherGame.worldBounds.top, SlitherGame.worldBounds.bottom);

    return fallbackPos;
  }

  bool _isNearPlayer(AiSnakeData snake, double range) =>
      snake.position.distanceTo(player.position) < range;

  void _lightPassiveUpdate(AiSnakeData snake, double dt) {
    const speed = 40.0;
    final dir = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(dir * speed * dt);

    final spacing = snake.segmentSpacing;
    Vector2 leader = snake.position;
    for (int i = 0; i < snake.bodySegments.length && i < 5; i++) {
      final seg = snake.bodySegments[i];
      final d = seg.distanceTo(leader);
      if (d > spacing) {
        seg.add((leader - seg).normalized() * (d - spacing));
      }
      leader = seg;
    }

    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  void _updateActiveSnake(AiSnakeData snake, double dt) {
    _determineAiState(snake);
    _handleBoostLogic(snake, dt);

    final desired = _calculateTargetDirection(snake);
    if (desired.length2 > 0) {
      snake.targetDirection = desired.normalized();
    }

    final targetAngle = snake.targetDirection.screenAngle();
    const rotationSpeed = 2 * pi;
    final diff = _getAngleDiff(snake.angle, targetAngle);
    final delta = rotationSpeed * dt;
    snake.angle += (diff.abs() < delta) ? diff : delta * diff.sign;

    final speed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;
    final forward = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(forward * speed * dt);

    final spacing = snake.segmentSpacing;
    Vector2 leader = snake.position;
    for (int i = 0; i < snake.bodySegments.length; i++) {
      final seg = snake.bodySegments[i];
      final d = seg.distanceTo(leader);
      if (d > spacing) {
        seg.add((leader - seg).normalized() * (d - spacing));
      }
      leader = seg;
    }

    _checkFoodConsumptionWithAnimation(snake);
    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  void _determineAiState(AiSnakeData snake) {
    final pos = snake.position;
    final bounds = SlitherGame.playArea;

    if (!_isInsideBounds(pos, bounds.deflate(200))) {
      snake.aiState = AiState.avoiding_boundary;
      return;
    }

    final distToPlayer = pos.distanceTo(player.position);
    final playerRadius = player.playerController.headRadius.value;
    final playerSegments = player.bodySegments.length;

    if (distToPlayer < 120) {
      snake.aiState = AiState.defending;
      return;
    }

    if (distToPlayer < 420) {
      if (snake.headRadius > playerRadius + 4) {
        snake.aiState = (_random.nextDouble() < 0.6) ? AiState.attacking : AiState.wandering;
        return;
      } else if (snake.headRadius < playerRadius - 4) {
        if (_random.nextDouble() < 0.4) {
          snake.aiState = AiState.attacking;
        } else {
          snake.aiState = (distToPlayer < 200 && _random.nextDouble() < 0.3)
              ? AiState.defending
              : AiState.fleeing;
        }
        return;
      } else {
        if (snake.segmentCount > playerSegments + 8) {
          snake.aiState = AiState.chasing;
        } else if (snake.segmentCount < playerSegments - 8) {
          snake.aiState = AiState.defending;
        } else {
          snake.aiState = (_random.nextDouble() < 0.3) ? AiState.attacking : AiState.wandering;
        }
        return;
      }
    }

    final nearby = _getNearbyThreats(snake);
    if (nearby.isNotEmpty) {
      final biggerThreat = nearby.any((t) => t.headRadius > snake.headRadius + 2);
      final smallerPrey = nearby.where((t) => t.headRadius < snake.headRadius - 2);

      if (biggerThreat) {
        snake.aiState = AiState.fleeing;
        return;
      } else if (smallerPrey.isNotEmpty && snake.segmentCount > 18) {
        snake.aiState = AiState.attacking;
        return;
      }
    }

    final food = _findNearestFood(snake.position, 300);
    if (food != null) {
      snake.aiState = AiState.seeking_food;
      return;
    }

    snake.aiState = AiState.wandering;
  }

  Vector2 _calculateTargetDirection(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.avoiding_boundary:
        return _getBoundaryAvoidDir(snake);
      case AiState.seeking_center:
        return (Vector2.zero() - snake.position).normalized();
      case AiState.chasing:
        final pred = player.position + player.playerController.currentDir * 60;
        return (pred - snake.position).normalized();
      case AiState.fleeing:
        return _getFleeDir(snake);
      case AiState.attacking:
        final ahead = player.position + player.playerController.currentDir * 120;
        return (ahead - snake.position).normalized();
      case AiState.defending:
        return _getDefendDir(snake);
      case AiState.seeking_food:
        final f = _findNearestFood(snake.position, 300);
        return f != null ? (f.position - snake.position).normalized() : _wanderDir(snake);
      case AiState.wandering:
      default:
        return _wanderDir(snake);
    }
  }

  Vector2 _getBoundaryAvoidDir(AiSnakeData snake) {
    final p = snake.position;
    final b = SlitherGame.playArea;
    Vector2 force = Vector2.zero();
    const safe = 600.0;

    if (p.x - b.left < safe) {
      final t = (safe - (p.x - b.left)) / safe;
      force.x += t * t * 2;
    }
    if (b.right - p.x < safe) {
      final t = (safe - (b.right - p.x)) / safe;
      force.x -= t * t * 2;
    }
    if (p.y - b.top < safe) {
      final t = (safe - (p.y - b.top)) / safe;
      force.y += t * t * 2;
    }
    if (b.bottom - p.y < safe) {
      final t = (safe - (b.bottom - p.y)) / safe;
      force.y -= t * t * 2;
    }

    if (force.length < 0.1) {
      force = (Vector2.zero() - p).normalized();
    }
    return force.normalized();
  }

  Vector2 _getFleeDir(AiSnakeData snake) {
    Vector2 flee = (snake.position - player.position).normalized();
    final perp = Vector2(-flee.y, flee.x);
    flee += perp * ((_random.nextDouble() - 0.5) * 0.4);
    return flee.normalized();
  }

  Vector2 _getDefendDir(AiSnakeData snake) {
    final toPlayer = (player.position - snake.position).normalized();
    final perp = Vector2(-toPlayer.y, toPlayer.x);
    final side = (_random.nextBool() ? 1.0 : -1.0);
    return (perp * side * 0.8 + (-toPlayer) * 0.2).normalized();
  }

  Vector2 _wanderDir(AiSnakeData snake) {
    if (_random.nextDouble() < 0.02) {
      final current = Vector2(cos(snake.angle), sin(snake.angle));
      final turn = (_random.nextDouble() - 0.5) * pi * 0.6;
      final nd = Vector2(
        current.x * cos(turn) - current.y * sin(turn),
        current.x * sin(turn) + current.y * cos(turn),
      );
      return nd.normalized();
    }
    final centerBias = (Vector2.zero() - snake.position).normalized() * 0.1;
    final cur = Vector2(cos(snake.angle), sin(snake.angle));
    return (cur + centerBias).normalized();
  }

  void _handleBoostLogic(AiSnakeData snake, double dt) {
    if (snake.boostCooldownTimer > 0) {
      snake.boostCooldownTimer -= dt;
    }

    if (snake.isBoosting) {
      snake.boostDuration -= dt;
      if (snake.boostDuration <= 0 || snake.segmentCount <= 8) {
        snake.isBoosting = false;
        snake.boostCooldownTimer = 2.0;
      }
    }

    if (!snake.isBoosting && snake.boostCooldownTimer <= 0 && snake.segmentCount > 15) {
      final should = _shouldBoost(snake);
      if (should) {
        snake.isBoosting = true;
        snake.boostDuration = 0.8 + _random.nextDouble() * 1.0;
      }
    }
  }

  bool _shouldBoost(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.chasing:
        final d = snake.position.distanceTo(player.position);
        return d < 250 && _random.nextDouble() < 0.3;
      case AiState.attacking:
        return _random.nextDouble() < 0.5;
      case AiState.fleeing:
      case AiState.defending:
        return _random.nextDouble() < 0.6;
      case AiState.avoiding_boundary:
        return _random.nextDouble() < 0.4;
      default:
        return _random.nextDouble() < 0.01;
    }
  }

  List<AiSnakeData> _getNearbyThreats(AiSnakeData snake) {
    final out = <AiSnakeData>[];
    for (final o in snakes) {
      if (o == snake || o.isDead) continue;
      final d = snake.position.distanceTo(o.position);
      if (d < 250) out.add(o);
    }
    return out;
  }

  double _getAngleDiff(double a, double b) {
    var diff = (b - a + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }

  bool _isInsideBounds(Vector2 p, Rect r) =>
      p.x >= r.left && p.x <= r.right && p.y >= r.top && p.y <= r.bottom;

  void _enforceBounds(AiSnakeData snake) {
    final b = SlitherGame.playArea;
    if (snake.position.x < b.left) snake.position.x = b.left;
    if (snake.position.x > b.right) snake.position.x = b.right;
    if (snake.position.y < b.top) snake.position.y = b.top;
    if (snake.position.y > b.bottom) snake.position.y = b.bottom;
  }

  void _updateBoundingBox(AiSnakeData snake) => snake.rebuildBoundingBox();

  void _checkFoodConsumptionWithAnimation(AiSnakeData snake) {
    final eR = snake.headRadius + 15;
    final eatRadiusSquared = eR * eR;

    final candidates = foodManager.eatableFoodList.where((food) {
      final ds = snake.position.distanceToSquared(food.position);
      return ds <= eatRadiusSquared;
    }).toList();

    for (final food in candidates) {
      foodManager.startConsumingFood(food, snake.position);

      // FIXED: Use new growth system matching player
      _growSnakeWithFood(snake, food.growth);

      foodManager.spawnFood(snake.position);
      _addAiEatingEffect(snake, food);
    }
  }

  void _addAiEatingEffect(AiSnakeData snake, food) {
    if (_frameCount % 60 == 0) {
      print('AI Snake consuming food worth ${food.growth} points! Total food score: ${snake.currentFoodScore}');
    }
  }

  // FIXED: New growth method using player-like system
  void _growSnakeWithFood(AiSnakeData snake, int foodValue) {
    snake.growFromFood(foodValue);
  }

  // Keep old method for compatibility but redirect to new system
  void _growSnake(AiSnakeData snake, int amt) {
    _growSnakeWithFood(snake, amt);
  }

  dynamic _findNearestFood(Vector2 p, double maxDist) {
    dynamic nearest;
    double best = maxDist * maxDist;
    for (final f in foodManager.eatableFoodList) {
      final ds = p.distanceToSquared(f.position);
      if (ds < best) {
        nearest = f;
        best = ds;
      }
    }
    return nearest;
  }

  Future<AiSnakeData> spawnNewSnake({Vector2? pos}) async {
    final random = Random();

    Vector2 startPos;
    if (pos != null) {
      startPos = pos;
    } else {
      final visibleRect = game.cameraComponent.visibleWorldRect.inflate(-100);
      final offscreenPos = _findOffscreenSpawnPosition(400, 800, visibleRect);
      startPos = offscreenPos ?? Vector2(
        player.position.x + (random.nextDouble() - 0.5) * 1000,
        player.position.y + (random.nextDouble() - 0.5) * 1000,
      );
    }

    final dir = (Vector2.random(random) - Vector2(0.5, 0.5)).normalized();

    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    final snake = AiSnakeData(
        position: startPos,
        skinColors: _getRandomPlayerSkin(),
        targetDirection: dir,
        segmentCount: 20 + random.nextInt(10),
        segmentSpacing: 10,
        baseSpeed: 70,
        boostSpeed: 130,
        minRadius: 8,
        maxRadius: 18,
        headSprite: headSprite
    );

    for (int i = 0; i < snake.segmentCount; i++) {
      snake.bodySegments.add(startPos - dir * (i * snake.segmentSpacing));
    }
    snake.rebuildBoundingBox();

    snakes.add(snake);
    print('Spawned new AI snake at position: (${startPos.x.toStringAsFixed(0)}, ${startPos.y.toStringAsFixed(0)})');
    return snake;
  }

  int get totalSnakeCount => snakes.length;
  int get aliveSnakeCount => snakes.where((s) => !s.isDead).length;
}