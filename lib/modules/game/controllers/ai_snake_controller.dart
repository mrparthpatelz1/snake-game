// lib/app/modules/game/controllers/ai_snake_controller.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../data/models/food_model.dart';
import '../components/food/food_manager.dart';
import '../components/player/player_component.dart';
import '../components/ai/ai_snake_component.dart';

// The different states the AI can be in.
enum AiState { wandering, huntingFood, huntingPlayer, fleeing }

class AiSnakeController {
  final FoodManager foodManager;
  final PlayerComponent player;
  final AiSnakeComponent self; // A reference to the AiSnakeComponent itself

  Vector2 targetDirection = Vector2(-1, 0)..rotate(Random().nextDouble() * 2 * pi);
  final List<Color> skinColors;
  AiState currentState = AiState.wandering;

  final Timer _wanderTimer = Timer(3, repeat: true, autoStart: false);
  final Random _random = Random();
  final double _visionRadius = 600.0; // AI can see further now

  AiSnakeController({
    required this.foodManager,
    required this.player,
    required this.self,
    required this.skinColors,
  }) {
    _wanderTimer.onTick = _wander;
    _wanderTimer.start();
  }

  void update(double dt) {
    _wanderTimer.update(dt);

    // --- ADVANCED AI DECISION MAKING ---
    final distanceToPlayer = self.position.distanceTo(player.position);

    if (distanceToPlayer < _visionRadius) {
      // If we can see the player, decide whether to hunt or flee.
      if (self.segmentCount > player.playerController.segmentCount.value) {
        // We are bigger, so we hunt the player.
        currentState = AiState.huntingPlayer;
        targetDirection = (player.position - self.position).normalized();
        _wanderTimer.stop();
        return; // Decision made, exit the update.
      } else {
        // We are smaller, so we flee from the player.
        currentState = AiState.fleeing;
        targetDirection = (self.position - player.position).normalized();
        _wanderTimer.stop();
        return; // Decision made, exit the update.
      }
    }

    // If the player is not a concern, look for food.
    final closestFood = _findClosestFood();
    if (closestFood != null) {
      currentState = AiState.huntingFood;
      targetDirection = (closestFood.position - self.position).normalized();
      _wanderTimer.stop();
      return;
    }

    // If there's nothing else to do, wander.
    if (currentState != AiState.wandering) {
      currentState = AiState.wandering;
      _wanderTimer.start();
      _wander();
    }
  }

  FoodModel? _findClosestFood() {
    FoodModel? closestFood;
    double closestDistance = double.infinity;

    for (final food in foodManager.foodList) {
      final distance = self.position.distanceTo(food.position);
      if (distance < _visionRadius && distance < closestDistance) {
        closestDistance = distance;
        closestFood = food;
      }
    }
    return closestFood;
  }

  void _wander() {
    final newAngle = _random.nextDouble() * 2 * pi;
    targetDirection = Vector2(cos(newAngle), sin(newAngle));
  }
}