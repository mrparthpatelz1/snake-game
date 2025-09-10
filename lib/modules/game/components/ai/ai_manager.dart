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

  int _nextId = 0;

  // Performance optimization counters
  int _frameCount = 0;
  int _cleanupCounter = 0;
  static const int CLEANUP_INTERVAL = 120;
  static const double MAX_DISTANCE_FROM_PLAYER = 1500.0;

  // Collision cooldowns for better survival
  final Map<AiSnakeData, double> _collisionCooldowns = {};
  static const double COLLISION_COOLDOWN_TIME = 1.0;

  // NEW: Fixed initial length
  static const int AI_INITIAL_SEGMENT_COUNT = 10;

  // NEW: Track spawn positions to ensure separation
  final List<Vector2> _recentSpawnPositions = [];
  static const double MIN_SPAWN_SEPARATION = 400.0;

  AiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 15,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
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
    if (_frameCount % 3 == 0) {
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

    // Always spawn 10-15 food pellets along body
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

  void _checkAiVsAiCollisionsSafer(Rect visibleRect) {
    final visibleSnakes = snakes.where((s) =>
    !s.isDead && visibleRect.overlaps(s.boundingBox)).toList();

    for (int i = 0; i < visibleSnakes.length; i++) {
      final snake1 = visibleSnakes[i];
      if (snake1.isDead || _collisionCooldowns.containsKey(snake1)) continue;

      for (int j = i + 1; j < visibleSnakes.length; j++) {
        final snake2 = visibleSnakes[j];
        if (snake2.isDead || _collisionCooldowns.containsKey(snake2)) continue;

        _checkCollisionBetweenAiSnakes(snake1, snake2);
      }
    }
  }

  // NEW: More realistic AI vs AI collisions - like real players
  void _checkCollisionBetweenAiSnakes(AiSnakeData snake1, AiSnakeData snake2) {
    // Head vs Head collision
    final headDistance = snake1.position.distanceTo(snake2.position);
    final requiredHeadDistance = (snake1.headRadius + snake2.headRadius) * 0.9; // Less forgiving

    if (headDistance <= requiredHeadDistance) {
      if (snake1.headRadius > snake2.headRadius + 2.0) { // Reduced size difference needed
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 8); // More food reward
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
      } else if (snake2.headRadius > snake1.headRadius + 2.0) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 8);
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
      } else {
        // Both die if similar size
        snake1.isDead = true;
        snake2.isDead = true;
      }
      return;
    }

    // Body collision - check more segments, less forgiving
    // Snake1 head vs Snake2 body
    for (int i = 3; i < snake2.bodySegments.length; i += 2) { // Check more segments
      final segment = snake2.bodySegments[i];
      final distance = snake1.position.distanceTo(segment);
      final requiredDistance = (snake1.headRadius + snake2.bodyRadius) * 0.85; // Less forgiving

      if (distance <= requiredDistance) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 8);
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
        return;
      }
    }

    // Snake2 head vs Snake1 body
    for (int i = 3; i < snake1.bodySegments.length; i += 2) {
      final segment = snake1.bodySegments[i];
      final distance = snake2.position.distanceTo(segment);
      final requiredDistance = (snake2.headRadius + snake1.bodyRadius) * 0.85;

      if (distance <= requiredDistance) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 8);
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

    // Clean old spawn positions
    if (_recentSpawnPositions.length > 10) {
      _recentSpawnPositions.removeRange(0, _recentSpawnPositions.length - 10);
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

  // NEW: Generate offscreen spawn positions around the visible area
  List<Vector2> _generateOffscreenSpawnPositions() {
    final visibleRect = game.cameraComponent.visibleWorldRect;
    final positions = <Vector2>[];

    // Calculate spawn distance - enough to fit longest possible snake
    final maxSnakeLength = AI_INITIAL_SEGMENT_COUNT * 13.0 + 200; // Extra margin
    final spawnDistance = max(visibleRect.width, visibleRect.height) / 2 + maxSnakeLength;

    // Generate positions around the perimeter
    final centerX = visibleRect.center.dx;
    final centerY = visibleRect.center.dy;

    // 8 directions around the screen
    final angles = [
      0,              // Right
      pi / 4,         // Bottom-right
      pi / 2,         // Bottom
      3 * pi / 4,     // Bottom-left
      pi,             // Left
      5 * pi / 4,     // Top-left
      3 * pi / 2,     // Top
      7 * pi / 4,     // Top-right
    ];

    for (final angle in angles) {
      final x = centerX + cos(angle) * spawnDistance;
      final y = centerY + sin(angle) * spawnDistance;

      // Clamp to world bounds
      final clampedX = x.clamp(SlitherGame.worldBounds.left + 100, SlitherGame.worldBounds.right - 100);
      final clampedY = y.clamp(SlitherGame.worldBounds.top + 100, SlitherGame.worldBounds.bottom - 100);

      positions.add(Vector2(clampedX, clampedY));
    }

    // Shuffle for randomness
    positions.shuffle(_random);
    return positions;
  }

  // NEW: Find a spawn position that's separated from recent spawns
  Vector2? _findSeparatedSpawnPosition() {
    final candidates = _generateOffscreenSpawnPositions();

    for (final candidate in candidates) {
      bool tooClose = false;

      // Check distance from recent spawn positions
      for (final recent in _recentSpawnPositions) {
        if (candidate.distanceTo(recent) < MIN_SPAWN_SEPARATION) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        _recentSpawnPositions.add(candidate);
        return candidate;
      }
    }

    // If all positions are too close, use the first one anyway
    if (candidates.isNotEmpty) {
      final fallback = candidates.first;
      _recentSpawnPositions.add(fallback);
      return fallback;
    }

    return null;
  }

  // FIXED: Spawn all snakes completely outside screen with separation
  void _spawnAllSnakes() {
    print('Spawning ${numberOfSnakes} AI snakes outside screen with length $AI_INITIAL_SEGMENT_COUNT...');

    for (int i = 0; i < numberOfSnakes; i++) {
      final spawnPos = _findSeparatedSpawnPosition();
      if (spawnPos != null) {
        _spawnSnakeAtPosition(spawnPos, isInitialSpawn: true);
      } else {
        print('Warning: Could not find suitable spawn position for AI snake $i');
      }
    }

    if (snakes.isNotEmpty) {
      print('Initial AI spawn complete: ${snakes.length} snakes with length $AI_INITIAL_SEGMENT_COUNT (all outside screen)');
    }
  }

  // FIXED: Spawn snake at position with proper offscreen body placement
  void _spawnSnakeAtPosition(Vector2 pos, {bool isInitialSpawn = false}) async {
    // NEW: Always use fixed initial count of 8
    int initCount = AI_INITIAL_SEGMENT_COUNT;

    // For replacement spawns, allow some variation but stay reasonable
    if (!isInitialSpawn) {
      final playerSegments = player.bodySegments.length;
      final minSegments = max(AI_INITIAL_SEGMENT_COUNT, (playerSegments * 0.6).round());
      final maxSegments = (playerSegments * 1.2).round().clamp(AI_INITIAL_SEGMENT_COUNT, 50);
      initCount = minSegments + _random.nextInt(max(1, maxSegments - minSegments + 1));
    }

    final baseSpeed = 60.0 + _random.nextDouble() * 20.0;
    final randomSkin = _getRandomPlayerSkin();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    // NEW: Calculate direction toward player/center for more realistic movement
    final playerPosition = player.position;
    final towardPlayerDirection = (playerPosition - pos).normalized();

    final snake = AiSnakeData(
        position: pos.clone(),
        skinColors: randomSkin,
        targetDirection: towardPlayerDirection, // Move toward player initially
        segmentCount: initCount,
        segmentSpacing: 13.0 * 0.6,
        baseSpeed: 70, // Slightly faster base speed
        boostSpeed: 140, // Faster boost speed
        minRadius: 16.0,
        maxRadius: 50.0,
        headSprite: headSprite
    );

    final bonus = (initCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (initCount - AI_INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    // CRITICAL: Build entire snake body extending away from player/center
    snake.bodySegments.clear();
    snake.path.clear();

    // Extend body in the direction away from player (so body is behind the head)
    final awayFromPlayerDirection = -towardPlayerDirection;
    for (int i = 0; i < initCount; i++) {
      final segmentPos = pos + (awayFromPlayerDirection * snake.segmentSpacing * (i + 1));
      snake.bodySegments.add(segmentPos);
      snake.path.add(segmentPos.clone());
    }

    snake.aiState = AiState.seeking_center; // Start by seeking center/player
    snakes.add(snake);
    _updateBoundingBox(snake);

    if (!isInitialSpawn) {
      final visibleRect = game.cameraComponent.visibleWorldRect;
      print('Spawned AI snake with $initCount segments moving toward player');
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

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius).length;

    if (near >= minActive && near <= maxActive) return;

    if (near < minActive) {
      final need = (minActive - near).clamp(0, 2);

      for (int i = 0; i < need; i++) {
        Vector2? spawnPos = _findSeparatedSpawnPosition();

        if (spawnPos != null) {
          _spawnSnakeAtPosition(spawnPos, isInitialSpawn: false);
        }
      }
    }
  }

  bool _isNearPlayer(AiSnakeData snake, double range) =>
      snake.position.distanceTo(player.position) < range;

  void _lightPassiveUpdate(AiSnakeData snake, double dt) {
    const speed = 50.0; // Slightly faster passive movement

    // NEW: Passive snakes also move toward center/player area
    final toCenter = (Vector2.zero() - snake.position).normalized() * 0.3;
    final toPlayer = (player.position - snake.position).normalized() * 0.7;
    final combinedDirection = (toCenter + toPlayer).normalized();

    final currentDir = Vector2(cos(snake.angle), sin(snake.angle));
    final newDirection = (currentDir * 0.8 + combinedDirection * 0.2).normalized();

    snake.angle = newDirection.screenAngle();
    snake.position.add(newDirection * speed * dt);

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
    const rotationSpeed = 2.2 * pi; // Faster turning for more responsive AI
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

  // NEW: More realistic AI behavior - like real players
  void _determineAiState(AiSnakeData snake) {
    final pos = snake.position;
    final bounds = SlitherGame.playArea;

    // Priority 1: Avoid boundaries (but less conservative)
    if (!_isInsideBounds(pos, bounds.deflate(200))) { // Reduced from 400
      snake.aiState = AiState.avoiding_boundary;
      return;
    }

    final distToPlayer = pos.distanceTo(player.position);
    final playerRadius = player.playerController.headRadius.value;

    // Priority 2: Food seeking is now higher priority
    final food = _findNearestFood(snake.position, 300); // Increased search range
    if (food != null) {
      // More willing to take risks for food
      final isSafe = _isSafeToSeekFood(snake, food.position);
      if (isSafe || _random.nextDouble() < 0.4) { // 40% chance to risk it
        snake.aiState = AiState.seeking_food;
        return;
      }
    }

    // Priority 3: Player interaction (more aggressive)
    if (distToPlayer < 300) { // Increased interaction range
      final sizeDiff = snake.headRadius - playerRadius;

      if (sizeDiff > 3) { // Reduced size advantage needed
        // More likely to attack
        snake.aiState = (_random.nextDouble() < 0.6) ? AiState.attacking : AiState.chasing;
      } else if (sizeDiff < -3) {
        // More strategic fleeing/defending
        snake.aiState = (_random.nextDouble() < 0.5) ? AiState.fleeing : AiState.defending;
      } else {
        // Similar size - more dynamic behavior
        final behaviors = [AiState.chasing, AiState.defending, AiState.attacking];
        snake.aiState = behaviors[_random.nextInt(behaviors.length)];
      }
      return;
    }

    // Priority 4: Check for AI snake opportunities
    final nearby = _getNearbyThreats(snake);
    if (nearby.isNotEmpty) {
      final biggerThreat = nearby.where((t) => t.headRadius > snake.headRadius + 2);
      final smallerTarget = nearby.where((t) => t.headRadius < snake.headRadius - 2);

      if (smallerTarget.isNotEmpty && _random.nextDouble() < 0.3) {
        // Chase smaller AI snakes
        snake.aiState = AiState.attacking;
        return;
      } else if (biggerThreat.isNotEmpty) {
        snake.aiState = AiState.fleeing;
        return;
      }
    }

    // Priority 5: Seek center/action area
    final distFromCenter = pos.distanceTo(Vector2.zero());
    if (distFromCenter > 800) {
      snake.aiState = AiState.seeking_center;
      return;
    }

    // Default: More active wandering
    snake.aiState = AiState.wandering;
  }

  bool _isSafeToSeekFood(AiSnakeData snake, Vector2 foodPos) {
    // Less conservative food seeking
    for (final other in snakes) {
      if (other == snake || other.isDead) continue;
      if (other.headRadius > snake.headRadius + 3 && // Reduced threat margin
          other.position.distanceTo(foodPos) < 100) { // Reduced danger zone
        return false;
      }
    }

    // Less worried about player unless much bigger
    if (player.playerController.headRadius.value > snake.headRadius + 5 &&
        player.position.distanceTo(foodPos) < 100) {
      return false;
    }

    return true;
  }

  Vector2 _calculateTargetDirection(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.avoiding_boundary:
        return _getBoundaryAvoidDir(snake);
      case AiState.seeking_center:
      // NEW: More direct movement toward center/player area
        final toCenter = (Vector2.zero() - snake.position).normalized() * 0.6;
        final toPlayer = (player.position - snake.position).normalized() * 0.4;
        return (toCenter + toPlayer).normalized();
      case AiState.chasing:
      // More aggressive chasing with prediction
        final pred = player.position + player.playerController.currentDir * 60;
        return (pred - snake.position).normalized();
      case AiState.fleeing:
        return _getFleeDir(snake);
      case AiState.attacking:
      // More sophisticated attacking
        final ahead = player.position + player.playerController.currentDir * 100;
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
    const safe = 400.0; // Reduced safety margin

    if (p.x - b.left < safe) {
      final t = (safe - (p.x - b.left)) / safe;
      force.x += t * t * 2; // Reduced force
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

    // Also flee from other bigger snakes but less drastically
    for (final other in snakes) {
      if (other == snake || other.isDead) continue;
      if (other.headRadius > snake.headRadius + 2 &&
          other.position.distanceTo(snake.position) < 250) {
        flee += (snake.position - other.position).normalized() * 0.3; // Reduced flee force
      }
    }

    return flee.normalized();
  }

  Vector2 _getDefendDir(AiSnakeData snake) {
    final toPlayer = (player.position - snake.position).normalized();
    final perp = Vector2(-toPlayer.y, toPlayer.x);
    final side = (_random.nextDouble() < 0.5 ? 1.0 : -1.0);

    // More dynamic defending - sometimes circle, sometimes retreat
    if (_random.nextDouble() < 0.3) {
      return (perp * side).normalized(); // Circle around
    } else {
      return (perp * side * 0.7 + (-toPlayer) * 0.3).normalized(); // Retreat while circling
    }
  }

  Vector2 _wanderDir(AiSnakeData snake) {
    if (_random.nextDouble() < 0.025) { // More frequent direction changes
      final current = Vector2(cos(snake.angle), sin(snake.angle));
      final turn = (_random.nextDouble() - 0.5) * pi * 0.6; // Larger turns
      final nd = Vector2(
        current.x * cos(turn) - current.y * sin(turn),
        current.x * sin(turn) + current.y * cos(turn),
      );
      return nd.normalized();
    }

    // Stronger bias toward center and player
    final centerBias = (Vector2.zero() - snake.position).normalized() * 0.4;
    final playerBias = (player.position - snake.position).normalized() * 0.3;
    final cur = Vector2(cos(snake.angle), sin(snake.angle)) * 0.3;

    return (cur + centerBias + playerBias).normalized();
  }

  // NEW: More strategic boosting like real players
  void _handleBoostLogic(AiSnakeData snake, double dt) {
    if (snake.boostCooldownTimer > 0) {
      snake.boostCooldownTimer -= dt;
    }

    if (snake.isBoosting) {
      snake.boostDuration -= dt;
      if (snake.boostDuration <= 0 || snake.segmentCount <= AI_INITIAL_SEGMENT_COUNT + 2) {
        snake.isBoosting = false;
        snake.boostCooldownTimer = 2.0; // Shorter cooldown
      }
    }

    if (!snake.isBoosting && snake.boostCooldownTimer <= 0 && snake.segmentCount > AI_INITIAL_SEGMENT_COUNT + 5) {
      final should = _shouldBoost(snake);
      if (should) {
        snake.isBoosting = true;
        snake.boostDuration = 0.5 + _random.nextDouble() * 0.8; // Longer boosts
      }
    }
  }

  bool _shouldBoost(AiSnakeData snake) {
    switch (snake.aiState) {
      case AiState.fleeing:
        return _random.nextDouble() < 0.7; // More likely to boost when fleeing
      case AiState.avoiding_boundary:
        return _random.nextDouble() < 0.5;
      case AiState.attacking:
      case AiState.chasing:
        return _random.nextDouble() < 0.4; // More aggressive boosting
      case AiState.seeking_food:
        return _random.nextDouble() < 0.2; // Sometimes boost for food
      default:
        return _random.nextDouble() < 0.1; // Occasional random boost
    }
  }

  List<AiSnakeData> _getNearbyThreats(AiSnakeData snake) {
    final out = <AiSnakeData>[];
    for (final o in snakes) {
      if (o == snake || o.isDead) continue;
      final d = snake.position.distanceTo(o.position);
      if (d < 300) out.add(o); // Increased awareness range
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

  // FIXED: Spawn replacement snakes with proper separation
  Future<AiSnakeData> spawnNewSnake({Vector2? pos}) async {
    final random = Random();

    Vector2 startPos;
    if (pos != null) {
      startPos = pos;
    } else {
      startPos = _findSeparatedSpawnPosition() ?? Vector2.zero();
    }

    final playerPos = player.position;
    final dir = (playerPos - startPos).normalized(); // Move toward player
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    // Replacement snakes can be larger
    final playerSegments = player.bodySegments.length;
    final minSegments = max(AI_INITIAL_SEGMENT_COUNT, (playerSegments * 0.6).round());
    final maxSegments = (playerSegments * 1.2).round().clamp(AI_INITIAL_SEGMENT_COUNT, 50);
    final segmentCount = minSegments + random.nextInt(max(1, maxSegments - minSegments + 1));

    final snake = AiSnakeData(
        position: startPos,
        skinColors: _getRandomPlayerSkin(),
        targetDirection: dir,
        segmentCount: segmentCount,
        segmentSpacing: 10,
        baseSpeed: 70,
        boostSpeed: 140,
        minRadius: 16,
        maxRadius: 50,
        headSprite: headSprite
    );

    final bonus = (segmentCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (segmentCount - AI_INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    // Build body extending away from player
    for (int i = 0; i < snake.segmentCount; i++) {
      snake.bodySegments.add(startPos - dir * (i * snake.segmentSpacing));
    }
    snake.rebuildBoundingBox();

    snakes.add(snake);
    print('Spawned replacement AI snake with $segmentCount segments moving toward player');
    return snake;
  }

  int get totalSnakeCount => snakes.length;
  int get aliveSnakeCount => snakes.where((s) => !s.isDead).length;
}