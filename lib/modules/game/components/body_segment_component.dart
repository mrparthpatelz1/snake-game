// lib/app/modules/game/components/body_segment_component.dart

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class BodySegmentComponent extends PositionComponent {
  // A reference to the snake this segment belongs to, so a snake can't collide with itself.
  final PositionComponent owner;

  BodySegmentComponent({required this.owner, required double radius}) {
    // Add a circular hitbox with the given radius.
    add(CircleHitbox(radius: radius));
  }
}