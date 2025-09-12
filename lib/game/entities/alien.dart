import 'game_object.dart';

class Alien extends GameObject with Shooter {
  Alien({
    required super.center,
    required super.size,
    super.assetName,
    super.health = 1,
    super.color,
    int power = 1,
    double reload = 1.0,
  }) : super(kind: 'alien') {
    shootingPower = power;
    reloadSeconds = reload;
  }
}
