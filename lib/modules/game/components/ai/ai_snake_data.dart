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
  Sprite headSprite;

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

  // --- Death Animation ---
  bool isDead = false;
  double deathAnimationTimer = 0.0;
  double scale = 1.0; // For death shrinking animation
  double opacity = 1.0; // For death fade animation
  double originalScale = 1.0; // Store original scale
  static const double deathAnimationDuration = 0.8; // seconds for death animation

  // NEW: Growth system matching player snake
  int foodScore = 0;       // Total food collected
  final int foodPerSegment = 5;        // Every 5 food -> +1 segment
  final int foodPerRadius = 1000;      // Every 1000 food -> +1 px radius
  int initialSegmentCount = 10;        // Starting segment count

  // --- Misc ---
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
    required this.headSprite,
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

    // NEW: Initialize growth system
    initialSegmentCount = segmentCount;
    foodScore = 0;
  }

  // NEW: Growth method matching player snake
  void growFromFood(int foodValue) {
    foodScore += foodValue;

    // Calculate new segment count based on food score
    final newSegmentCount = initialSegmentCount + (foodScore ~/ foodPerSegment);

    // Add new segments if needed
    if (newSegmentCount > segmentCount) {
      final segmentsToAdd = newSegmentCount - segmentCount;
      for (int i = 0; i < segmentsToAdd; i++) {
        if (bodySegments.isNotEmpty) {
          bodySegments.add(bodySegments.last.clone());
        } else {
          bodySegments.add(position.clone());
        }
      }
      segmentCount = newSegmentCount;
    }

    // Calculate new radius based on food score
    final newRadius = minRadius + (foodScore / foodPerRadius);
    headRadius = newRadius.clamp(minRadius, maxRadius);
    bodyRadius = headRadius - 1.0;

    print('AI Snake grew: foodScore=$foodScore, segments=$segmentCount, radius=${headRadius.toStringAsFixed(1)}');
  }

  // NEW: Get current food score for debugging
  int get currentFoodScore => foodScore;

  // NEW: Get growth progress for debugging
  double get growthProgress => foodScore / foodPerRadius;

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