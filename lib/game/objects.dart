import 'dart:ui';

class GameObject {
  final String kind; // e.g., 'alien', 'ufo', 'player', 'obstacle'
  Offset center;
  Size size;
  final String? assetName;
  int health;
  Color? color;
  double _flashUntilSeconds = -1.0;

  GameObject({
    required this.kind,
    required this.center,
    required this.size,
    this.assetName,
    this.health = 1,
    this.color,
  });

  Rect get rect => Rect.fromCenter(center: center, width: size.width, height: size.height);

  void flash(double nowSeconds, {double durationSeconds = 0.12}) {
    _flashUntilSeconds = nowSeconds + durationSeconds;
  }

  bool isFlashing(double nowSeconds) => nowSeconds < _flashUntilSeconds;
}

mixin Shooter {
  late int shootingPower; // damage per shot
  late double reloadSeconds; // time between shots
  double _lastShotTime = -1e9;

  bool canShoot(double nowSeconds) => (nowSeconds - _lastShotTime) >= reloadSeconds;
  void recordShot(double nowSeconds) {
    _lastShotTime = nowSeconds;
  }
}

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

class UFO extends GameObject with Shooter {
  UFO({
    required super.center,
    required super.size,
    super.assetName,
    super.health = 3,
    super.color,
    int power = 1,
    double reload = 1.5,
  }) : super(kind: 'ufo') {
    shootingPower = power;
    reloadSeconds = reload;
  }
}

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

class Obstacle extends GameObject {
  Obstacle({
    required super.center,
    required super.size,
    super.assetName,
    super.health = 5,
    super.color,
  }) : super(kind: 'obstacle');
}
