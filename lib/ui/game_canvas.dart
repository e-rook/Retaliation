import 'package:flutter/material.dart';
import '../game/entities/entities.dart';
import '../game/force_field.dart';
import '../game/projectile.dart';
import '../gfx/sprites.dart';

class GameCanvas extends StatelessWidget {
  final List<Alien> aliens;
  final PlayerShip? player;
  final List<Obstacle> obstacles;
  final List<Projectile> projectiles;
  final double now;
  final ForceField? forceField;

  const GameCanvas({super.key, required this.aliens, required this.player, required this.obstacles, required this.projectiles, required this.now, required this.forceField});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GamePainter(aliens: aliens, player: player, obstacles: obstacles, now: now, forceField: forceField, projectiles: projectiles),
      size: Size.infinite,
    );
  }
}

class _GamePainter extends CustomPainter {
  final List<Alien> aliens;
  final PlayerShip? player;
  final List<Obstacle> obstacles;
  final List<Projectile> projectiles;
  final double now;
  final ForceField? forceField;

  _GamePainter({required this.aliens, required this.player, required this.obstacles, required this.projectiles, required this.now, required this.forceField});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    for (final alien in aliens) {
      final asset = alien.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final cf = alien.isFlashing(now)
            ? const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)
            : (alien.color != null ? ColorFilter.mode(alien.color!, BlendMode.modulate) : null);
        final p = Paint()..colorFilter = cf;
        canvas.drawImageRect(img, src, alien.rect, p);
      } else if (asset == null || SpriteStore.instance.hasFailed(asset)) {
        final baseColor = alien.color ?? const Color(0xFF38D66B);
        final paint = Paint()..color = alien.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(alien.rect, paint);
      }
    }

    final s = player;
    if (s != null) {
      final asset = s.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, s.rect, Paint()..colorFilter = (s.isFlashing(now) ? const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn) : null));
      } else {
        final baseColor = s.color ?? const Color(0xFF5AA9E6);
        final shipPaint = Paint()..color = s.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(s.rect, shipPaint);
      }
    }

    // Projectiles
    final projPaint = Paint()..color = const Color(0xFFE84D4D);
    for (final p in projectiles) {
      canvas.drawRect(p.rect, projPaint);
    }

    for (final o in obstacles) {
      final asset = o.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, o.rect, Paint());
      } else {
        final baseColor = o.color ?? const Color(0xFF9AA0A6);
        final obPaint = Paint()..color = o.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(o.rect, obPaint);
      }
    }

    final ff = forceField;
    if (ff != null && ff.alive) {
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ff.color.withValues(alpha: 0.15);
      canvas.drawPath(ff.path, base);
      final gw = ff.glowWidth(now);
      if (gw > 0) {
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = gw
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9);
        canvas.drawPath(ff.path, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) {
    return old.aliens != aliens || old.player != player || old.obstacles != obstacles || old.projectiles != projectiles || old.forceField != forceField || old.now != now;
  }
}
