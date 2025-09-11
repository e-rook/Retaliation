import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game/objects.dart';
import 'game/projectile.dart';
import 'dart:math';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retaliation',
      theme: ThemeData.dark(useMaterial3: true),
      home: const GamePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  static const int alienRows = 2;
  static const int alienCols = 6;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  Size _size = Size.zero;
  List<Alien> _aliens = [];
  PlayerShip? _player;
  final List<Obstacle> _obstacles = [];
  final List<Projectile> _projectiles = [];
  double _elapsedSeconds = 0;
  final Random _rng = Random();
  double? _nextPlayerShotAt;

  // Tunables
  final double _alienWidthFactor = 0.1; // relative to width
  final double _alienHeightFactor = 0.06; // relative to height
  final double _shipWidthFactor = 0.16;
  final double _shipHeightFactor = 0.035;
  final double _rowTopMarginFactor = 0.12;
  final double _rowSpacingFactor = 0.06;
  final double _colSpacingFactor = 0.04;
  final double _projectileSpeed = 280; // px/s downward

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6; // seconds
    _lastTick = elapsed;

    _elapsedSeconds += dt;
    if (_projectiles.isNotEmpty) {
      // Step motion
      for (final p in _projectiles) {
        p.step(dt);
      }
      // Remove projectiles off-screen (both top and bottom)
      _projectiles.removeWhere((p) =>
          p.center.dy - p.size.height / 2 > _size.height ||
          p.center.dy + p.size.height / 2 < 0);

      // Auto-fire from player at random intervals (1-4s)
      final s = _player;
      if (s != null) {
        _nextPlayerShotAt ??= _elapsedSeconds + 1 + _rng.nextDouble() * 3;
        if (_elapsedSeconds >= (_nextPlayerShotAt ?? 0) && s.canShoot(_elapsedSeconds)) {
          _fireFromPlayer(s);
          _nextPlayerShotAt = _elapsedSeconds + 1 + _rng.nextDouble() * 3;
        }
      }

      // Collisions
      bool anyCollision = false;
      // Iterate over a copy so we can remove safely
      for (final p in List<Projectile>.from(_projectiles)) {
        if (p.ownerKind == 'player') {
          Alien? hitAlien;
          for (final a in _aliens) {
            if (p.rect.overlaps(a.rect)) {
              a.health -= p.damage;
              a.flash(_elapsedSeconds);
              hitAlien = a;
              anyCollision = true;
              break;
            }
          }
          if (hitAlien != null) {
            _projectiles.remove(p);
            if (hitAlien.health <= 0) {
              _aliens.remove(hitAlien);
            }
            continue;
          }
        } else {
          // Alien projectile: hit obstacle first (shield), then player
          Obstacle? hitObs;
          for (final o in _obstacles) {
            if (p.rect.overlaps(o.rect)) {
              o.health -= p.damage;
              o.flash(_elapsedSeconds);
              hitObs = o;
              anyCollision = true;
              break;
            }
          }
          if (hitObs != null) {
            _projectiles.remove(p);
            if (hitObs.health <= 0) {
              _obstacles.remove(hitObs);
            }
            continue;
          }

          final ps = _player;
          if (ps != null && p.rect.overlaps(ps.rect)) {
            ps.health -= p.damage;
            ps.flash(_elapsedSeconds);
            anyCollision = true;
            _projectiles.remove(p);
            if (ps.health <= 0) {
              _player = null;
            }
            continue;
          }
        }
      }

      if (anyCollision) {
        setState(() {});
      } else {
        // Still repaint to animate motion if no collisions
        setState(() {});
      }
    }
  }

  void _layout(Size size) {
    if (size == _size) return;
    _size = size;

    final alienW = size.width * _alienWidthFactor;
    final alienH = size.height * _alienHeightFactor;
    final top = size.height * _rowTopMarginFactor;
    final rowGap = size.height * _rowSpacingFactor;

    // Compute total width of aliens plus gaps to center the grid
    final totalAliensW = alienCols * alienW;
    final gaps = (alienCols - 1) * (size.width * _colSpacingFactor);
    final startX = (size.width - (totalAliensW + gaps)) / 2;

    final aliens = <Alien>[];
    for (int r = 0; r < alienRows; r++) {
      for (int c = 0; c < alienCols; c++) {
        final x = startX + c * (alienW + size.width * _colSpacingFactor);
        final y = top + r * (alienH + rowGap);
        aliens.add(
          Alien(
            center: Offset(x + alienW / 2, y + alienH / 2),
            size: Size(alienW, alienH),
            assetName: null,
            health: 1,
            power: 1,
            reload: 0.8,
          ),
        );
      }
    }
    _aliens = aliens;

    final shipW = size.width * _shipWidthFactor;
    final shipH = size.height * _shipHeightFactor;
    _player = PlayerShip(
      center: Offset(size.width / 2, size.height - shipH * 1.5),
      size: Size(shipW, shipH),
      assetName: null,
      health: 3,
      power: 1,
      reload: 0.3,
    );
    _nextPlayerShotAt = _elapsedSeconds + 1 + _rng.nextDouble() * 3;

    // Obstacles (shields) — simple blocks above the ship
    _obstacles.clear();
    final shieldW = size.width * 0.18;
    final shieldH = size.height * 0.04;
    final y = size.height - shipH * 3.5;
    final gapsCount = 2;
    final totalShieldsW = 3 * shieldW;
    final gap = (size.width - totalShieldsW) / (3 + gapsCount);
    double cx = gap + shieldW / 2;
    for (int i = 0; i < 3; i++) {
      _obstacles.add(Obstacle(center: Offset(cx, y), size: Size(shieldW, shieldH), health: 5));
      cx += shieldW + gap;
    }
    // Do not call setState here; we're in the build/layout phase via LayoutBuilder.
    // The new geometry is immediately used in this build pass.
  }

  void _handleTap(TapDownDetails details) {
    final pos = details.localPosition;
    for (final alien in _aliens) {
      if (alien.rect.contains(pos)) {
        _fireFromAlien(alien);
        break;
      }
    }

    // If tap is on player, shoot upwards
    final s = _player;
    if (s != null && s.rect.contains(pos)) {
      _fireFromPlayer(s);
    }
  }

  void _fireFromAlien(Alien alien) {
    if (!alien.canShoot(_elapsedSeconds)) return;
    final start = Offset(alien.center.dx, alien.rect.bottom + 6);
    _projectiles.add(
      Projectile(
        center: start,
        velocity: Offset(0, _projectileSpeed),
        damage: alien.shootingPower,
        ownerKind: 'alien',
      ),
    );
    alien.recordShot(_elapsedSeconds);
    setState(() {});
  }

  void _fireFromPlayer(PlayerShip player) {
    if (!player.canShoot(_elapsedSeconds)) return;
    final start = Offset(player.center.dx, player.rect.top - 6);
    _projectiles.add(
      Projectile(
        center: start,
        velocity: const Offset(0, -360),
        damage: player.shootingPower,
        ownerKind: 'player',
      ),
    );
    player.recordShot(_elapsedSeconds);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layout(Size(constraints.maxWidth, constraints.maxHeight));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTap,
              child: CustomPaint(
                painter: _GamePainter(
                  aliens: _aliens,
                  player: _player,
                  obstacles: _obstacles,
                  projectiles: _projectiles,
                  now: _elapsedSeconds,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final List<Alien> aliens;
  final PlayerShip? player;
  final List<Obstacle> obstacles;
  final List<Projectile> projectiles;
  final double now;

  _GamePainter({required this.aliens, required this.player, required this.obstacles, required this.projectiles, required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Aliens
    for (final alien in aliens) {
      final paint = Paint()
        ..color = alien.isFlashing(now) ? const Color(0xFFFFFFFF) : const Color(0xFF38D66B);
      canvas.drawRect(alien.rect, paint);
    }

    // Ship
    final shipPaint = Paint();
    final s = player;
    if (s != null) {
      shipPaint.color = s.isFlashing(now) ? const Color(0xFFFFFFFF) : const Color(0xFF5AA9E6);
      canvas.drawRect(s.rect, shipPaint);
    }

    // Projectiles
    final projPaint = Paint()..color = const Color(0xFFE84D4D);
    for (final p in projectiles) {
      canvas.drawRect(p.rect, projPaint);
    }

    // Obstacles
    for (final o in obstacles) {
      final obPaint = Paint()
        ..color = o.isFlashing(now) ? const Color(0xFFFFFFFF) : const Color(0xFF9AA0A6);
      canvas.drawRect(o.rect, obPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return oldDelegate.aliens != aliens ||
        oldDelegate.player != player ||
        oldDelegate.obstacles != obstacles ||
        oldDelegate.projectiles != projectiles;
  }
}
