import 'dart:ui';

class Projectile {
  Offset center; // center position
  Offset velocity; // px per second
  final Size size;
  final int damage;
  final String ownerKind; // 'alien' or 'player'

  Projectile({
    required this.center,
    required this.velocity,
    this.size = const Size(4, 12),
    this.damage = 1,
    this.ownerKind = 'alien',
  });

  Rect get rect => Rect.fromCenter(center: center, width: size.width, height: size.height);

  void step(double dtSeconds) {
    center = Offset(center.dx + velocity.dx * dtSeconds, center.dy + velocity.dy * dtSeconds);
  }
}

