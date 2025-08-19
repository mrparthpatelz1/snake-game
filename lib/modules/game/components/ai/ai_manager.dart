// lib/modules/game/components/ai/ai_manager.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';
import 'ai_snake_data.dart';

class AiManager extends Component with HasGameReference<SlitherGame> {
  final int numberOfSnakes = 30; // Reduced for performance
  final Random _random = Random();
  final FoodManager foodManager;
  final PlayerComponent player;
  final List<AiSnakeData> snakes = [];

  late final List<Rect> _spawnZones;
  int _nextZoneIndex = 0;

  // For batched updates
  int _updateIndex = 0;
  static const int _batchSize = 5;

  AiManager({required this.foodManager, required this.player});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _initializeSpawnZones();
    _spawnAllSnakes();
  }

  @override
  void update(double dt) {
    super.update(dt);

    int total = snakes.length;
    int end = _updateIndex + _batchSize;

    for (int i = 0; i < total; i++) {
      AiSnakeData snake = snakes[i];
      if (i >= _updateIndex && i < end) {
        _updateActiveSnake(snake, dt);
      } else {
        _updatePassiveSnake(snake, dt);
      }
    }

    _updateIndex = end % total;
  }

  void _updatePassiveSnake(AiSnakeData snake, double dt) {
    // Move forward only
    final dir = Vector2(cos(snake.angle), sin(snake.angle));
    final mv = dir * snake.speed * dt;
    snake.position.add(mv);
    for (final seg in snake.bodySegments) {
      seg.add(mv);
    }
    // Hard clamp
    _enforceHardBoundaries(snake);
  }

  void _updateActiveSnake(AiSnakeData snake, double dt) {
    snake.savePreviousPosition();
    _determineAiState(snake);
    Vector2 target = _calculateTargetDirection(snake);
    snake.targetDirection = target;
    _moveSnakeSmooth(snake, dt);
    _updateSnakeBody(snake);
    _checkFoodConsumption(snake);
  }

  void _determineAiState(AiSnakeData s) {
    Vector2 pos = s.position;
    final bounds = SlitherGame.playArea;
    if (!_isInsideBounds(pos, bounds.deflate(200))) {
      s.aiState = AiState.avoiding_boundary;
      return;
    }
    final distCenter = pos.distanceTo(Vector2.zero());
    final worldSize = min(
      SlitherGame.worldBounds.width,
      SlitherGame.worldBounds.height,
    );
    if (distCenter > worldSize * 0.3) {
      s.aiState = AiState.seeking_center;
      return;
    }
    final dPlayer = pos.distanceTo(player.position);
    if (dPlayer < 500) {
      if (s.segmentCount > player.bodySegments.length + 3) {
        s.aiState = AiState.chasing;
      } else if (s.segmentCount < player.bodySegments.length - 3) {
        s.aiState = AiState.fleeing;
      } else {
        s.aiState = AiState.wandering;
      }
      return;
    }
    s.aiState = AiState.wandering;
  }

  Vector2 _calculateTargetDirection(AiSnakeData s) {
    switch (s.aiState) {
      case AiState.avoiding_boundary:
        return _getBoundaryAvoidanceDirection(s);
      case AiState.seeking_center:
        return _getCenterSeekingDirection(s);
      case AiState.chasing:
        return _getChaseDirection(s);
      case AiState.fleeing:
        return _getFleeDirection(s);
      case AiState.wandering:
        return _getWanderDirection(s);
    }
  }

  Vector2 _getBoundaryAvoidanceDirection(AiSnakeData s) {
    final pos = s.position;
    final b = SlitherGame.playArea;
    Vector2 force = Vector2.zero();
    const safe = 800.0;
    if (pos.x - b.left < safe) {
      force.x += pow((safe - (pos.x - b.left)) / safe, 2);
    }
    if (b.right - pos.x < safe) {
      force.x -= pow((safe - (b.right - pos.x)) / safe, 2);
    }
    if (pos.y - b.top < safe) {
      force.y += pow((safe - (pos.y - b.top)) / safe, 2);
    }
    if (b.bottom - pos.y < safe) {
      force.y -= pow((safe - (b.bottom - pos.y)) / safe, 2);
    }
    if (force.length < 0.1) {
      force = (Vector2.zero() - pos).normalized();
    }
    return force.normalized();
  }

  Vector2 _getCenterSeekingDirection(AiSnakeData s) {
    final dir = (Vector2.zero() - s.position).normalized();
    final rnd = Vector2(
      (_random.nextDouble() - 0.5) * 0.3,
      (_random.nextDouble() - 0.5) * 0.3,
    );
    return (dir + rnd).normalized();
  }

  Vector2 _getChaseDirection(AiSnakeData s) {
    final toPlayer = (player.position - s.position).normalized();
    final predPos =
        player.position + player.playerController.targetDirection * 50;
    final toPred = (predPos - s.position).normalized();
    return (toPlayer * 0.7 + toPred * 0.3).normalized();
  }

  Vector2 _getFleeDirection(AiSnakeData s) {
    final flee = (s.position - player.position).normalized();
    final perp = Vector2(-flee.y, flee.x);
    final rnd = perp * ((_random.nextDouble() - 0.5) * 0.4);
    return (flee + rnd).normalized();
  }

  Vector2 _getWanderDirection(AiSnakeData s) {
    final food = _findNearestFood(s.position, 300);
    if (food != null) {
      return (food.position - s.position).normalized();
    }
    if (_random.nextDouble() < 0.008) {
      final cd = Vector2(cos(s.angle), sin(s.angle));
      final turn = (_random.nextDouble() - 0.5) * pi * 0.6;
      final nd = Vector2(
        cd.x * cos(turn) - cd.y * sin(turn),
        cd.x * sin(turn) + cd.y * cos(turn),
      );
      return nd.normalized();
    }
    final cd = Vector2(cos(s.angle), sin(s.angle));
    final bias = (Vector2.zero() - s.position).normalized() * 0.1;
    return (cd + bias).normalized();
  }

  void _moveSnakeSmooth(AiSnakeData s, double dt) {
    final tgt = s.targetDirection.screenAngle();
    final cur = s.angle;
    final diff = _normalizeAngle(tgt - cur);
    final base = 2.5 * pi;
    final um = s.aiState == AiState.avoiding_boundary ? 2.0 : 1.0;
    final rs = base * um;
    final rot = rs * dt;
    s.angle = diff.abs() <= rot ? tgt : cur + rot * diff.sign;
    final mv = Vector2(cos(s.angle), sin(s.angle)) * s.speed * dt;
    s.position.add(mv);
    _enforceHardBoundaries(s);
  }

  double _normalizeAngle(double angle) {
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    return angle;
  }

  void _enforceHardBoundaries(AiSnakeData s) {
    final b = SlitherGame.playArea;
    if (s.position.x < b.left) s.position.x = b.left;
    if (s.position.x > b.right) s.position.x = b.right;
    if (s.position.y < b.top) s.position.y = b.top;
    if (s.position.y > b.bottom) s.position.y = b.bottom;
    final centerDir = (Vector2.zero() - s.position).normalized();
    s.targetDirection = centerDir;
    s.angle = centerDir.screenAngle();
  }

  bool _isInsideBounds(Vector2 p, Rect r) =>
      p.x >= r.left && p.x <= r.right && p.y >= r.top && p.y <= r.bottom;

  void _updateSnakeBody(AiSnakeData s) {
    if (s.path.isEmpty ||
        s.position.distanceTo(s.path.first) > 2) {
      s.path.insert(0, s.position.clone());
    }
    for (int i = 0; i < s.bodySegments.length; i++) {
      final d = (i + 1) * s.segmentSpacing;
      s.bodySegments[i].setFrom(_getPointOnPath(s, d));
    }
    final maxLen = s.bodySegments.length * 3 + 20;
    if (s.path.length > maxLen) {
      s.path.removeRange(maxLen, s.path.length);
    }
  }

  Vector2 _getPointOnPath(AiSnakeData s, double dist) {
    final path = [s.position, ...s.path];
    double acc = 0;
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i], p2 = path[i + 1];
      final segLen = p1.distanceTo(p2);
      if (acc + segLen >= dist) {
        final need = dist - acc;
        return p1 + (p2 - p1).normalized() * need;
      }
      acc += segLen;
    }
    return path.last.clone();
  }

  void _checkFoodConsumption(AiSnakeData snake) {
    final eatRadius = snake.headRadius + 10.0;
    final region = Rect.fromCircle(
      center: snake.position.toOffset(),
      radius: eatRadius + 100,
    );

    final candidates = foodManager.foodList.where(
            (food) => region.contains(food.position.toOffset()));
    for (final food in candidates) {
      if (snake.position.distanceToSquared(food.position) <= eatRadius * eatRadius) {
        foodManager.removeFood(food);
        _growSnake(snake, food.growth);
        foodManager.spawnFood();
      }
    }
  }

  FoodModel? _findNearestFood(Vector2 p, double md) {
    FoodModel? nearest;
    double best = md * md;
    for (final f in foodManager.foodList) {
      final ds = p.distanceToSquared(f.position);
      if (ds < best) {
        nearest = f;
        best = ds;
      }
    }
    return nearest;
  }

  void _initializeSpawnZones() {
    const margin = 200.0;
    final bounds = SlitherGame.worldBounds.deflate(margin);
    final gridSize = (sqrt(numberOfSnakes)).ceil();
    final w = bounds.width / gridSize;
    final h = bounds.height / gridSize;

    _spawnZones = List.generate(gridSize * gridSize, (i) {
      final row = i ~/ gridSize;
      final col = i % gridSize;
      return Rect.fromLTWH(
        bounds.left + col * w,
        bounds.top + row * h,
        w,
        h,
      );
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

    final initCount = 8 + _random.nextInt(12);
    final snakeData = AiSnakeData(
      position: pos,
      skinColors: _getRandomSkin(),
      targetDirection: Vector2.random(_random).normalized(),
      segmentCount: initCount,
      segmentSpacing: 13.0 * 0.6,
      speed: 80.0 + _random.nextDouble() * 40.0,
      minRadius: 12.0,
      maxRadius: 40.0,
    );

    final bonus = (initCount / 25).floor().toDouble();
    snakeData.headRadius =
        (12.0 + bonus).clamp(snakeData.minRadius, snakeData.maxRadius);
    snakeData.bodyRadius = snakeData.headRadius - 1.0;

    snakeData.bodySegments.clear();
    snakeData.path.clear();
    for (int i = 0; i < initCount; i++) {
      final offset = snakeData.targetDirection *
          snakeData.segmentSpacing *
          (i + 1);
      final sPos = pos - offset;
      snakeData.bodySegments.add(sPos.clone());
      snakeData.path.add(sPos.clone());
    }

    snakeData.aiState = AiState.wandering;
    snakes.add(snakeData);
  }

  void _growSnake(AiSnakeData s, int amt) {
    final old = s.segmentCount;
    s.segmentCount += amt;
    for (int i = 0; i < amt; i++) {
      s.bodySegments.add(s.bodySegments.last.clone());
    }
    final oldB = (old / 25).floor();
    final newB = (s.segmentCount / 25).floor();
    if (newB > oldB) {
      final inc = (newB - oldB).toDouble();
      s.headRadius =
          (s.headRadius + inc).clamp(s.minRadius, s.maxRadius);
      s.bodyRadius = s.headRadius - 1.0;
    }
  }

  void killSnakeAndScatterFood(AiSnakeData s) {

    for (final seg in s.bodySegments) {
      // Each segment drops 2–4 pellets
      int pelletCount = 2 + _random.nextInt(3);

      for (int i = 0; i < pelletCount; i++) {
        // Random scatter radius (based on snake body size)
        double radius = s.bodyRadius * (0.5 + _random.nextDouble());

        // Random angle around the segment
        double angle = _random.nextDouble() * 2 * pi;

        final offset = Vector2(
          seg.x + cos(angle) * radius,
          seg.y + sin(angle) * radius,
        );

        foodManager.spawnFoodAt(offset);
      }
    }
    foodManager.spawnFoodAt(s.position);

    snakes.remove(s);
  }

  void spawnNewSnake() => _spawnSnake();

  List<Color> _getRandomSkin() {
    final b = _random.nextDouble() * 360;
    return List.generate(6, (i) {
      final h = (b + i * 15) % 360;
      return HSVColor.fromAHSV(1, h, 0.8, 0.9).toColor();
    });
  }
}
