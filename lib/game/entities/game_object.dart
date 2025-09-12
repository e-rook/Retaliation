import 'dart:ui';

abstract class GameObject {
  final String kind;
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
  double reloadRandomMax = 0.0; // extra random seconds [0..max]
  double _lastShotTime = -1e9;

  bool canShoot(double nowSeconds) => (nowSeconds - _lastShotTime) >= reloadSeconds;
  void recordShot(double nowSeconds) {
    _lastShotTime = nowSeconds;
  }
}
