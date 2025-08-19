import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'ai_manager.dart';

class AiSnakeData {
  Vector2 position;
  double angle = 0.0;
  final List<Vector2> bodySegments = [];
  final List<Color> skinColors;
  Vector2 targetDirection;
  final List<Vector2> path = [];

  Rect boundingBox = Rect.zero;

  String gridKey = '';

  double headRadius;
  double bodyRadius;
  final double segmentSpacing;
  double speed;
  int segmentCount;
  final double minRadius;
  double maxRadius;
  late AiDifficulty difficulty;

  AiSnakeData({
    required this.position,
    required this.skinColors,
    required this.targetDirection,
    required this.headRadius,
    required this.bodyRadius,
    required this.segmentSpacing,
    required this.speed,
    required this.segmentCount,
    required this.minRadius,
    required this.maxRadius,
  });
}
