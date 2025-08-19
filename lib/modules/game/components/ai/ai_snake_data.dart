// lib/modules/game/components/ai/ai_snake_data.dart

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum AiDifficulty { easy, medium, hard }

enum AiState { wandering, chasing, fleeing, avoiding_boundary, seeking_center }

class AiSnakeData {
  Vector2 position;
  double angle = 0.0;
  final List<Vector2> bodySegments = [];
  final List<Color> skinColors;
  Vector2 targetDirection;
  final List<Vector2> path = [];

  Rect boundingBox = Rect.zero;

  double headRadius = 0;
  double bodyRadius = 0;
  final double segmentSpacing;
  double speed;
  int segmentCount;
  final double minRadius;
  double maxRadius;

  late AiDifficulty difficulty;
  late AiState aiState;

  AiSnakeData({
    required this.position,
    required this.skinColors,
    required this.targetDirection,
    required this.segmentSpacing,
    required this.speed,
    required this.segmentCount,
    required this.minRadius,
    required this.maxRadius,
  }) {
    aiState = AiState.wandering;
  }
}
