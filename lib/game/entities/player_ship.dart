import 'game_object.dart';

class PlayerShip extends GameObject with Shooter {
  PlayerShip({
    required super.center,
    required super.size,
    super.assetName,
    super.health = 3,
    super.color,
    int power = 1,
    double reload = 0.4,
  }) : super(kind: 'player') {
    shootingPower = power;
    reloadSeconds = reload;
  }
}
