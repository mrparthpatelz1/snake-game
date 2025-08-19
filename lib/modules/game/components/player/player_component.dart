import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/food_model.dart';
import '../../../../data/service/score_service.dart';
import '../../controllers/player_controller.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';

class PlayerComponent extends PositionComponent with HasGameRef<SlitherGame> {
  final PlayerController playerController = Get.find<PlayerController>();
  final FoodManager foodManager;
  final ScoreService _scoreService = ScoreService();

  PlayerComponent({required this.foodManager});

  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  final List<Vector2> _path = [];
  final List<Vector2> bodySegments = [];
  double headAngle = 0.0;

  final Timer _shrinkTimer = Timer(0.1, repeat: true);
  late final int _minLength = playerController.initialSegmentCount;

  bool _isDead = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;

    // Optional head hitbox (you’re doing manual collisions anyway).
    add(CircleHitbox(
      radius: playerController.headRadius.value,
      position: Vector2.zero(),
      anchor: Anchor.center,
    ));

    if (playerController.segmentCount.value < _minLength) {
      playerController.segmentCount.value = _minLength;
    }
    for (int i = 0; i < playerController.segmentCount.value; i++) {
      bodySegments.add(position.clone());
    }
    _path.add(position.clone());
  }

  void _growSnake(int amount) {
    final oldSegmentCount = playerController.segmentCount.value;
    playerController.segmentCount.value += amount;
    for (int i = 0; i < amount; i++) {
      bodySegments.add(bodySegments.isEmpty ? position.clone() : bodySegments.last.clone());
    }
    if (playerController.headRadius.value < playerController.maxRadius) {
      final oldBonus = (oldSegmentCount / 25).floor();
      final newBonus = (playerController.segmentCount.value / 25).floor();
      if (newBonus > oldBonus) {
        final inc = (newBonus - oldBonus).toDouble();
        playerController.headRadius.value =
            (playerController.headRadius.value + inc).clamp(playerController.minRadius, playerController.maxRadius);
        playerController.bodyRadius.value = playerController.headRadius.value;
      }
    }
  }

  void _shrinkSnake() {
    if (bodySegments.length <= _minLength) return;

    final oldSegmentCount = playerController.segmentCount.value;
    playerController.segmentCount.value--;
    bodySegments.removeLast();

    if (playerController.headRadius.value > playerController.minRadius) {
      final oldBonus = (oldSegmentCount / 25).floor();
      final newBonus = (playerController.segmentCount.value / 25).floor();
      if (newBonus < oldBonus) {
        final dec = (oldBonus - newBonus).toDouble();
        playerController.headRadius.value =
            (playerController.headRadius.value - dec).clamp(playerController.minRadius, playerController.maxRadius);
        playerController.bodyRadius.value = playerController.headRadius.value;
      }
    }
  }

  void die() {
    if (_isDead) return;
    _isDead = true;

    for (final segmentPos in bodySegments) {
      foodManager.spawnFoodAt(segmentPos);
    }

    final currentScore = playerController.segmentCount.value;
    if (currentScore > _scoreService.getHighScore()) {
      _scoreService.saveHighScore(currentScore);
    }
    final currentKills = playerController.kills.value;
    if (currentKills > _scoreService.getHighKills()) {
      _scoreService.saveHighKills(currentKills);
    }

    print('>>> Player died. Showing gameOver overlay.');
    game.overlays.add('gameOver');
    game.pauseEngine();

    // Slight delay so overlay has time to mount before we remove the player.
    Future.delayed(const Duration(milliseconds: 100), () {
      removeFromParent();
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead) return;

    _shrinkTimer.update(dt);

    final canBoost = playerController.isBoosting.value &&
        playerController.segmentCount.value > _minLength;
    final currentSpeed = canBoost ? playerController.boostSpeed : playerController.baseSpeed;

    if (canBoost && !_shrinkTimer.isRunning()) {
      _shrinkTimer.onTick = _shrinkSnake;
      _shrinkTimer.start();
    } else if (!canBoost && _shrinkTimer.isRunning()) {
      _shrinkTimer.stop();
    }

    final moveDirection = playerController.targetDirection;
    if (moveDirection != Vector2.zero()) {
      position.add(moveDirection * currentSpeed * dt);
    }

    final targetAngle = playerController.targetDirection.screenAngle();
    const rotationSpeed = 5 * pi;
    final angleDiff = _getAngleDifference(headAngle, targetAngle);
    final rotationAmount = rotationSpeed * dt;
    headAngle = (angleDiff.abs() < rotationAmount)
        ? targetAngle
        : headAngle + rotationAmount * angleDiff.sign;

    if (_path.isEmpty || position.distanceTo(_path.first) > 3.0) {
      _path.insert(0, position.clone());
    }
    for (int i = 0; i < bodySegments.length; i++) {
      final totalDistance = (i + 1) * playerController.segmentSpacing;
      bodySegments[i].setFrom(_getPointOnPathAtDistance(totalDistance));
    }

    position.clamp(
      SlitherGame.playArea.topLeft.toVector2(),
      SlitherGame.playArea.bottomRight.toVector2(),
    );

    final maxPathLength = (bodySegments.length + 5) * 20;
    if (_path.length > maxPathLength) {
      _path.removeRange(maxPathLength, _path.length);
    }

    // Eat food
    final eatDistSq = (playerController.headRadius.value * playerController.headRadius.value) + 500;
    final eatenFood = <FoodData>[];
    for (final food in foodManager.foodList) {
      if (position.distanceToSquared(food.position) < eatDistSq) {
        eatenFood.add(food);
      }
    }
    for (final food in eatenFood) {
      foodManager.removeFood(food);
      _growSnake(food.growth);
      foodManager.spawnFood();
    }
  }

  Vector2 _getPointOnPathAtDistance(double distance) {
    final searchPath = [position, ..._path];
    double distanceTraveled = 0;
    for (int i = 0; i < searchPath.length - 1; i++) {
      final p1 = searchPath[i];
      final p2 = searchPath[i + 1];
      final segmentLength = p1.distanceTo(p2);
      if (distanceTraveled + segmentLength >= distance) {
        final needed = distance - distanceTraveled;
        final direction = (p2 - p1).normalized();
        return p1 + direction * needed;
      }
      distanceTraveled += segmentLength;
    }
    return searchPath.last;
  }

  double _getAngleDifference(double a, double b) {
    var diff = (b - a + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Body
    for (int i = bodySegments.length - 1; i >= 0; i--) {
      final segPos = bodySegments[i];
      final color = playerController.skinColors[i % playerController.skinColors.length];
      _drawSegment(canvas, segPos, playerController.bodyRadius.value, color);
    }
    // Head
    canvas.save();
    canvas.rotate(headAngle);
    _drawSegment(canvas, position, playerController.headRadius.value, playerController.skinColors.first, isHead: true);
    _drawEyes(canvas);
    canvas.restore();
  }

  void _drawSegment(Canvas canvas, Vector2 segPos, double radius, Color color, {bool isHead = false}) {
    final Offset offset = isHead
        ? Offset.zero
        : Offset(segPos.x - position.x, segPos.y - position.y);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.6,
      colors: [color.withOpacity(1.0), color.withOpacity(0.6)],
      stops: const [0.5, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: offset, radius: radius));
    canvas.drawCircle(offset, radius, paint);
  }

  void _drawEyes(Canvas canvas) {
    final headRadius = playerController.headRadius.value;
    final eyeRadius = headRadius * 0.25;
    final pupilRadius = eyeRadius * 0.5;
    final eyeDistance = headRadius * 0.6;

    final rightEyePos = Offset(eyeDistance, -eyeDistance * 0.7);
    canvas.drawCircle(rightEyePos, eyeRadius, _eyePaint);
    canvas.drawCircle(rightEyePos, pupilRadius, _pupilPaint);

    final leftEyePos = Offset(eyeDistance, eyeDistance * 0.7);
    canvas.drawCircle(leftEyePos, eyeRadius, _eyePaint);
    canvas.drawCircle(leftEyePos, pupilRadius, _pupilPaint);
  }
}
