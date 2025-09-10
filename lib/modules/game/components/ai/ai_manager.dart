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
  final List<AiSnakeData> _dyingSnakes = [];

  late final List<Rect> _spawnZones;
  int _nextZoneIndex = 0;
  int _nextId = 0;

  // Performance optimization counters
  int _frameCount = 0;
  int _cleanupCounter = 0;
  static const int CLEANUP_INTERVAL = 120;
  static const double MAX_DISTANCE_FROM_PLAYER = 1500.0;

  // Collision cooldowns for better survival
  final Map<AiSnakeData, double> _collisionCooldowns = {};
  static const double COLLISION_COOLDOWN_TIME = 1.0; // Increased immunity time

  // AI snake initial length matches player
  static const int INITIAL_SEGMENT_COUNT = 10;

  AiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 15,
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

    // Update collision cooldowns
    final cooldownsToRemove = <AiSnakeData>[];
    _collisionCooldowns.forEach((snake, cooldown) {
      final newCooldown = cooldown - dt;
      if (newCooldown <= 0) {
        cooldownsToRemove.add(snake);
      } else {
        _collisionCooldowns[snake] = newCooldown;
      }
    });
    for (final snake in cooldownsToRemove) {
      _collisionCooldowns.remove(snake);
    }

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

    // Update dying snakes
    _updateDyingSnakes(dt);

    // Check collisions less frequently
    if (_frameCount % 3 == 0) { // Every 3rd frame
      _checkAiVsAiCollisionsSafer(visibleRect);
    }

    // Process newly dead snakes
    final newlyDead = snakes.where((s) => s.isDead && !_dyingSnakes.contains(s)).toList();
    for (final snake in newlyDead) {
      _startDeathAnimation(snake);
    }

    // Periodic cleanup
    _cleanupCounter++;
    if (_cleanupCounter >= CLEANUP_INTERVAL) {
      _cleanupCounter = 0;
      _performPeriodicCleanup();
    }

    // Ensure minimum snakes
    _ensureMinSnakesAroundPlayer();

    if (_frameCount % 180 == 0) {
      debugPrint(
        "AI Stats - Active: $activeCount | Passive: $passiveCount | Total: ${snakes.length} | Dying: ${_dyingSnakes.length}",
      );
    }
  }

  void killSnakeAsRevenge(AiSnakeData snake) {
    if (snake.isDead) return;

    print('REVENGE KILL: Eliminating AI snake that killed the player!');
    snake.isDead = true;
    _startDeathAnimation(snake, isRevengeDeath: true);
  }

  void _startDeathAnimation(AiSnakeData snake, {bool isRevengeDeath = false}) {
    print('Starting death animation for snake with ${snake.segmentCount} segments');

    _dyingSnakes.add(snake);

    snake.deathAnimationTimer = isRevengeDeath
        ? AiSnakeData.deathAnimationDuration * 1.5
        : AiSnakeData.deathAnimationDuration;
    snake.originalScale = 1.0;

    // FIXED: Always spawn 10-15 food pellets along body
    foodManager.scatterFoodFromAiSnakeBody(
        snake.position,
        snake.headRadius,
        snake.bodySegments,
        isRevengeDeath
    );
  }

  void _updateDyingSnakes(double dt) {
    final List<AiSnakeData> toRemove = [];

    for (final snake in _dyingSnakes) {
      snake.deathAnimationTimer -= dt;

      final progress = 1.0 - (snake.deathAnimationTimer / AiSnakeData.deathAnimationDuration);
      snake.scale = (1.0 - progress).clamp(0.0, 1.0);
      snake.opacity = snake.scale;

      if (snake.deathAnimationTimer <= 0) {
        toRemove.add(snake);
      }
    }

    for (final snake in toRemove) {
      _dyingSnakes.remove(snake);
      snakes.remove(snake);
      _collisionCooldowns.remove(snake);
    }
  }

  // IMPROVED: Even safer collision detection
  void _checkAiVsAiCollisionsSafer(Rect visibleRect) {
    final visibleSnakes = snakes.where((s) =>
    !s.isDead && visibleRect.overlaps(s.boundingBox)).toList();

    for (int i = 0; i < visibleSnakes.length; i++) {
      final snake1 = visibleSnakes[i];
      if (snake1.isDead || _collisionCooldowns.containsKey(snake1)) continue;

      for (int j = i + 1; j < visibleSnakes.length; j++) {
        final snake2 = visibleSnakes[j];
        if (snake2.isDead || _collisionCooldowns.containsKey(snake2)) continue;

        _checkCollisionBetweenAiSnakesVeryCareful(snake1, snake2);
      }
    }
  }

  // VERY CAREFUL: More survival-focused collision
  void _checkCollisionBetweenAiSnakesVeryCareful(AiSnakeData snake1, AiSnakeData snake2) {
    // Head vs Head collision - very forgiving
    final headDistance = snake1.position.distanceTo(snake2.position);
    final requiredHeadDistance = (snake1.headRadius + snake2.headRadius) * 0.8; // 20% buffer

    if (headDistance <= requiredHeadDistance) {
      // Need significant size difference to kill
      if (snake1.headRadius > snake2.headRadius + 6.0) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 10);
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
      } else if (snake2.headRadius > snake1.headRadius + 6.0) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 10);
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
      } else {
        // Push apart with strong force
        final pushDirection = (snake1.position - snake2.position).normalized();
        snake1.position += pushDirection * 30;
        snake2.position -= pushDirection * 30;
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
      }
      return;
    }

    // Body collision - skip first 8 segments (large neck area)
    // Snake1 head vs Snake2 body
    for (int i = 8; i < snake2.bodySegments.length; i += 4) {
      final segment = snake2.bodySegments[i];
      final distance = snake1.position.distanceTo(segment);
      final requiredDistance = (snake1.headRadius + snake2.bodyRadius) * 0.75; // Very forgiving

      if (distance <= requiredDistance) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 10);
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
        return;
      }
    }

    // Snake2 head vs Snake1 body
    for (int i = 8; i < snake1.bodySegments.length; i += 4) {
      final segment = snake1.bodySegments[i];
      final distance = snake2.position.distanceTo(segment);
      final requiredDistance = (snake2.headRadius + snake1.bodyRadius) * 0.75;

      if (distance <= requiredDistance) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 10);
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
        return;
      }
    }
  }

  void _performPeriodicCleanup() {
    final playerPos = player.position;
    int removedCount = 0;

    snakes.removeWhere((snake) {
      if (snake.isDead) return false;

      final distance = snake.position.distanceTo(playerPos);
      if (distance > MAX_DISTANCE_FROM_PLAYER) {
        removedCount++;
        _collisionCooldowns.remove(snake);
        return true;
      }
      return false;
    });

    if (removedCount > 0) {
      debugPrint("Cleaned up $removedCount distant AI snakes");
    }

    // Limit total snakes
    if (snakes.length > 25) {
      final excess = snakes.length - 20;
      final toRemove = snakes
          .where((s) => !s.isDead)
          .where((s) => s.position.distanceTo(playerPos) > 1000)
          .take(excess)
          .toList();

      for (final snake in toRemove) {
        snakes.remove(snake);
        _collisionCooldowns.remove(snake);
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

    if (snakes.isNotEmpty) {
      final avgSegments = snakes.map((s) => s.segmentCount).reduce((a, b) => a + b) ~/ snakes.length;
      print('Initial AI spawn: ${snakes.length} snakes with avg $avgSegments segments');
    }
  }

  void _spawnSnake() {
    if (_spawnZones.isEmpty) return;

    final zone = _spawnZones[_nextZoneIndex++ % _spawnZones.length];
    final x = zone.left + _random.nextDouble() * zone.width;
    final y = zone.top + _random.nextDouble() * zone.height;
    final pos = Vector2(x, y);
    _spawnSnakeAtPosition(pos, isInitialSpawn: true);
  }

  // COMPLETELY FIXED: Spawn entire snake outside screen
  void _spawnSnakeAt(Vector2 pos) {
    _spawnSnakeAtPosition(pos, isInitialSpawn: false);
  }

  void _spawnSnakeAtPosition(Vector2 pos, {bool isInitialSpawn = false}) async {
    final playerSegments = player.bodySegments.length;

    // Calculate spawn size relative to player (or use initial size)
    int initCount;
    if (isInitialSpawn || playerSegments <= INITIAL_SEGMENT_COUNT) {
      // Initial spawn or early game - use player's initial size
      initCount = INITIAL_SEGMENT_COUNT;
    } else {
      // Scale with player size
      final minSegments = (playerSegments * 0.7).round().clamp(INITIAL_SEGMENT_COUNT, 40);
      final maxSegments = (playerSegments * 1.1).round().clamp(INITIAL_SEGMENT_COUNT + 5, 60);
      initCount = minSegments + _random.nextInt(maxSegments - minSegments + 1);
    }

    final baseSpeed = 60.0 + _random.nextDouble() * 20.0;
    final randomSkin = _getRandomPlayerSkin();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    // Create snake with appropriate direction
    final spawnDirection = (Vector2.zero() - pos).normalized();

    final snake = AiSnakeData(
        position: pos.clone(),
        skinColors: randomSkin,
        targetDirection: spawnDirection,
        segmentCount: initCount,
        segmentSpacing: 13.0 * 0.6,
        baseSpeed: 60,
        boostSpeed: 130,
        minRadius: 16.0,
        maxRadius: 50.0,
        headSprite: headSprite
    );

    final bonus = (initCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (initCount - INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    // CRITICAL FIX: Ensure entire snake spawns outside screen
    final visibleRect = game.cameraComponent.visibleWorldRect;
    final totalSnakeLength = initCount * snake.segmentSpacing + 100; // Extra margin

    // If spawn position is too close to or inside visible area, move it far outside
    if (!isInitialSpawn) {
      final distToVisible = _distanceToRect(pos, visibleRect);

      if (distToVisible < totalSnakeLength) {
        // Find the nearest edge and move snake completely outside
        final edges = [
          {'side': 'left', 'dist': pos.x - visibleRect.left},
          {'side': 'right', 'dist': visibleRect.right - pos.x},
          {'side': 'top', 'dist': pos.y - visibleRect.top},
          {'side': 'bottom', 'dist': visibleRect.bottom - pos.y},
        ];

        edges.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
        final nearestEdge = edges.first['side'] as String;

        // Move snake completely outside with full body length clearance
        switch (nearestEdge) {
          case 'left':
            pos.x = visibleRect.left - totalSnakeLength;
            break;
          case 'right':
            pos.x = visibleRect.right + totalSnakeLength;
            break;
          case 'top':
            pos.y = visibleRect.top - totalSnakeLength;
            break;
          case 'bottom':
            pos.y = visibleRect.bottom + totalSnakeLength;
            break;
        }

        // Update snake position
        snake.position = pos.clone();
      }
    }

    // Build body segments extending away from player/center
    snake.bodySegments.clear();
    snake.path.clear();

    // Body extends opposite to spawn direction (away from center)
    final bodyDirection = -spawnDirection;
    for (int i = 0; i < initCount; i++) {
      final segmentPos = pos + (bodyDirection * snake.segmentSpacing * (i + 1));
      snake.bodySegments.add(segmentPos);
      snake.path.add(segmentPos.clone());
    }

    snake.aiState = AiState.wandering;
    snakes.add(snake);
    _updateBoundingBox(snake);

    if (!isInitialSpawn) {
      print('Spawned AI snake with $initCount segments completely outside screen at distance ${_distanceToRect(pos, visibleRect).toStringAsFixed(0)}');
    }
  }

  double _distanceToRect(Vector2 point, Rect rect) {
    final dx = max(max(rect.left - point.x, 0), point.x - rect.right);
    final dy = max(max(rect.top - point.y, 0), point.y - rect.bottom);
    return sqrt(dx * dx + dy * dy);
  }

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

  void _ensureMinSnakesAroundPlayer() {
    const minActive = 10;
    const maxActive = 15;
    const spawnRadius = 1000.0;
    const safeZone = 600.0;

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius).length;

    if (near >= minActive && near <= maxActive) return;

    if (near < minActive) {
      final need = (minActive - near).clamp(0, 2);

      for (int i = 0; i < need; i++) {
        Vector2? spawnPos = _findOffscreenSpawnPosition(safeZone, spawnRadius);

        if (spawnPos != null) {
          _spawnSnakeAt(spawnPos);
        }
      }
    }
  }

  Vector2? _findOffscreenSpawnPosition(double safeZone, double spawnRadius) {
    final visibleRect = game.cameraComponent.visibleWorldRect;

    // Always spawn well outside visible area
    final margin = 400.0;
    final angles = [0, pi/2, pi, 3*pi/2];
    final angle = angles[_random.nextInt(angles.length)];

    // Calculate spawn distance to ensure entire snake is outside
    final spawnDistance = max(visibleRect.width, visibleRect.height) / 2 + margin;

    final spawnPos = game.cameraComponent.visibleWorldRect.center.toVector2() +
        Vector2(cos(angle), sin(angle)) * spawnDistance;

    // Clamp to world bounds
    spawnPos.x = spawnPos.x.clamp(
        SlitherGame.worldBounds.left + 100,
        SlitherGame.worldBounds.right - 100
    );
    spawnPos.y = spawnPos.y.clamp(
        SlitherGame.worldBounds.top + 100,
        SlitherGame.worldBounds.bottom - 100
    );

    return spawnPos;
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
    const rotationSpeed = 1.8 * pi; // Slightly slower turning for safety
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

  // ULTRA DEFENSIVE: AI state for maximum survival
  void _determineAiState(AiSnakeData snake) {
    final pos = snake.position;
    final bounds = SlitherGame.playArea;

    // Priority 1: Always avoid boundaries
    if (!_isInsideBounds(pos, bounds.deflate(400))) {
      snake.aiState = AiState.avoiding_boundary;
      return;
    }

    final distToPlayer = pos.distanceTo(player.position);
    final playerRadius = player.playerController.headRadius.value;

    // Priority 2: Strong defensive behavior near player
    if (distToPlayer < 200) {
      snake.aiState = AiState.defending;
      return;
    }

    // Priority 3: Very cautious interaction
    if (distToPlayer < 400) {
      final sizeDiff = snake.headRadius - playerRadius;

      if (sizeDiff > 8) {
        // Only attack if much larger
        snake.aiState = (_random.nextDouble() < 0.2) ? AiState.attacking : AiState.wandering;
      } else {
        // Flee or defend when similar or smaller
        snake.aiState = (_random.nextDouble() < 0.8) ? AiState.fleeing : AiState.defending;
      }
      return;
    }

    // Check for nearby AI threats
    final nearby = _getNearbyThreats(snake);
    if (nearby.isNotEmpty) {
      final biggerThreat = nearby.any((t) => t.headRadius > snake.headRadius + 2);

      if (biggerThreat) {
        snake.aiState = AiState.fleeing;
        return;
      }
    }

    // Look for food cautiously
    final food = _findNearestFood(snake.position, 200);
    if (food != null && _isSafeToSeekFood(snake, food.position)) {
      snake.aiState = AiState.seeking_food;
      return;
    }

    snake.aiState = AiState.wandering;
  }

  bool _isSafeToSeekFood(AiSnakeData snake, Vector2 foodPos) {
    // Check if food is near threats
    for (final other in snakes) {
      if (other == snake || other.isDead) continue;
      if (other.headRadius > snake.headRadius &&
          other.position.distanceTo(foodPos) < 150) {
        return false; // Food is near a bigger snake
      }
    }

    // Check if food is near player when player is bigger
    if (player.playerController.headRadius.value > snake.headRadius &&
        player.position.distanceTo(foodPos) < 150) {
      return false;
    }

    return true;
  }

  Vector2 _calculateTargetDirection(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.avoiding_boundary:
        return _getBoundaryAvoidDir(snake);
      case AiState.seeking_center:
        return (Vector2.zero() - snake.position).normalized();
      case AiState.chasing:
      // More cautious chasing
        final pred = player.position + player.playerController.currentDir * 40;
        return (pred - snake.position).normalized();
      case AiState.fleeing:
        return _getFleeDir(snake);
      case AiState.attacking:
      // Careful attacking
        final ahead = player.position + player.playerController.currentDir * 80;
        return (ahead - snake.position).normalized();
      case AiState.defending:
        return _getDefendDir(snake);
      case AiState.seeking_food:
        final f = _findNearestFood(snake.position, 200);
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
    const safe = 800.0; // Increased safety margin

    if (p.x - b.left < safe) {
      final t = (safe - (p.x - b.left)) / safe;
      force.x += t * t * 3; // Stronger avoidance
    }
    if (b.right - p.x < safe) {
      final t = (safe - (b.right - p.x)) / safe;
      force.x -= t * t * 3;
    }
    if (p.y - b.top < safe) {
      final t = (safe - (p.y - b.top)) / safe;
      force.y += t * t * 3;
    }
    if (b.bottom - p.y < safe) {
      final t = (safe - (b.bottom - p.y)) / safe;
      force.y -= t * t * 3;
    }

    if (force.length < 0.1) {
      force = (Vector2.zero() - p).normalized();
    }
    return force.normalized();
  }

  Vector2 _getFleeDir(AiSnakeData snake) {
    Vector2 flee = (snake.position - player.position).normalized();

    // Also flee from other bigger snakes
    for (final other in snakes) {
      if (other == snake || other.isDead) continue;
      if (other.headRadius > snake.headRadius &&
          other.position.distanceTo(snake.position) < 300) {
        flee += (snake.position - other.position).normalized() * 0.5;
      }
    }

    return flee.normalized();
  }

  Vector2 _getDefendDir(AiSnakeData snake) {
    final toPlayer = (player.position - snake.position).normalized();
    final perp = Vector2(-toPlayer.y, toPlayer.x);
    final side = (_random.nextBool() ? 1.0 : -1.0);
    return (perp * side * 0.9 + (-toPlayer) * 0.1).normalized();
  }

  Vector2 _wanderDir(AiSnakeData snake) {
    if (_random.nextDouble() < 0.015) { // Less frequent direction changes
      final current = Vector2(cos(snake.angle), sin(snake.angle));
      final turn = (_random.nextDouble() - 0.5) * pi * 0.4; // Smaller turns
      final nd = Vector2(
        current.x * cos(turn) - current.y * sin(turn),
        current.x * sin(turn) + current.y * cos(turn),
      );
      return nd.normalized();
    }
    final centerBias = (Vector2.zero() - snake.position).normalized() * 0.15;
    final cur = Vector2(cos(snake.angle), sin(snake.angle));
    return (cur + centerBias).normalized();
  }

  // VERY CONSERVATIVE: Minimal boosting for survival
  void _handleBoostLogic(AiSnakeData snake, double dt) {
    if (snake.boostCooldownTimer > 0) {
      snake.boostCooldownTimer -= dt;
    }

    if (snake.isBoosting) {
      snake.boostDuration -= dt;
      if (snake.boostDuration <= 0 || snake.segmentCount <= 12) {
        snake.isBoosting = false;
        snake.boostCooldownTimer = 4.0; // Long cooldown
      }
    }

    if (!snake.isBoosting && snake.boostCooldownTimer <= 0 && snake.segmentCount > 25) {
      final should = _shouldBoost(snake);
      if (should) {
        snake.isBoosting = true;
        snake.boostDuration = 0.3 + _random.nextDouble() * 0.3; // Very short boosts
      }
    }
  }

  bool _shouldBoost(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.fleeing:
      case AiState.avoiding_boundary:
        return _random.nextDouble() < 0.3; // Only boost when really needed
      case AiState.defending:
        return _random.nextDouble() < 0.2;
      case AiState.attacking:
      case AiState.chasing:
        return _random.nextDouble() < 0.1; // Very rare offensive boost
      default:
        return false; // Never boost when wandering or seeking food
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
      _growSnakeWithFood(snake, food.growth);
      foodManager.spawnFood(snake.position);
      _addAiEatingEffect(snake, food);
    }
  }

  void _addAiEatingEffect(AiSnakeData snake, food) {
    // Visual effects can be added here
  }

  void _growSnakeWithFood(AiSnakeData snake, int foodValue) {
    snake.growFromFood(foodValue);
  }

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

  // Spawn replacement snakes completely offscreen
  Future<AiSnakeData> spawnNewSnake({Vector2? pos}) async {
    final random = Random();

    Vector2 startPos;
    if (pos != null) {
      startPos = pos;
    } else {
      startPos = _findOffscreenSpawnPosition(600, 1000) ?? Vector2.zero();
    }

    final dir = (Vector2.random(random) - Vector2(0.5, 0.5)).normalized();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    final playerSegments = player.bodySegments.length;
    final minSegments = (playerSegments * 0.7).round().clamp(INITIAL_SEGMENT_COUNT, 40);
    final maxSegments = (playerSegments * 1.1).round().clamp(INITIAL_SEGMENT_COUNT + 5, 60);
    final segmentCount = minSegments + random.nextInt(maxSegments - minSegments + 1);

    final snake = AiSnakeData(
        position: startPos,
        skinColors: _getRandomPlayerSkin(),
        targetDirection: dir,
        segmentCount: segmentCount,
        segmentSpacing: 10,
        baseSpeed: 70,
        boostSpeed: 130,
        minRadius: 16,
        maxRadius: 50,
        headSprite: headSprite
    );

    final bonus = (segmentCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (segmentCount - INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    // Build body extending away from visible area
    for (int i = 0; i < snake.segmentCount; i++) {
      snake.bodySegments.add(startPos - dir * (i * snake.segmentSpacing));
    }
    snake.rebuildBoundingBox();

    snakes.add(snake);
    print('Spawned replacement AI snake with $segmentCount segments offscreen');
    return snake;
  }

  int get totalSnakeCount => snakes.length;
  int get aliveSnakeCount => snakes.where((s) => !s.isDead).length;
}