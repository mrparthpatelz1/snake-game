// lib/modules/game/components/player/player_component.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/food_model.dart';
import '../../../../data/service/score_service.dart';
import '../../../../data/service/settings_service.dart';
import '../../controllers/player_controller.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';

class BodySegment {
  Vector2 position;
  double scale;
  BodySegment(this.position, {this.scale = 1.0});
}

class PlayerComponent extends PositionComponent with HasGameRef<SlitherGame> {
  final PlayerController playerController = Get.find<PlayerController>();
  final FoodManager foodManager;
  final ScoreService _scoreService = ScoreService();
  final SettingsService settings = Get.find<SettingsService>();

  PlayerComponent({required this.foodManager}) : super();

  Sprite? headSprite;
  final List<BodySegment> bodySegments = [];
  double headAngle = 0.0;
  final Timer _shrinkTimer = Timer(0.1, repeat: true);
  late final int _minLength = playerController.initialSegmentCount;
  bool isDead = false;

  final double _headBobFrequency = 10.0;
  final double _headBobAmplitude = 0.08;
  double _bobAngle = 0.0;
  final double _growthSpeed = 5.0;
  double _elapsedTime = 0.0;

  final List<Vector2> _path = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    headSprite = await game.loadSprite(settings.selectedHead);
    add(CircleHitbox(
        radius: playerController.headRadius.value,
        position: Vector2.zero(),
        anchor: Anchor.center
    ));

    for (int i = 0; i < playerController.initialSegmentCount; i++) {
      bodySegments.add(BodySegment(position.clone()));
    }
  }

  void _growSnake(int amount) {
    playerController.foodScore.value += amount;
    final newSegments = (playerController.foodScore.value ~/ playerController.foodPerSegment) -
        (playerController.segmentCount.value - playerController.initialSegmentCount);

    if (newSegments > 0) {
      playerController.segmentCount.value += newSegments;
      for (int i = 0; i < newSegments; i++) {
        bodySegments.add(BodySegment(bodySegments.last.position.clone(), scale: 0.0));
      }
    }

    final desiredRadius = playerController.minRadius +
        (playerController.foodScore.value / playerController.foodPerRadius);
    playerController.headRadius.value = desiredRadius.clamp(
        playerController.minRadius,
        playerController.maxRadius
    );
    playerController.bodyRadius.value = playerController.headRadius.value;
  }

  void _shrinkSnake() {
    if (bodySegments.length <= _minLength) return;
    playerController.segmentCount.value--;
    playerController.foodScore.value -= playerController.foodPerSegment;
    if (playerController.foodScore.value < 0) playerController.foodScore.value = 0;
    bodySegments.removeLast();

    final desiredRadius = playerController.minRadius +
        (playerController.foodScore.value / playerController.foodPerRadius);
    playerController.headRadius.value = desiredRadius.clamp(
        playerController.minRadius,
        playerController.maxRadius
    );
    playerController.bodyRadius.value = playerController.headRadius.value;
  }

  void die() {
    if (isDead) return;
    isDead = true;
    for (final segment in bodySegments) {
      foodManager.spawnFoodAt(segment.position);
    }
    final currentScore = playerController.foodScore.value;
    if (currentScore > _scoreService.getHighScore()) {
      _scoreService.saveHighScore(currentScore);
    }
    game.overlays.add('revive');
    game.pauseEngine();
  }

  void revive() {
    isDead = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;
    _elapsedTime += dt;

    final canBoost = playerController.isBoosting.value && bodySegments.length > _minLength;
    final currentSpeed = canBoost ? playerController.boostSpeed : playerController.baseSpeed;
    final currentBobFrequency = canBoost ? _headBobFrequency * 2.0 : _headBobFrequency;
    _bobAngle = sin(_elapsedTime * currentBobFrequency) * _headBobAmplitude;

    _shrinkTimer.update(dt);
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

    // Path-following logic
    if (_path.isEmpty || position.distanceTo(_path.first) > 4.0) {
      _path.insert(0, position.clone());
    }

    final maxPathLength = bodySegments.length * 10 + 1;
    if (_path.length > maxPathLength) {
      _path.removeRange(maxPathLength, _path.length);
    }

    for (int i = 0; i < bodySegments.length; i++) {
      final segment = bodySegments[i];
      if (segment.scale < 1.0) {
        segment.scale = min(1.0, segment.scale + dt * _growthSpeed);
      }

      final targetPoint = _getPointOnPathAtDistance((i + 1) * playerController.segmentSpacing);
      segment.position.lerp(targetPoint, 1 - exp(-25 * dt));
    }

    position.clamp(
        SlitherGame.playArea.topLeft.toVector2(),
        SlitherGame.playArea.bottomRight.toVector2()
    );

    // Enhanced food consumption with animation
    _checkAndConsumeFoodWithAnimation();
  }

  void _checkAndConsumeFoodWithAnimation() {
    final eatDistSq = (playerController.headRadius.value * playerController.headRadius.value) + 500;
    final candidateFood = <FoodModel>[];

    // Check only eatable food (not already being consumed)
    for (final food in foodManager.eatableFoodList) {
      if (position.distanceToSquared(food.position) < eatDistSq) {
        candidateFood.add(food);
      }
    }

    // Start consumption animation for each food item
    for (final food in candidateFood) {
      foodManager.startConsumingFood(food, position);
      _growSnake(food.growth);

      // Spawn new food to replace the one being consumed
      foodManager.spawnFood(position);

      // Optional: Add some visual feedback or sound effect here
      _addEatingEffect(food);
    }
  }

  void _addEatingEffect(FoodModel food) {
    // You can add additional effects here like:
    // - Screen shake
    // - Particle effects
    // - Sound effects
    // - Score popup animations

    // For now, just a simple debug print
    print('Player consuming food worth ${food.growth} points!');
  }

  Vector2 _getPointOnPathAtDistance(double distance) {
    if (_path.isEmpty) return position.clone();

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

  double _getAngleDifference(double a, double b) {
    var diff = (b - a + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (int i = bodySegments.length - 1; i >= 0; i--) {
      final segment = bodySegments[i];
      final color = playerController.skinColors[i % playerController.skinColors.length];
      _drawSegment(canvas, segment.position, playerController.bodyRadius.value * segment.scale, color);
    }
    canvas.save();
    canvas.rotate(headAngle + (pi) + _bobAngle);
    headSprite?.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2.all(playerController.headRadius.value * 2),
        anchor: Anchor.center
    );
    canvas.restore();
  }

  void _drawSegment(Canvas canvas, Vector2 segmentPosition, double radius, Color color) {
    if (radius < 1.0) return;
    final Offset offset = Offset(segmentPosition.x - position.x, segmentPosition.y - position.y);
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
}