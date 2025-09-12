import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game/entities/entities.dart';
import 'game/force_field.dart';
import 'game/game_controller.dart';
import 'game/projectile.dart';
import 'game/level.dart';
import 'game/level_validator.dart';
import 'game/level_list.dart';
import 'util/log.dart';
import 'designer/level_select_page.dart';
import 'menu/menu_page.dart';
import 'gfx/sprites.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
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
  late final GameController _gc;
  final Random _rng = Random();
  LevelConfig? _level;
  String? _currentLevelPath;
  // current level path tracked in _currentLevelPath; order in _order
  String? _lastLayoutLevelId;
  // Ship AI runtime
  // Alien dance (group march)
  bool get _won => _gc.won;
  bool get _lost => _gc.lost;
  String? _loadError;
  bool _tickLoggedOnce = false;
  double _lastTelemetry = 0;

  // Tunables

  @override
  void initState() {
    super.initState();
    logv('Game', 'initState');
    _gc = GameController(rng: _rng, log: logv);
    _ticker = createTicker(_onTick)..start();
    SpriteStore.instance.addListener(_onSpritesChanged);
    _bootstrap(widget.initialLevelPath);
  }

  @override
  void dispose() {
    SpriteStore.instance.removeListener(_onSpritesChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onSpritesChanged() {
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6; // seconds
    _lastTick = elapsed;

    _gc.elapsedSeconds += dt;
    if (!_tickLoggedOnce) {
      logv('Tick', 'Ticker started.');
      _tickLoggedOnce = true;
    }
    if (_level == null || _won || _lost) {
      if (_gc.elapsedSeconds - _lastTelemetry >= 1.0) {
        _lastTelemetry = _gc.elapsedSeconds;
        logv('Tick', 'waiting=${_level == null}, won=$_won, lost=$_lost');
      }
      return; // wait for level or stop on end
    }


    _gc.tick(dt);
    if (_gc.projectiles.isNotEmpty || _gc.player != null) {
      if (_gc.elapsedSeconds - _lastTelemetry >= 1.0) {
        _lastTelemetry = _gc.elapsedSeconds;
        logv('State', 'aliens=${_gc.aliens.length}, obstacles=${_gc.obstacles.length}, projectiles=${_gc.projectiles.length}');
      }
      setState(() {});
    }
  }

  Future<void> _bootstrap([String? initialPath]) async {
    try {
      final order = await LevelList.loadFromAsset('assets/levels/levels.json');
      final prefs = await SharedPreferences.getInstance();
      final unlocked = (prefs.getInt('unlocked_count') ?? 1).clamp(1, order.levels.length);
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
        // Debug: verify that sprite assets are present in the bundle
        _debugCheckSpriteAssets(lvl);
      }
      logv('Game', 'Level ready: ${lvl.id}; unlocked=$unlocked');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load levels: $e';
      });
    }
  }

  Future<void> _debugCheckSpriteAssets(LevelConfig lvl) async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestStr);
      final keys = manifest.keys.toSet();
      final paths = <String?>[
        lvl.ship.asset,
        for (final a in lvl.aliens) a.asset,
        for (final o in lvl.obstacles) o.asset,
      ].whereType<String>().toSet();
      for (final p in paths) {
        final present = keys.contains(p);
        logv('Assets', '${present ? 'FOUND' : 'MISSING'} in bundle: $p');
      }
    } catch (e) {
      logv('Assets', 'Failed to read AssetManifest.json: $e');
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
          _lastLayoutLevelId = null;
          _lastTick = Duration.zero;
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


  void _layout(Size size) {
    final didSizeChange = size != _size;
    final currentLevelId = _level?.id;
    final didLevelChange = currentLevelId != _lastLayoutLevelId;
    if (!didSizeChange && !didLevelChange) return;
    _size = size;
    logv('Layout', 'Game surface size: ${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}');

    if (_level != null) {
      _gc.loadLevel(_level!);
      _gc.layout(size);
    }
    _lastLayoutLevelId = currentLevelId;
    // Do not call setState here; we're in the build/layout phase via LayoutBuilder.
    // The new geometry is immediately used in this build pass.
  }

  void _handleTap(TapDownDetails details) {
    final pos = details.localPosition;
    for (final alien in _gc.aliens) {
      if (alien.rect.contains(pos)) {
        _gc.handleTap(pos);
        break;
      }
    }
  }



  String _formatTimer() {
    final limit = _level?.timeLimitSeconds;
    if (limit == null) return '';
    double remaining = (limit - _gc.elapsedSeconds);
    if (remaining < 0) remaining = 0;
    final total = remaining.floor();
    if (limit >= 60) {
      final m = total ~/ 60;
      final sec = total % 60;
      return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    } else {
      return total.toString().padLeft(2, '0');
    }
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
                      aliens: _gc.aliens,
                      player: _gc.player,
                      obstacles: _gc.obstacles,
                      projectiles: _gc.projectiles,
                      now: _gc.elapsedSeconds,
                      forceField: _gc.forceField,
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (_level?.timeLimitSeconds != null)
                  Positioned(
                    left: 10,
                    top: 8,
                    child: _TimerBadge(text: _formatTimer()),
                  ),
                
                if (overlay != null) overlay,
                Positioned(
                  right: 8,
                  top: 8,
                  child: _LevelsButton(onTap: _openLevelPicker),
                ),
                Positioned(
                  right: 8,
                  top: 36,
                  child: _MenuButton(onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MenuPage()),
                      (route) => false,
                    );
                  }),
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
  final ForceField? forceField;

  _GamePainter({required this.aliens, required this.player, required this.obstacles, required this.projectiles, required this.now, required this.forceField});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Aliens (sprite if available; tint with color; if loading, skip; fallback rect if missing/failed)
    for (final alien in aliens) {
      final asset = alien.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        // ignore: discarded_futures
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final cf = alien.isFlashing(now)
            ? const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)
            : (alien.color != null
                ? ColorFilter.mode(alien.color!, BlendMode.modulate)
                : null);
        final p = Paint()..colorFilter = cf;
        canvas.drawImageRect(img, src, alien.rect, p);
      } else if (asset == null || SpriteStore.instance.hasFailed(asset)) {
        final baseColor = alien.color ?? const Color(0xFF38D66B);
        final paint = Paint()..color = alien.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(alien.rect, paint);
      }
    }

    // Ship
    final shipPaint = Paint();
    final s = player;
    if (s != null) {
      final asset = s.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        // ignore: discarded_futures
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, s.rect, Paint());
      } else if (asset == null || SpriteStore.instance.hasFailed(asset)) {
        final baseColor = s.color ?? const Color(0xFF5AA9E6);
        shipPaint.color = s.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(s.rect, shipPaint);
      }
    }

    // Projectiles
    final projPaint = Paint()..color = const Color(0xFFE84D4D);
    for (final p in projectiles) {
      canvas.drawRect(p.rect, projPaint);
    }

    // Obstacles (sprite if available; if loading, skip; fallback rect if missing/failed)
    for (final o in obstacles) {
      final asset = o.assetName;
      final img = (asset != null) ? SpriteStore.instance.imageFor(asset) : null;
      if (asset != null && img == null) {
        // ignore: discarded_futures
        SpriteStore.instance.ensure(asset);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, o.rect, Paint());
      } else if (asset == null || SpriteStore.instance.hasFailed(asset)) {
        final baseColor = o.color ?? const Color(0xFF9AA0A6);
        final obPaint = Paint()..color = o.isFlashing(now) ? const Color(0xFFFFFFFF) : baseColor;
        canvas.drawRect(o.rect, obPaint);
      }
    }

    // ForceField
    final ff = forceField;
    if (ff != null && ff.alive) {
      // Base: almost transparent
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ff.color.withValues(alpha: 0.15);
      canvas.drawPath(ff.path, base);
      // Glow sequence following Swift behavior
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
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return oldDelegate.aliens != aliens ||
        oldDelegate.player != player ||
        oldDelegate.obstacles != obstacles ||
        oldDelegate.projectiles != projectiles ||
        oldDelegate.forceField != forceField ||
        oldDelegate.now != now;
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


class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});
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
              Icon(Icons.home, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Menu', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
