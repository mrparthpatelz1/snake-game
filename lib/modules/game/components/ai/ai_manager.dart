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
  static const double MAX_DISTANCE_FROM_PLAYER = 1200.0; // Remove snakes beyond this distance

  AiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 0,
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

    // Check AI vs AI collisions for visible snakes
    _checkAiVsAiCollisions(visibleRect);

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

    // NEW: Scatter food along the snake's body path using the new method
    foodManager.scatterFoodFromAiSnake(
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

  // NEW: AI vs AI collision detection
  void _checkAiVsAiCollisions(Rect visibleRect) {
    final visibleSnakes = snakes.where((s) =>
    !s.isDead && visibleRect.overlaps(s.boundingBox)).toList();

    for (int i = 0; i < visibleSnakes.length; i++) {
      final snake1 = visibleSnakes[i];
      if (snake1.isDead) continue;

      for (int j = i + 1; j < visibleSnakes.length; j++) {
        final snake2 = visibleSnakes[j];
        if (snake2.isDead) continue;

        _checkCollisionBetweenAiSnakes(snake1, snake2);
      }
    }
  }

  void _checkCollisionBetweenAiSnakes(AiSnakeData snake1, AiSnakeData snake2) {
    // Head vs Head collision
    final headDistance = snake1.position.distanceTo(snake2.position);
    final requiredHeadDistance = snake1.headRadius + snake2.headRadius;

    if (headDistance <= requiredHeadDistance) {
      if (snake1.headRadius > snake2.headRadius + 1.0) {
        // Snake1 wins
        snake2.isDead = true;
        _growSnake(snake1, snake2.segmentCount ~/ 3); // Winner gets some growth
      } else if (snake2.headRadius > snake1.headRadius + 1.0) {
        // Snake2 wins
        snake1.isDead = true;
        _growSnake(snake2, snake1.segmentCount ~/ 3);
      } else {
        // Equal size - both die
        snake1.isDead = true;
        snake2.isDead = true;
      }
      return;
    }

    // Snake1 head vs Snake2 body
    for (int i = 0; i < snake2.bodySegments.length; i++) {
      final segment = snake2.bodySegments[i];
      final distance = snake1.position.distanceTo(segment);
      final requiredDistance = snake1.headRadius + snake2.bodyRadius;

      if (distance <= requiredDistance) {
        snake2.isDead = true;
        _growSnake(snake1, (snake2.segmentCount ~/ 4) + 2);
        return;
      }
    }

    // Snake2 head vs Snake1 body
    for (int i = 0; i < snake1.bodySegments.length; i++) {
      final segment = snake1.bodySegments[i];
      final distance = snake2.position.distanceTo(segment);
      final requiredDistance = snake2.headRadius + snake1.bodyRadius;

      if (distance <= requiredDistance) {
        snake1.isDead = true;
        _growSnake(snake2, (snake1.segmentCount ~/ 4) + 2);
        return;
      }
    }
  }

  // NEW: Periodic cleanup for performance optimization
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

    // Garbage collect if we have too many snakes
    if (snakes.length > 50) {
      final excess = snakes.length - 40;
      final toRemove = snakes
          .where((s) => !s.isDead)
          .where((s) => s.position.distanceTo(playerPos) > 800)
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
    final grid = (sqrt(numberOfSnakes)).ceil().clamp(1, 10); // Limit grid size
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

    // NEW: Use random player skins for AI snakes
    final randomSkin = _getRandomPlayerSkin();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    final snake = AiSnakeData(
      position: pos,
      skinColors: randomSkin, // Use player skins instead of random colors
      targetDirection: Vector2.random(_random).normalized(),
      segmentCount: initCount,
      segmentSpacing: 13.0 * 0.6,
      baseSpeed: baseSpeed,
      boostSpeed: baseSpeed * 1.6,
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

  // NEW: Get random player skin for AI snakes
  List<Color> _getRandomPlayerSkin() {
    final allSkins = _settingsService.allSkins;
    if (allSkins.isEmpty) {
      // Fallback to basic colors if no skins available
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

  // NEW: Enhanced spawning to ensure snakes spawn outside visible area
  void _ensureMinSnakesAroundPlayer() {
    const minActive = 15;
    const maxActive = 25; // Limit maximum for performance
    const spawnRadius = 900.0;
    const safeZone = 420.0;
    const offscreenMargin = 150.0; // Increased margin to ensure offscreen spawning

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius).length;

    if (near >= minActive && near <= maxActive) return;

    if (near < minActive) {
      final need = (minActive - near).clamp(0, 5); // Limit spawning rate
      final visible = game.cameraComponent.visibleWorldRect.inflate(-offscreenMargin); // Negative inflation to ensure offscreen

      for (int i = 0; i < need; i++) {
        Vector2? spawnPos = _findOffscreenSpawnPosition(safeZone, spawnRadius, visible);

        if (spawnPos != null) {
          _spawnSnakeAt(spawnPos);
          print('Spawned AI snake at offscreen position: (${spawnPos.x.toStringAsFixed(0)}, ${spawnPos.y.toStringAsFixed(0)})');
        }
      }
    }
  }

  // NEW: Find a spawn position that's outside the visible area
  Vector2? _findOffscreenSpawnPosition(double safeZone, double spawnRadius, Rect visibleArea) {
    const maxAttempts = 10;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final ang = _random.nextDouble() * pi * 2;
      final dist = safeZone + _random.nextDouble() * (spawnRadius - safeZone);
      final spawnPos = player.position + Vector2(cos(ang), sin(ang)) * dist;

      // Check if position is outside visible area and within world bounds
      if (!visibleArea.contains(spawnPos.toOffset()) &&
          SlitherGame.worldBounds.contains(spawnPos.toOffset())) {
        return spawnPos;
      }
    }

    // Fallback: spawn at edge of visible area
    final edgeAngles = [0, pi/2, pi, 3*pi/2]; // Right, Down, Left, Up
    final edgeAngle = edgeAngles[_random.nextInt(edgeAngles.length)];
    final edgeDistance = spawnRadius * 0.8;
    final fallbackPos = player.position + Vector2(cos(edgeAngle), sin(edgeAngle)) * edgeDistance;

    // Clamp to world bounds
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
    for (int i = 0; i < snake.bodySegments.length && i < 5; i++) { // Limit body updates for performance
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
      if (snake.headRadius > playerRadius + 2) {
        snake.aiState = (_random.nextDouble() < 0.75) ? AiState.attacking : AiState.wandering;
        return;
      } else if (snake.headRadius < playerRadius - 2) {
        if (_random.nextDouble() < 0.5) {
          snake.aiState = AiState.attacking;
        } else {
          snake.aiState = (distToPlayer < 200 && _random.nextDouble() < 0.35)
              ? AiState.defending
              : AiState.fleeing;
        }
        return;
      } else {
        if (snake.segmentCount > playerSegments + 5) {
          snake.aiState = AiState.chasing;
        } else if (snake.segmentCount < playerSegments - 5) {
          snake.aiState = AiState.defending;
        } else {
          snake.aiState = (_random.nextBool()) ? AiState.attacking : AiState.wandering;
        }
        return;
      }
    }

    final nearby = _getNearbyThreats(snake);
    if (nearby.isNotEmpty) {
      final biggerThreat = nearby.any((t) => t.headRadius > snake.headRadius + 1);
      final smallerPrey = nearby.where((t) => t.headRadius < snake.headRadius - 1);

      if (biggerThreat) {
        snake.aiState = AiState.fleeing;
        return;
      } else if (smallerPrey.isNotEmpty && snake.segmentCount > 15) {
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

    if (!snake.isBoosting && snake.boostCooldownTimer <= 0 && snake.segmentCount > 12) {
      final should = _shouldBoost(snake);
      if (should) {
        snake.isBoosting = true;
        snake.boostDuration = 1.0 + _random.nextDouble() * 1.5;
      }
    }
  }

  bool _shouldBoost(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.chasing:
        final d = snake.position.distanceTo(player.position);
        return d < 300 && _random.nextDouble() < 0.4;
      case AiState.attacking:
        return _random.nextDouble() < 0.7;
      case AiState.fleeing:
      case AiState.defending:
        return _random.nextDouble() < 0.8;
      case AiState.avoiding_boundary:
        return _random.nextDouble() < 0.5;
      default:
        return _random.nextDouble() < 0.02;
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
      _growSnake(snake, food.growth);
      foodManager.spawnFood(snake.position);
      _addAiEatingEffect(snake, food);
    }
  }

  void _addAiEatingEffect(AiSnakeData snake, food) {
    // Optional: Add visual or audio effects for AI eating
    if (_frameCount % 60 == 0) { // Reduce debug spam
      print('AI Snake consuming food worth ${food.growth} points!');
    }
  }

  void _growSnake(AiSnakeData snake, int amt) {
    final old = snake.segmentCount;
    snake.segmentCount += amt;
    for (int i = 0; i < amt; i++) {
      if (snake.bodySegments.isNotEmpty) {
        snake.bodySegments.add(snake.bodySegments.last.clone());
      } else {
        snake.bodySegments.add(snake.position.clone());
      }
    }
    final oldB = (old / 25).floor();
    final newB = (snake.segmentCount / 25).floor();
    if (newB > oldB) {
      final inc = (newB - oldB).toDouble();
      snake.headRadius = (snake.headRadius + inc).clamp(snake.minRadius, snake.maxRadius);
      snake.bodyRadius = snake.headRadius - 1.0;
    }
  }

  // REMOVED: killSnakeAndScatterFood - now handled in death animation

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

    // NEW: Try to spawn offscreen first
    Vector2 startPos;
    if (pos != null) {
      startPos = pos;
    } else {
      final visibleRect = game.cameraComponent.visibleWorldRect.inflate(-100); // Ensure offscreen
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
      skinColors: _getRandomPlayerSkin(), // Use player skins
      targetDirection: dir,
      segmentCount: 20 + random.nextInt(10),
      segmentSpacing: 10,
      baseSpeed: 80,
      boostSpeed: 140,
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

  // Getter for total snake count (for debugging)
  int get totalSnakeCount => snakes.length;
  int get aliveSnakeCount => snakes.where((s) => !s.isDead).length;
}