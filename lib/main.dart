import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game/objects.dart';
import 'game/projectile.dart';
import 'game/level.dart';
import 'game/level_validator.dart';
import 'game/level_list.dart';
import 'util/log.dart';
import 'designer/designer_page.dart';
import 'designer/level_select_page.dart';
import 'menu/menu_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

void main() {
  logv('App', 'main() starting');
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retaliation',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MenuPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GamePage extends StatefulWidget {
  final String? initialLevelPath;
  const GamePage({super.key, this.initialLevelPath});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {

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
  LevelConfig? _level;
  LevelList? _order;
  String? _currentLevelPath;
  // current level path tracked in _currentLevelPath; order in _order
  String? _lastLayoutLevelId;
  // Ship AI runtime
  double? _shipTargetX;
  double _shipMoveSpeed = 220;
  double _shipMoveChance = 0.6;
  double _shipAvoidChance = 0.5;
  double _shipBulletSpeed = 360;
  // Alien dance (group march)
  double _danceHSpeed = 0; // px/s
  double _danceVStep = 0; // px per bounce
  int _alienDir = 1; // 1 => right, -1 => left
  bool _won = false;
  bool _lost = false;
  String? _loadError;
  bool _tickLoggedOnce = false;
  double _lastTelemetry = 0;

  // Tunables
  final double _projectileSpeed = 280; // px/s downward

  @override
  void initState() {
    super.initState();
    logv('Game', 'initState');
    _ticker = createTicker(_onTick)..start();
    _bootstrap(widget.initialLevelPath);
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
    if (!_tickLoggedOnce) {
      logv('Tick', 'Ticker started.');
      _tickLoggedOnce = true;
    }
    if (_level == null || _won || _lost) {
      if (_elapsedSeconds - _lastTelemetry >= 1.0) {
        _lastTelemetry = _elapsedSeconds;
        logv('Tick', 'waiting=${_level == null}, won=$_won, lost=$_lost');
      }
      return; // wait for level or stop on end
    }

    // Ship AI: plan and move
    _updateShipAI(dt);

    if (_projectiles.isNotEmpty || _player != null) {
      // Aliens dance (group march)
      _updateAliensDance(dt);
      // Step motion
      for (final p in _projectiles) {
        p.step(dt);
      }
      // Remove projectiles off-screen (both top and bottom)
      _projectiles.removeWhere((p) =>
          p.center.dy - p.size.height / 2 > _size.height ||
          p.center.dy + p.size.height / 2 < 0);

      // Auto-fire from ship based on level spec (with slight randomness)
      final s = _player;
      if (s != null) {
        _nextPlayerShotAt ??= _elapsedSeconds + 0.5 + _rng.nextDouble() * 1.0;
        if (_elapsedSeconds >= (_nextPlayerShotAt ?? 0) && s.canShoot(_elapsedSeconds)) {
          _fireFromPlayer(s);
          // Next shot time: around reload +/- 50%
          final reload = s.reloadSeconds;
          final jitter = (0.5 + _rng.nextDouble()) * 0.5; // 0.25..0.75
          _nextPlayerShotAt = _elapsedSeconds + reload * (1.0 + jitter);
        }
      }

      // Collisions
      // Iterate over a copy so we can remove safely
      for (final p in List<Projectile>.from(_projectiles)) {
        if (p.ownerKind == 'player') {
          Alien? hitAlien;
          for (final a in _aliens) {
            if (p.rect.overlaps(a.rect)) {
              a.health -= p.damage;
              a.flash(_elapsedSeconds);
              logv('Hit', 'Ship shot alien: health=${a.health}');
              hitAlien = a;
              break;
            }
          }
          if (hitAlien != null) {
            _projectiles.remove(p);
            if (hitAlien.health <= 0) {
              logv('Kill', 'Alien destroyed');
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
              logv('Hit', 'Alien shot obstacle: health=${o.health}');
              hitObs = o;
              break;
            }
          }
          if (hitObs != null) {
            _projectiles.remove(p);
            if (hitObs.health <= 0) {
              logv('Kill', 'Obstacle destroyed');
              _obstacles.remove(hitObs);
            }
            continue;
          }

          final ps = _player;
          if (ps != null && p.rect.overlaps(ps.rect)) {
            ps.health -= p.damage;
            ps.flash(_elapsedSeconds);
            logv('Hit', 'Alien shot ship: health=${ps.health}');
            _projectiles.remove(p);
            if (ps.health <= 0) {
              logv('Kill', 'Ship destroyed');
              _player = null;
            }
            continue;
          }
        }
      }

      // Win/Lose evaluation
      _evaluateEndConditions();
      if (_elapsedSeconds - _lastTelemetry >= 1.0) {
        _lastTelemetry = _elapsedSeconds;
        logv('State', 'aliens=${_aliens.length}, obstacles=${_obstacles.length}, projectiles=${_projectiles.length}');
      }
      setState(() {});
    }
  }

  Future<void> _bootstrap([String? initialPath]) async {
    try {
      final order = await LevelList.loadFromAsset('assets/levels/levels.json');
      final prefs = await SharedPreferences.getInstance();
      final unlocked = (prefs.getInt('unlocked_count') ?? 1).clamp(1, order.levels.length);
      _order = order;
      _currentLevelPath = initialPath ?? (order.levels.isNotEmpty ? order.levels[0] : 'assets/levels/level1.json');
      final lvl = await LevelConfig.loadFromAsset(_currentLevelPath!);
      final validation = validateLevel(lvl);
      if (!mounted) return;
      if (!validation.isValid) {
        setState(() {
          _loadError = 'Level validation failed:\n- ${validation.errors.join('\n- ')}';
        });
      } else {
        setState(() {
          _level = lvl;
        });
      }
      logv('Game', 'Level ready: ${lvl.id}; unlocked=$unlocked');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load levels: $e';
      });
    }
  }

  Future<void> _openDesigner() async {
    final lvl = _level;
    if (lvl == null) return;
    final updated = await Navigator.of(context).push<LevelConfig>(
      MaterialPageRoute(builder: (_) => DesignerPage(initial: lvl)),
    );
    if (updated != null) {
      setState(() {
        _level = updated;
        _won = false;
        _lost = false;
        _aliens.clear();
        _obstacles.clear();
        _projectiles.clear();
        _player = null;
        _lastLayoutLevelId = null; // force layout rebuild with new level
      });
    }
  }

  Future<void> _openLevelPicker() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LevelSelectPage()),
    );
    if (selected != null) {
      try {
        final lvl = await LevelConfig.loadFromAsset(selected);
        final validation = validateLevel(lvl);
        if (!validation.isValid) {
          if (!mounted) return;
          // Show validation issues
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Invalid Level'),
              content: SingleChildScrollView(child: Text(validation.errors.join('\n'))),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
          return;
        }
        if (!mounted) return;
        setState(() {
          _level = lvl;
          _won = false;
          _lost = false;
          _aliens.clear();
          _obstacles.clear();
          _projectiles.clear();
          _player = null;
          _lastLayoutLevelId = null;
          _currentLevelPath = selected;
        });
      } catch (e) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Load Error'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  void _updateAliensDance(double dt) {
    if (_aliens.isEmpty || _danceHSpeed <= 0) return;
    bool willHitEdge = false;
    final dx = _alienDir * _danceHSpeed * dt;
    for (final a in _aliens) {
      final nx = a.center.dx + dx;
      final halfW = a.size.width / 2;
      if (nx - halfW < 0 || nx + halfW > _size.width) {
        willHitEdge = true;
        break;
      }
    }
    if (willHitEdge) {
      // Step down, reverse, then immediately continue horizontal move this tick
      for (final a in _aliens) {
        final ny = (a.center.dy + _danceVStep).clamp(a.size.height / 2, _size.height - a.size.height / 2);
        a.center = Offset(a.center.dx, ny);
      }
      _alienDir = -_alienDir;
      final dx2 = _alienDir * _danceHSpeed * dt;
      for (final a in _aliens) {
        final halfW = a.size.width / 2;
        final nx2 = (a.center.dx + dx2).clamp(halfW, _size.width - halfW);
        a.center = Offset(nx2, a.center.dy);
      }
    } else {
      for (final a in _aliens) {
        a.center = Offset(a.center.dx + dx, a.center.dy);
      }
    }
  }

  String _formatTimer() {
    final limit = _level?.timeLimitSeconds;
    if (limit == null) return '';
    double remaining = (limit - _elapsedSeconds);
    if (remaining < 0) remaining = 0;
    final total = remaining.floor();
    if (limit >= 60) {
      final m = total ~/ 60;
      final s = total % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return total.toString().padLeft(2, '0');
    }
  }

  void _updateShipAI(double dt) {
    final s = _player;
    if (s == null) return;
    // Movement target selection
    if (_shipTargetX == null || (s.center.dx - (_shipTargetX ?? s.center.dx)).abs() < 3) {
      if (_rng.nextDouble() < _shipMoveChance * dt) {
        _shipTargetX = _rng.nextDouble() * _size.width;
      }
    }

    // Avoidance: consider nearest alien projectile approaching
    Projectile? danger;
    double bestDy = double.infinity;
    for (final p in _projectiles) {
      if (p.ownerKind != 'alien') continue; // player's shots
      final dy = (s.center.dy - p.center.dy);
      if (dy > 0 && dy < bestDy && (p.center - s.center).distance < _size.width * 0.3) {
        bestDy = dy;
        danger = p;
      }
    }
    if (danger != null && _rng.nextDouble() < _shipAvoidChance * dt) {
      final away = (s.center.dx - danger.center.dx) >= 0 ? 1 : -1;
      final target = (s.center.dx + away * _size.width * 0.25).clamp(0 + s.size.width / 2, _size.width - s.size.width / 2);
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
        s.center = Offset((s.center.dx + step).clamp(s.size.width / 2, _size.width - s.size.width / 2), s.center.dy);
      }
    }
  }

  void _evaluateEndConditions() {
    final lvl = _level;
    if (lvl == null) return;
    bool win = false;
    bool lose = false;
    bool timerElapsed = lvl.timeLimitSeconds != null && _elapsedSeconds >= (lvl.timeLimitSeconds ?? 0);

    bool shipDestroyed = _player == null;
    bool aliensDestroyed = _aliens.isEmpty;

    for (final c in lvl.winConditions) {
      switch (c) {
        case ConditionKind.shipDestroyed:
          win |= shipDestroyed;
          break;
        case ConditionKind.aliensDestroyed:
          win |= aliensDestroyed;
          break;
        case ConditionKind.surviveTime:
          win |= timerElapsed;
          break;
        case ConditionKind.timerElapsed:
          win |= timerElapsed;
          break;
      }
    }
    for (final c in lvl.loseConditions) {
      switch (c) {
        case ConditionKind.shipDestroyed:
          lose |= shipDestroyed;
          break;
        case ConditionKind.aliensDestroyed:
          lose |= aliensDestroyed;
          break;
        case ConditionKind.surviveTime:
          lose |= timerElapsed;
          break;
        case ConditionKind.timerElapsed:
          lose |= timerElapsed;
          break;
      }
    }
    if (win) {
      if (!_won) {
        _won = true;
        _unlockNextLevel();
      }
    } else if (lose) {
      _lost = true;
    }
  }

  Future<void> _unlockNextLevel() async {
    if (_order == null || _currentLevelPath == null) return;
    final idx = _order!.levels.indexOf(_currentLevelPath!);
    if (idx < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('unlocked_count') ?? 1;
    final want = (idx + 2).clamp(1, _order!.levels.length);
    if (want > current) {
      await prefs.setInt('unlocked_count', want);
      logv('Progress', 'Unlocked levels: $want');
    }
  }

  void _layout(Size size) {
    final didSizeChange = size != _size;
    final currentLevelId = _level?.id;
    final didLevelChange = currentLevelId != _lastLayoutLevelId;
    if (!didSizeChange && !didLevelChange) return;
    _size = size;
    logv('Layout', 'Game surface size: ${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}');

    if (_level != null) {
      final lvl = _level!;
      // Aliens from spec
      _aliens = lvl.aliens
          .map((a) => Alien(
                center: Offset(a.x * size.width, a.y * size.height),
                size: Size(a.w * size.width, a.h * size.height),
                health: a.health,
                assetName: a.asset,
                color: a.color,
                power: a.shooter.power,
                reload: a.shooter.reloadSeconds,
              ))
          .toList();
      logv('Layout', 'Spawned aliens: ${_aliens.length}');

      // Ship from spec
      final s = lvl.ship;
      _player = PlayerShip(
        center: Offset(s.x * size.width, s.y * size.height),
        size: Size(s.w * size.width, s.h * size.height),
        health: s.health,
        assetName: s.asset,
        color: s.color,
        power: s.shooter.power,
        reload: s.shooter.reloadSeconds,
      );
      _shipMoveSpeed = s.ai.moveSpeed;
      _shipMoveChance = s.ai.moveChancePerSecond;
      _shipAvoidChance = s.ai.avoidChance;
      _shipBulletSpeed = s.shooter.bulletSpeed;
      _nextPlayerShotAt = _elapsedSeconds + 0.5 + _rng.nextDouble();
      logv('Layout', 'Ship ready. moveSpeed=$_shipMoveSpeed reload=${_player?.reloadSeconds}');

      // Obstacles from spec
      _obstacles.clear();
      for (final o in lvl.obstacles) {
        final totalW = o.w * size.width;
        final totalH = o.h * size.height;
        final cx = o.x * size.width;
        final cy = o.y * size.height;
        final cols = o.tileCols <= 0 ? 1 : o.tileCols;
        final rows = o.tileRows <= 0 ? 1 : o.tileRows;

        if (rows == 1 && cols == 1) {
          _obstacles.add(Obstacle(
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
          // Small visual gap so damage is visible
          const gap = 2.0; // logical px
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              final tx = left + c * tileW + tileW / 2;
              final ty = top + r * tileH + tileH / 2;
              final w = (tileW - gap).clamp(1.0, tileW);
              final h = (tileH - gap).clamp(1.0, tileH);
              _obstacles.add(Obstacle(
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
      logv('Layout', 'Spawned obstacles: ${_obstacles.length}');
      // Dance parameters
      _danceHSpeed = lvl.dance.hSpeed;
      _danceVStep = lvl.dance.vStep;
      _alienDir = 1;
    }
    _lastLayoutLevelId = currentLevelId;
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
    logv('Fire', 'Alien fired from x=${alien.center.dx.toStringAsFixed(1)}');
    setState(() {});
  }

  void _fireFromPlayer(PlayerShip player) {
    if (!player.canShoot(_elapsedSeconds)) return;
    final start = Offset(player.center.dx, player.rect.top - 6);
    _projectiles.add(
      Projectile(
        center: start,
        velocity: Offset(0, -_shipBulletSpeed),
        damage: player.shootingPower,
        ownerKind: 'player',
      ),
    );
    player.recordShot(_elapsedSeconds);
    logv('Fire', 'Ship fired');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layout(Size(constraints.maxWidth, constraints.maxHeight));
            // Determine overlay message
            Widget? overlay;
            if (_loadError != null) {
              overlay = Center(child: _MessageCard(text: _loadError!));
            } else if (_level == null) {
              overlay = const Center(child: _MessageCard(text: 'Loading level...'));
            } else if (_won) {
              overlay = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openLevelPicker,
                child: Center(child: _MessageCard(text: _level!.winMessage)),
              );
            } else if (_lost) {
              overlay = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openLevelPicker,
                child: Center(child: _MessageCard(text: _level!.loseMessage)),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
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
                ),
                if (_level?.timeLimitSeconds != null)
                  Positioned(
                    left: 10,
                    top: 8,
                    child: GestureDetector(
                      onLongPress: _openDesigner,
                      child: _TimerBadge(text: _formatTimer()),
                    ),
                  ),
                if (overlay != null) overlay,
                Positioned(
                  right: 8,
                  top: 8,
                  child: _LevelsButton(onTap: _openLevelPicker),
                ),
              ],
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
      final baseColor = alien.color ?? const Color(0xFF38D66B);
      final paint = Paint()
        ..color = alien.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
      canvas.drawRect(alien.rect, paint);
    }

    // Ship
    final shipPaint = Paint();
    final s = player;
    if (s != null) {
      final baseColor = s.color ?? const Color(0xFF5AA9E6);
      shipPaint.color = s.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
      canvas.drawRect(s.rect, shipPaint);
    }

    // Projectiles
    final projPaint = Paint()..color = const Color(0xFFE84D4D);
    for (final p in projectiles) {
      canvas.drawRect(p.rect, projPaint);
    }

    // Obstacles
    for (final o in obstacles) {
      final baseColor = o.color ?? const Color(0xFF9AA0A6);
      final obPaint = Paint()
        ..color = o.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
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

class _MessageCard extends StatelessWidget {
  final String text;
  const _MessageCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final String text;
  const _TimerBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _LevelsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LevelsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Levels', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
