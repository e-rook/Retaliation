import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'entities/entities.dart';
import 'projectile.dart';
import 'force_field.dart';
import 'level.dart';

typedef LogFn = void Function(String tag, String message);

class GameController extends ChangeNotifier {
  // Public state (read-only from UI)
  final List<Alien> aliens = [];
  PlayerShip? player;
  final List<Obstacle> obstacles = [];
  final List<Projectile> projectiles = [];
  ForceField? forceField;

  // Level info
  LevelConfig? level;
  Size _size = Size.zero;

  // Runtime flags
  bool won = false;
  bool lost = false;
  double elapsedSeconds = 0;

  // AI & movement
  double? _shipTargetX;
  double _shipMoveSpeed = 220;
  double _shipMoveChance = 0.6;
  double _shipAvoidChance = 0.5;
  double _shipBulletSpeed = 360;
  double? _nextPlayerShotAt;

  // Dance
  double _danceHSpeed = 0;
  double _danceVStep = 0;
  int _alienDir = 1;

  // Params
  double projectileSpeed = 280; // alien projectile down speed

  // Util
  final Random rng;
  final LogFn log;

  GameController({required this.rng, required this.log});

  // Load a LevelConfig and reset runtime state
  void loadLevel(LevelConfig cfg) {
    level = cfg;
    // clear state
    aliens.clear();
    obstacles.clear();
    projectiles.clear();
    player = null;
    forceField = null;
    won = false;
    lost = false;
    elapsedSeconds = 0;
    _shipTargetX = null;
    _nextPlayerShotAt = null;
    // Defer geometry to layout(Size)
    notifyListeners();
  }

  // Build geometry given current size
  void layout(Size size) {
    if (level == null) return;
    if (size == _size) return;
    _size = size;
    final lvl = level!;

    // Aliens
    aliens
      ..clear()
      ..addAll(lvl.aliens.map((a) => Alien(
            center: Offset(a.x * size.width, a.y * size.height),
            size: Size(a.w * size.width, a.h * size.height),
            assetName: a.asset,
            health: a.health,
            color: a.color,
            power: a.shooter.power,
            reload: a.shooter.reloadSeconds,
          )));

    // Ship
    final s = lvl.ship;
    player = PlayerShip(
      center: Offset(s.x * size.width, s.y * size.height),
      size: Size(s.w * size.width, s.h * size.height),
      assetName: s.asset,
      health: s.health,
      color: s.color,
      power: s.shooter.power,
      reload: s.shooter.reloadSeconds,
    );
    player!.reloadRandomMax = s.shooter.reloadRandom;

    _shipMoveSpeed = s.ai.moveSpeed;
    _shipMoveChance = s.ai.moveChancePerSecond;
    _shipAvoidChance = s.ai.avoidChance;
    _shipBulletSpeed = s.shooter.bulletSpeed;
    _nextPlayerShotAt = elapsedSeconds + 0.5 + rng.nextDouble();

    // Obstacles (with tiling)
    obstacles.clear();
    for (final o in lvl.obstacles) {
      final totalW = o.w * size.width;
      final totalH = o.h * size.height;
      final cx = o.x * size.width;
      final cy = o.y * size.height;
      final cols = o.tileCols <= 0 ? 1 : o.tileCols;
      final rows = o.tileRows <= 0 ? 1 : o.tileRows;
      if (rows == 1 && cols == 1) {
        obstacles.add(Obstacle(
          center: Offset(cx, cy),
          size: Size(totalW, totalH),
          health: o.health,
          color: o.color,
          assetName: o.asset,
        ));
      } else {
        final tileW = totalW / cols;
        final tileH = totalH / rows;
        final left = cx - totalW / 2;
        final top = cy - totalH / 2;
        const gap = 2.0;
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            final tx = left + c * tileW + tileW / 2;
            final ty = top + r * tileH + tileH / 2;
            final w = (tileW - gap).clamp(1.0, tileW);
            final h = (tileH - gap).clamp(1.0, tileH);
            obstacles.add(Obstacle(
              center: Offset(tx, ty),
              size: Size(w, h),
              health: o.health,
              color: o.color,
              assetName: o.asset,
            ));
          }
        }
      }
    }

    // Dance
    _danceHSpeed = lvl.dance.hSpeed;
    _danceVStep = lvl.dance.vStep;
    _alienDir = 1;

    // Force field
    if (lvl.forceField != null && player != null) {
      forceField = ForceField(
        transparent: lvl.forceField!.transparent,
        health: lvl.forceField!.health,
        color: lvl.forceField!.color ?? const Color(0xFF66D9FF),
      );
      forceField!.layout(size, player!.rect);
      log('ForceField', 'Enabled: transparent=${forceField!.transparent}, health=${forceField!.health}');
    } else {
      forceField = null;
    }

    notifyListeners();
  }

  void tick(double dt) {
    if (level == null) return;
    elapsedSeconds += dt;
    if (won || lost) return;

    _updateAliensDance(dt);
    _updateShipAI(dt);

    // Step projectiles
    for (final p in projectiles) {
      p.step(dt);
    }
    // Cull off-screen
    projectiles.removeWhere((p) => p.center.dy - p.size.height / 2 > _size.height || p.center.dy + p.size.height / 2 < 0);

    // Auto-fire from ship
    final s = player;
    if (s != null) {
      _nextPlayerShotAt ??= elapsedSeconds + 0.5 + rng.nextDouble();
      if (elapsedSeconds >= (_nextPlayerShotAt ?? 0) && s.canShoot(elapsedSeconds)) {
        _fireFromPlayer(s);
        final base = s.reloadSeconds;
        final rand = rng.nextDouble() * (s.reloadRandomMax);
        _nextPlayerShotAt = elapsedSeconds + base + rand;
      }
    }

    _collisions();
    _evaluateEndConditions();
    notifyListeners();
  }

  void handleTap(Offset pos) {
    for (final alien in aliens) {
      if (alien.rect.contains(pos)) {
        _fireFromAlien(alien);
        break;
      }
    }
  }

  // --- internals ---
  void _fireFromAlien(Alien alien) {
    if (!alien.canShoot(elapsedSeconds)) return;
    final start = Offset(alien.center.dx, alien.rect.bottom + 6);
    projectiles.add(Projectile(center: start, velocity: Offset(0, projectileSpeed), damage: alien.shootingPower, ownerKind: 'alien'));
    alien.recordShot(elapsedSeconds);
  }

  void _fireFromPlayer(PlayerShip s) {
    if (!s.canShoot(elapsedSeconds)) return;
    final start = Offset(s.center.dx, s.rect.top - 6);
    projectiles.add(Projectile(center: start, velocity: Offset(0, -_shipBulletSpeed), damage: s.shootingPower, ownerKind: 'player'));
    s.recordShot(elapsedSeconds);
  }

  void _updateAliensDance(double dt) {
    if (aliens.isEmpty || _danceHSpeed <= 0) return;
    bool willHitEdge = false;
    final dx = _alienDir * _danceHSpeed * dt;
    for (final a in aliens) {
      final nx = a.center.dx + dx;
      final halfW = a.size.width / 2;
      if (nx - halfW < 0 || nx + halfW > _size.width) {
        willHitEdge = true;
        break;
      }
    }
    if (willHitEdge) {
      for (final a in aliens) {
        final ny = (a.center.dy + _danceVStep).clamp(a.size.height / 2, _size.height - a.size.height / 2);
        a.center = Offset(a.center.dx, ny);
      }
      _alienDir = -_alienDir;
      final dx2 = _alienDir * _danceHSpeed * dt;
      for (final a in aliens) {
        final halfW = a.size.width / 2;
        final nx2 = (a.center.dx + dx2).clamp(halfW, _size.width - halfW);
        a.center = Offset(nx2, a.center.dy);
      }
    } else {
      for (final a in aliens) {
        a.center = Offset(a.center.dx + dx, a.center.dy);
      }
    }
  }

  void _collisions() {
    for (final p in List<Projectile>.from(projectiles)) {
      if (p.ownerKind == 'player') {
        Alien? hitAlien;
        for (final a in aliens) {
          if (p.rect.overlaps(a.rect)) {
            a.health -= p.damage;
            a.flash(elapsedSeconds);
            hitAlien = a;
            break;
          }
        }
        if (hitAlien != null) {
          projectiles.remove(p);
          if (hitAlien.health <= 0) {
            aliens.remove(hitAlien);
          }
          continue;
        }
      } else {
        // ForceField first
        if (forceField != null && forceField!.hitTest(p)) {
          forceField!.onHit(elapsedSeconds, p.damage);
          if (forceField!.transparent) {
            log('ForceField', 'Hit (transparent): projectile passes through');
          } else {
            log('ForceField', 'Hit (absorbed): projectile removed');
            projectiles.remove(p);
          }
          continue;
        }

        // Obstacles
        Obstacle? hitObs;
        for (final o in obstacles) {
          if (p.rect.overlaps(o.rect)) {
            o.health -= p.damage;
            o.flash(elapsedSeconds);
            hitObs = o;
            break;
          }
        }
        if (hitObs != null) {
          projectiles.remove(p);
          if (hitObs.health <= 0) {
            obstacles.remove(hitObs);
          }
          continue;
        }

        // Ship
        final ps = player;
        if (ps != null && p.rect.overlaps(ps.rect)) {
          ps.health -= p.damage;
          ps.flash(elapsedSeconds);
          projectiles.remove(p);
          if (ps.health <= 0) {
            player = null;
          }
          continue;
        }
      }
    }
  }

  void _evaluateEndConditions() {
    final lvl = level;
    if (lvl == null) return;
    bool winLocal = false, loseLocal = false;
    final timerElapsed = lvl.timeLimitSeconds != null && elapsedSeconds >= (lvl.timeLimitSeconds ?? 0);
    final shipDestroyed = player == null;
    final aliensDestroyed = aliens.isEmpty;
    for (final c in lvl.winConditions) {
      switch (c) {
        case ConditionKind.shipDestroyed:
          winLocal |= shipDestroyed;
          break;
        case ConditionKind.aliensDestroyed:
          winLocal |= aliensDestroyed;
          break;
        case ConditionKind.surviveTime:
        case ConditionKind.timerElapsed:
          winLocal |= timerElapsed;
          break;
      }
    }
    for (final c in lvl.loseConditions) {
      switch (c) {
        case ConditionKind.shipDestroyed:
          loseLocal |= shipDestroyed;
          break;
        case ConditionKind.aliensDestroyed:
          loseLocal |= aliensDestroyed;
          break;
        case ConditionKind.surviveTime:
        case ConditionKind.timerElapsed:
          loseLocal |= timerElapsed;
          break;
      }
    }
    won = winLocal;
    lost = loseLocal;
  }

  void _updateShipAI(double dt) {
    final s = player;
    if (s == null) return;
    // Random target selection
    if (_shipTargetX == null || (s.center.dx - (_shipTargetX ?? s.center.dx)).abs() < 3) {
      if (rng.nextDouble() < _shipMoveChance * dt) {
        _shipTargetX = rng.nextDouble() * _size.width;
      }
    }
    // Avoidance: nearest alien projectile approaching
    Projectile? danger;
    double bestDy = double.infinity;
    for (final p in projectiles) {
      if (p.ownerKind != 'alien') continue;
      final dy = s.center.dy - p.center.dy;
      if (dy > 0 && dy < bestDy && (p.center - s.center).distance < _size.width * 0.3) {
        bestDy = dy;
        danger = p;
      }
    }
    if (danger != null && rng.nextDouble() < _shipAvoidChance * dt) {
      final away = (s.center.dx - danger.center.dx) >= 0 ? 1 : -1;
      final target = (s.center.dx + away * _size.width * 0.25)
          .clamp(s.size.width / 2, _size.width - s.size.width / 2);
      _shipTargetX = target.toDouble();
    }
    // Move toward target
    final tx = _shipTargetX;
    if (tx != null) {
      final dir = tx - s.center.dx;
      final step = _shipMoveSpeed * dt * dir.sign;
      if (dir.abs() <= step.abs()) {
        s.center = Offset(tx, s.center.dy);
      } else {
        s.center = Offset(
            (s.center.dx + step).clamp(s.size.width / 2, _size.width - s.size.width / 2),
            s.center.dy);
      }
    }
  }
}
