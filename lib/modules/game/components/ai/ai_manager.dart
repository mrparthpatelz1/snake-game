import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../../views/game_screen.dart';               // SlitherGame
import '../food/food_manager.dart';                  // your FoodManager
import '../player/player_component.dart';            // PlayerComponent
import 'ai_snake_data.dart';

class AiManager extends Component with HasGameReference<SlitherGame> {
  final Random _random = Random();

  final FoodManager foodManager;
  final PlayerComponent player;

  final int numberOfSnakes; // initial world count
  final List<AiSnakeData> snakes = [];

  // spawn grid (initial world placement)
  late final List<Rect> _spawnZones;
  int _nextZoneIndex = 0;

  int _nextId = 0;

  AiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 0,
  });

  // ========= Lifecycle =========

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _initializeSpawnZones();
    _spawnAllSnakes();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Expand visible area to “wake up” earlier
    final visibleRect = game.cameraComponent.visibleWorldRect.inflate(400);

    int activeCount = 0;
    int passiveCount = 0;

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

    // Cleanup dead + drop food
    final dead = snakes.where((s) => s.isDead).toList();
    for (final s in dead) {
      killSnakeAndScatterFood(s);
    }

    // Keep ~15+ around player; spawn off-screen only
    _ensureMinSnakesAroundPlayer();

    debugPrint(
      "Active: $activeCount | Passive: $passiveCount | Total: ${snakes.length}",
    );
  }

  void _updateSnakeMovement(AiSnakeData snake, double dt) {
    final moveSpeed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;

    // move in the current heading (whatever it is)
    final moveDir = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position += moveDir * moveSpeed * dt;

    // --- update body segments flow ---
    // Insert new head position at front
    snake.bodySegments.insert(0, snake.position.clone());

    // Keep only the allowed number of segments
    while (snake.bodySegments.length > snake.segmentCount) {
      snake.bodySegments.removeLast();
    }

    // --- bounding box update ---
    snake.rebuildBoundingBox();
  }

  // ========= Spawning =========

  void _initializeSpawnZones() {
    const m = 300.0;
    final b = SlitherGame.worldBounds.deflate(m);
    final grid = (sqrt(numberOfSnakes)).ceil();
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
    final zone = _spawnZones[_nextZoneIndex++ % _spawnZones.length];
    final x = zone.left + _random.nextDouble() * zone.width;
    final y = zone.top + _random.nextDouble() * zone.height;
    final pos = Vector2(x, y);

    _spawnSnakeAt(pos);
  }

  void _spawnSnakeAt(Vector2 pos) {
    final initCount = 12 + _random.nextInt(18); // 12..29
    final baseSpeed = 60.0 + _random.nextDouble() * 25.0;

    final snake = AiSnakeData(
      position: pos,
      skinColors: _getRandomSkin(),
      targetDirection: Vector2.random(_random).normalized(),
      segmentCount: initCount,
      segmentSpacing: 13.0 * 0.6,
      baseSpeed: baseSpeed,
      boostSpeed: baseSpeed * 1.6,
      minRadius: 12.0,
      maxRadius: 40.0,
    );

    final bonus = (initCount / 25).floor().toDouble();
    snake.headRadius = (12.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;

    // Build body + initial path
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

  void _ensureMinSnakesAroundPlayer() {
    const minActive = 15;
    const spawnRadius = 900.0;
    const safeZone = 420.0;
    const offscreenMargin = 60.0;

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius);

    if (near.length >= minActive) return;

    final need = minActive - near.length;
    final visible = game.cameraComponent.visibleWorldRect.inflate(offscreenMargin);

    for (int i = 0; i < need; i++) {
      final ang = _random.nextDouble() * pi * 2;
      final dist = safeZone + _random.nextDouble() * (spawnRadius - safeZone);
      final spawnPos = player.position + Vector2(cos(ang), sin(ang)) * dist;

      if (!visible.contains(spawnPos.toOffset())) {
        _spawnSnakeAt(spawnPos);
      }
    }
  }

  // ========= Updates =========

  bool _isNearPlayer(AiSnakeData snake, double range) =>
      snake.position.distanceTo(player.position) < range;

  void _lightPassiveUpdate(AiSnakeData snake, double dt) {
    const speed = 40.0;
    final dir = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(dir * speed * dt);

    // Body follow (coarse)
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

    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  void _updateActiveSnake(AiSnakeData snake, double dt) {
    _determineAiState(snake);
    _handleBoostLogic(snake, dt);

    // Compute desired direction from AI
    final desired = _calculateTargetDirection(snake);
    if (desired.length2 > 0) {
      snake.targetDirection = desired.normalized();
    }

    // Rotate toward desired
    final targetAngle = snake.targetDirection.screenAngle();
    const rotationSpeed = 2 * pi;
    final diff = _getAngleDiff(snake.angle, targetAngle);
    final delta = rotationSpeed * dt;
    snake.angle += (diff.abs() < delta) ? diff : delta * diff.sign;

    // Move
    final speed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;
    final forward = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(forward * speed * dt);

    // Body follow (smooth)
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

    _checkFoodConsumption(snake);
    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  // ========= AI logic =========

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
        snake.aiState =
        (_random.nextDouble() < 0.75) ? AiState.attacking : AiState.wandering;
        return;
      } else if (snake.headRadius < playerRadius - 2) {
        // small can still attack sometimes
        if (_random.nextDouble() < 0.5) {
          snake.aiState = AiState.attacking;
        } else {
          snake.aiState = (distToPlayer < 200 && _random.nextDouble() < 0.35)
              ? AiState.defending
              : AiState.fleeing;
        }
        return;
      } else {
        // similar size
        if (snake.segmentCount > playerSegments + 5) {
          snake.aiState = AiState.chasing;
        } else if (snake.segmentCount < playerSegments - 5) {
          snake.aiState = AiState.defending;
        } else {
          snake.aiState =
          (_random.nextBool()) ? AiState.attacking : AiState.wandering;
        }
        return;
      }
    }

    // other snakes
    final nearby = _getNearbyThreats(snake);
    if (nearby.isNotEmpty) {
      final biggerThreat =
      nearby.any((t) => t.headRadius > snake.headRadius + 1);
      final smallerPrey =
      nearby.where((t) => t.headRadius < snake.headRadius - 1);

      if (biggerThreat) {
        snake.aiState = AiState.fleeing;
        return;
      } else if (smallerPrey.isNotEmpty && snake.segmentCount > 15) {
        snake.aiState = AiState.attacking;
        return;
      }
    }

    // food
    final food = _findNearestFood(pos, 300);
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

  // ========= Behaviours (directions) =========

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

    // add little perpendicular evasion
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
    // small random changes
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

  // ========= Boosts =========

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

  // ========= Helpers =========

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

  // ========= Food =========

  void _checkFoodConsumption(AiSnakeData snake) {
    final eR = snake.headRadius + 15;
    final eatRadiusSquared = eR * eR;

    final candidates = foodManager.foodList.where((food) {
      final ds = snake.position.distanceToSquared(food.position);
      return ds <= eatRadiusSquared;
    }).toList();

    for (final food in candidates) {
      foodManager.removeFood(food);
      _growSnake(snake, food.growth);
      foodManager.spawnFood(snake.position);
    }
  }

  void _growSnake(AiSnakeData snake, int amt) {
    final old = snake.segmentCount;
    snake.segmentCount += amt;
    for (int i = 0; i < amt; i++) {
      snake.bodySegments.add(snake.bodySegments.last.clone());
    }
    final oldB = (old / 25).floor();
    final newB = (snake.segmentCount / 25).floor();
    if (newB > oldB) {
      final inc = (newB - oldB).toDouble();
      snake.headRadius = (snake.headRadius + inc).clamp(snake.minRadius, snake.maxRadius);
      snake.bodyRadius = snake.headRadius - 1.0;
    }
  }

  void killSnakeAndScatterFood(AiSnakeData snake) {
    for (int i = 0; i < snake.bodySegments.length; i += 2) {
      foodManager.spawnFoodAt(snake.bodySegments[i]);
    }
    foodManager.spawnFoodAt(snake.position);
    snakes.remove(snake);
  }

  // ========= Food search =========

  // NOTE: this depends on your existing FoodModel & FoodManager
  dynamic _findNearestFood(Vector2 p, double maxDist) {
    dynamic nearest;
    double best = maxDist * maxDist;
    for (final f in foodManager.foodList) {
      final ds = p.distanceToSquared(f.position);
      if (ds < best) {
        nearest = f;
        best = ds;
      }
    }
    return nearest;
  }

  Color _randomSnakeColor() {
    final colors = [Colors.green, Colors.red, Colors.blue, Colors.yellow, Colors.purple];
    return colors[Random().nextInt(colors.length)];
  }


  AiSnakeData spawnNewSnake({Vector2? pos}) {
    final random = Random();
    final world = game.cameraComponent.visibleWorldRect;

    final startPos = pos ??
        Vector2(
          random.nextDouble() * world.width,
          random.nextDouble() * world.height,
        );

    final dir = (Vector2.random(random) - Vector2(0.5, 0.5)).normalized();

    final snake = AiSnakeData(
      position: startPos,
      skinColors: [_randomSnakeColor()],
      targetDirection: dir,
      segmentCount: 20 + random.nextInt(10),
      segmentSpacing: 10,
      baseSpeed: 80,
      boostSpeed: 140,
      minRadius: 8,
      maxRadius: 18,
    );

    for (int i = 0; i < snake.segmentCount; i++) {
      snake.bodySegments.add(startPos - dir * (i * snake.segmentSpacing));
    }
    snake.rebuildBoundingBox();

    snakes.add(snake);
    return snake;
  }




  // ========= Cosmetics =========

  List<Color> _getRandomSkin() {
    final base = _random.nextDouble() * 360;
    return List.generate(6, (i) {
      final h = (base + i * 15) % 360;
      return HSVColor.fromAHSV(1, h, 0.8, 0.9).toColor();
    });
  }
}
