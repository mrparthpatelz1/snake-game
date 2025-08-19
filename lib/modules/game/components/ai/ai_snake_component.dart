// lib/app/modules/game/components/ai/ai_snake_component.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/food_model.dart';
import '../../controllers/ai_snake_controller.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';

// The buggy `CollisionCallbacks` mixin has been removed.
class AiSnakeComponent extends PositionComponent {
  late final AiSnakeController controller;
  final FoodManager foodManager;
  final PlayerComponent player;
  final List<Color> skinColors;

  AiSnakeComponent({
    required this.foodManager,
    required this.player,
    required this.skinColors,
    required Vector2 position,
  }) : super(position: position);

  // --- State & Config (Managed by the component itself) ---
  int segmentCount = 15;
  final double headRadius = 16.0;
  final double bodyRadius = 15.0;
  final double speed = 120.0;
  late final double segmentSpacing = headRadius * 0.6;

  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  final List<Vector2> _path = [];
  final List<Vector2> _bodySegments = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;

    // Create the controller, passing it all necessary references.
    controller = AiSnakeController(
      foodManager: foodManager,
      player: player,
      self: this,
      skinColors: skinColors,
    );

    // We no longer need a hitbox on the AI snake.
    for (int i = 0; i < segmentCount; i++) {
      final segmentPos = position - Vector2(segmentSpacing * (i + 1), 0);
      _bodySegments.add(segmentPos);
      _path.add(segmentPos);
    }
  }

  void _growSnake(int amount) {
    segmentCount += amount;
    for (int i = 0; i < amount; i++) {
      _bodySegments.add(_bodySegments.last.clone());
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    controller.update(dt); // Update the AI's brain

    // --- Movement Logic ---
    final targetAngle = controller.targetDirection.screenAngle();
    const rotationSpeed = 2 * pi;
    final angleDiff = _getAngleDifference(angle, targetAngle);
    final rotationAmount = rotationSpeed * dt;

    if (angleDiff.abs() < rotationAmount) {
      angle = targetAngle;
    } else {
      angle += rotationAmount * angleDiff.sign;
    }

    final direction = Vector2(cos(angle), sin(angle));
    position.add(direction * speed * dt);

    position.clamp(
      Vector2(SlitherGame.worldBounds.left, SlitherGame.worldBounds.top),
      Vector2(SlitherGame.worldBounds.right, SlitherGame.worldBounds.bottom),
    );

    if (_path.isEmpty || position.distanceTo(_path.first) > 3.0) {
      _path.insert(0, position.clone());
    }

    for (int i = 0; i < _bodySegments.length; i++) {
      final totalDistance = (i + 1) * segmentSpacing;
      final pointOnPath = _getPointOnPathAtDistance(totalDistance);
      _bodySegments[i].setFrom(pointOnPath);
    }

    final maxPathLength = (_bodySegments.length + 5) * 20;
    if (_path.length > maxPathLength) {
      _path.removeRange(maxPathLength, _path.length);
    }

    // --- FAST, MANUAL COLLISION DETECTION ---
    final eatDistance = (headRadius * headRadius) + 500;
    final List<FoodModel> eatenFood = [];

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
    for (int i = _bodySegments.length - 1; i >= 0; i--) {
      final segmentPosition = _bodySegments[i];
      final color = controller.skinColors[i % controller.skinColors.length];
      _drawSegment(canvas, segmentPosition, bodyRadius, color);
    }
    final headColor = controller.skinColors.first;
    _drawSegment(canvas, position, headRadius, headColor, isHead: true);
    _drawEyes(canvas);
  }

  void _drawSegment(Canvas canvas, Vector2 segmentPosition, double radius, Color color, {bool isHead = false}) {
    final Offset offset = isHead ? Offset.zero : Offset(segmentPosition.x - position.x, segmentPosition.y - position.y);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.6,
      colors: [color.withOpacity(1.0), color.withOpacity(0.6)],
      stops: const [0.5, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(Rect.fromCircle(center: offset, radius: radius));
    canvas.drawCircle(offset, radius, paint);
  }

  void _drawEyes(Canvas canvas) {
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