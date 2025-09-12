// lib/modules/game/components/player/player_component.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../data/models/food_model.dart';
import '../../../../data/service/haptic_service.dart';
import '../../../../data/service/score_service.dart';
import '../../../../data/service/settings_service.dart';
import '../../../../data/service/audio_service.dart';  // NEW: Import audio service
import '../../controllers/player_controller.dart';
import '../../controllers/home_controller.dart';
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
  final AudioService _audioService = Get.find<AudioService>();  // NEW: Audio service
  final HapticService _hapticService = Get.find<HapticService>();

  // Get username from HomeController
  late final String username;

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

  // Smooth boost animation
  double _currentBoostScale = 1.0;
  double _targetBoostScale = 1.0;
  final double _boostScaleSpeed = 8.0;
  final double _boostScaleMultiplier = 1.12;

  // NEW: Track boost state for audio
  bool _wasBoostingLastFrame = false;

  // Text rendering
  late final TextPaint _namePaint;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    headSprite = await game.loadSprite(settings.selectedHead);

    // Get username from HomeController
    try {
      final homeController = Get.find<HomeController>();
      username = homeController.nicknameController.text.isNotEmpty
          ? homeController.nicknameController.text
          : "Player";
    } catch (e) {
      username = "Player";
    }

    // Initialize text paint for username
    _namePaint = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: Colors.black,
            offset: Offset(1, 1),
          ),
        ],
      ),
    );

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
      _hapticService.grow();

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

    // NEW: Play death sound
    _audioService.playDeath();

    // Strong haptic feedback for death
    _hapticService.death();

    foodManager.scatterFoodFromSnake(position, playerController.headRadius.value, bodySegments.length);

    final currentScore = playerController.foodScore.value;
    if (currentScore > _scoreService.getHighScore()) {
      _scoreService.saveHighScore(currentScore);
    }
    game.overlays.add('revive');
    game.pauseEngine();
  }

  void revive() {
    isDead = false;
    // NEW: Play revive sound
    _audioService.playRevive();
    // Haptic feedback for revive
    _hapticService.revive();
  }

  void onAiSnakeKilled() {
    // NEW: Play kill sound
    _audioService.playKill();
    // Light haptic feedback for AI kill
    _hapticService.kill();
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

    // Smooth boost scale animation
    _targetBoostScale = canBoost ? _boostScaleMultiplier : 1.0;
    _currentBoostScale = _lerpDouble(_currentBoostScale, _targetBoostScale, 1 - exp(-_boostScaleSpeed * dt));

    // NEW: Enhanced boost audio and haptic feedback
    if (canBoost != _wasBoostingLastFrame) {
      if (canBoost) {
        _audioService.playBoostOn();
        _hapticService.boostStart(); // Boost start
      } else {
        _audioService.playBoostOff();
        _hapticService.boostEnd();
      }
      _wasBoostingLastFrame = canBoost;
    }

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

    // Path management for smooth segments
    if (_path.isEmpty || position.distanceTo(_path.first) > 1.5) {
      _path.insert(0, position.clone());
    }

    final baseSpacing = playerController.headRadius.value * 0.55;
    final maxPathLength = (bodySegments.length * baseSpacing * 0.6).round() + 1;
    if (_path.length > maxPathLength) {
      _path.removeRange(maxPathLength, _path.length);
    }

    // Update segments
    for (int i = 0; i < bodySegments.length; i++) {
      final segment = bodySegments[i];

      if (segment.scale < 1.0) {
        segment.scale = min(1.0, segment.scale + dt * _growthSpeed);
      }

      final targetPoint = _getPointOnPathAtDistance((i + 1) * baseSpacing);
      segment.position.lerp(targetPoint, 1 - exp(-25 * dt));
    }

    position.clamp(
        SlitherGame.playArea.topLeft.toVector2(),
        SlitherGame.playArea.bottomRight.toVector2()
    );

    _checkAndConsumeFoodWithAnimation();
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  void _checkAndConsumeFoodWithAnimation() {
    final eatDistSq = (playerController.headRadius.value * playerController.headRadius.value) + 500;
    final candidateFood = <FoodModel>[];

    for (final food in foodManager.eatableFoodList) {
      if (position.distanceToSquared(food.position) < eatDistSq) {
        candidateFood.add(food);
      }
    }

    for (final food in candidateFood) {
      // NEW: Play eat food sound
      _audioService.playEatFood();
      _hapticService.eatFood();

      // Light haptic when eating food
      HapticFeedback.selectionClick();

      foodManager.startConsumingFood(food, position);
      _growSnake(food.growth);
      foodManager.spawnFood(position);
      _addEatingEffect(food);
    }
  }

  void _addEatingEffect(FoodModel food) {
    // Can add visual effects here
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

    final canBoost = playerController.isBoosting.value && bodySegments.length > _minLength;

    final currentHeadRadius = playerController.headRadius.value * _currentBoostScale;
    final currentBodyRadius = playerController.bodyRadius.value * _currentBoostScale;

    // Render body segments from back to front
    for (int i = bodySegments.length - 1; i >= 0; i--) {
      final segment = bodySegments[i];
      final color = playerController.skinColors[i % playerController.skinColors.length];

      final segmentRadius = currentBodyRadius * segment.scale;

      if (canBoost && segment.scale > 0.5) {
        _renderBoostGlow(canvas, segment.position, segmentRadius, color, 1.0);
      }

      _drawSegment(canvas, segment.position, segmentRadius, color);
    }

    if (canBoost) {
      _renderHeadBoostGlow(canvas, position, currentHeadRadius, playerController.skinColors[0], 1.0);
    }

    // Render head sprite
    canvas.save();
    canvas.rotate(headAngle + (pi) + _bobAngle);
    headSprite?.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2.all(currentHeadRadius * 2),
        anchor: Anchor.center
    );
    canvas.restore();

    // RENDER USERNAME below the head
    if (username.isNotEmpty) {
      final textOffset = Offset(0, currentHeadRadius + 15).toVector2();
      _namePaint.render(
        canvas,
        username,
        textOffset,
        anchor: Anchor.topCenter,
      );
    }
  }

  void _renderBoostGlow(Canvas canvas, Vector2 segmentPosition, double radius, Color color, double opacity) {
    final Offset offset = Offset(segmentPosition.x - position.x, segmentPosition.y - position.y);
    final glowRadius = radius * 1.3;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.4 * opacity),
          color.withOpacity(0.1 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: offset, radius: glowRadius));

    canvas.drawCircle(offset, glowRadius, glowPaint);
  }

  void _renderHeadBoostGlow(Canvas canvas, Vector2 headPosition, double radius, Color color, double opacity) {
    final glowRadius = radius * 1.5;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.3 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: glowRadius));

    canvas.drawCircle(Offset.zero, glowRadius, glowPaint);
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