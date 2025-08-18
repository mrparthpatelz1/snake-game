// lib/app/modules/game/components/player/player_component.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/events.dart';
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

  // The constructor no longer needs the AiManager.
  PlayerComponent({required this.foodManager});

  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  final List<Vector2> _path = [];
  final List<Vector2> bodySegments = [];
  double headAngle = 0.0;

  final Timer _shrinkTimer = Timer(0.1, repeat: true);
  late final int _minLength = playerController.initialSegmentCount;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;

    // Add collision hitbox for the player head
    final headHitbox = CircleHitbox(
      radius: playerController.headRadius.value,
      position: Vector2.zero(),
      anchor: Anchor.center,
    );
    add(headHitbox);

    // Ensure initial body segments are present
    if (playerController.segmentCount.value < _minLength) {
      playerController.segmentCount.value = _minLength;
    }
    for (int i = 0; i < playerController.segmentCount.value; i++) {
      bodySegments.add(position.clone());
    }
    // Initialize path with current position
    _path.add(position.clone());
  }

  void _growSnake(int amount) {
    final oldSegmentCount = playerController.segmentCount.value;
    playerController.segmentCount.value += amount;
    for (int i = 0; i < amount; i++) {
      bodySegments.add(
        bodySegments.isEmpty ? position.clone() : bodySegments.last.clone(),
      );
    }
    if (playerController.headRadius.value < playerController.maxRadius) {
      final oldRadiusBonus = (oldSegmentCount / 25).floor();
      final newRadiusBonus = (playerController.segmentCount.value / 25).floor();
      if (newRadiusBonus > oldRadiusBonus) {
        final radiusIncrease = (newRadiusBonus - oldRadiusBonus).toDouble();
        double newRadius = playerController.headRadius.value + radiusIncrease;
        if (newRadius > playerController.maxRadius) {
          newRadius = playerController.maxRadius;
        }
        playerController.headRadius.value = newRadius;
        playerController.bodyRadius.value = newRadius;
      }
    }
  }

  void _shrinkSnake() {
    if (bodySegments.length > _minLength) {
      final oldSegmentCount = playerController.segmentCount.value;
      playerController.segmentCount.value--;
      bodySegments.removeLast();
      if (playerController.headRadius.value > playerController.minRadius) {
        final oldRadiusBonus = (oldSegmentCount / 25).floor();
        final newRadiusBonus = (playerController.segmentCount.value / 25)
            .floor();
        if (newRadiusBonus < oldRadiusBonus) {
          final radiusDecrease = (oldRadiusBonus - newRadiusBonus).toDouble();
          double newRadius = playerController.headRadius.value - radiusDecrease;
          if (newRadius < playerController.minRadius) {
            newRadius = playerController.minRadius;
          }
          playerController.headRadius.value = newRadius;
          playerController.bodyRadius.value = newRadius;
        }
      }
    }
  }

  // This new method will be called by the AiManager when the player dies.
  void die() {
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
    game.pauseEngine();
    game.overlays.add('gameOver');
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _shrinkTimer.update(dt);

    final bool canBoost =
        playerController.isBoosting.value &&
        playerController.segmentCount.value > _minLength;
    final currentSpeed = canBoost
        ? playerController.boostSpeed
        : playerController.baseSpeed;
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
    if (angleDiff.abs() < rotationAmount) {
      headAngle = targetAngle;
    } else {
      headAngle += rotationAmount * angleDiff.sign;
    }

    if (_path.isEmpty || position.distanceTo(_path.first) > 3.0) {
      _path.insert(0, position.clone());
    }
    for (int i = 0; i < bodySegments.length; i++) {
      final totalDistance = (i + 1) * playerController.segmentSpacing;
      final pointOnPath = _getPointOnPathAtDistance(totalDistance);
      bodySegments[i].setFrom(pointOnPath);
    }
    position.clamp(
      SlitherGame.playArea.topLeft.toVector2(),
      SlitherGame.playArea.bottomRight.toVector2(),
    );
    final maxPathLength = (bodySegments.length + 5) * 20;
    if (_path.length > maxPathLength) {
      _path.removeRange(maxPathLength, _path.length);
    }

    final eatDistance =
        (playerController.headRadius.value *
            playerController.headRadius.value) +
        500;
    final List<FoodData> eatenFood = [];
    for (final food in foodManager.foodList) {
      if (position.distanceToSquared(food.position) < eatDistance) {
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
        final neededDist = distance - distanceTraveled;
        final direction = (p2 - p1).normalized();
        return p1 + direction * neededDist;
      }
      distanceTraveled += segmentLength;
    }
    return searchPath.last;
  }

  double _getAngleDifference(double angle1, double angle2) {
    var diff = (angle2 - angle1 + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (int i = bodySegments.length - 1; i >= 0; i--) {
      final segmentPosition = bodySegments[i];
      final color =
          playerController.skinColors[i % playerController.skinColors.length];
      _drawSegment(
        canvas,
        segmentPosition,
        playerController.bodyRadius.value,
        color,
      );
    }
    canvas.save();
    canvas.rotate(headAngle);
    final headColor = playerController.skinColors.first;
    _drawSegment(
      canvas,
      position,
      playerController.headRadius.value,
      headColor,
      isHead: true,
    );
    _drawEyes(canvas);
    canvas.restore();
  }

  void _drawSegment(
    Canvas canvas,
    Vector2 segmentPosition,
    double radius,
    Color color, {
    bool isHead = false,
  }) {
    final Offset offset = isHead
        ? Offset.zero
        : Offset(
            segmentPosition.x - position.x,
            segmentPosition.y - position.y,
          );
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.6,
      colors: [color.withOpacity(1.0), color.withOpacity(0.6)],
      stops: const [0.5, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: offset, radius: radius),
      );
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
