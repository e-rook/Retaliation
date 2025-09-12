import 'game_object.dart';

class Obstacle extends GameObject {
  Obstacle({
    required super.center,
    required super.size,
    super.assetName,
    super.health = 5,
    super.color,
  }) : super(kind: 'obstacle');
}
