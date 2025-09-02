import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Keep the same states you already use elsewhere
enum AiState {
  avoiding_boundary,
  seeking_center,
  chasing,
  fleeing,
  attacking,
  defending,
  seeking_food,
  wandering,
}

class AiSnakeData {
  // --- Core ---
  Vector2 position;
  double angle; // radians (0 right, pi/2 down if using screenAngle)
  Vector2 targetDirection; // normalized target dir
  List<Vector2> bodySegments = [];
  List<Vector2> path = [];

  // --- Sizes & look ---
  double headRadius;
  double bodyRadius;
  double minRadius;
  double maxRadius;
  List<Color> skinColors;

  // --- Movement ---
  int segmentCount;
  double segmentSpacing;
  double baseSpeed;
  double boostSpeed;

  // --- AI ---
  AiState aiState = AiState.wandering;

  // --- Boost ---
  bool isBoosting = false;
  double boostDuration = 0.0;
  double boostCooldownTimer = 0.0;

  // --- Misc ---
  bool isDead = false;
  Rect boundingBox = const Rect.fromLTWH(0, 0, 0, 0);

  AiSnakeData({
    required this.position,
    required this.skinColors,
    required this.targetDirection,
    required this.segmentCount,
    required this.segmentSpacing,
    required this.baseSpeed,
    required this.boostSpeed,
    required this.minRadius,
    required this.maxRadius,
    double? headRadius,
    this.angle = 0.0,
  })  : headRadius = headRadius ?? minRadius,
        bodyRadius = (headRadius ?? minRadius) - 1.0 {
    // Normalize direction
    if (targetDirection.length2 == 0) {
      targetDirection = Vector2(1, 0);
    } else {
      targetDirection.normalize();
    }
    angle = targetDirection.screenAngle();
  }

  /// Convenience to (re)compute bounding box from head + segments
  void rebuildBoundingBox() {
    double minX = position.x, maxX = position.x;
    double minY = position.y, maxY = position.y;

    for (final seg in bodySegments) {
      if (seg.x < minX) minX = seg.x;
      if (seg.x > maxX) maxX = seg.x;
      if (seg.y < minY) minY = seg.y;
      if (seg.y > maxY) maxY = seg.y;
    }
    boundingBox = Rect.fromLTRB(minX - 32, minY - 32, maxX + 32, maxY + 32);
  }
}
