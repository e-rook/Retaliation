import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game/game_controller.dart';
import 'game/level.dart';
import 'game/level_validator.dart';
import 'game/level_list.dart';
import 'util/log.dart';
import 'menu/menu_page.dart';
import 'gfx/sprites.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'ui/game_canvas.dart';
import 'ui/game_scaffold.dart';
import 'ui/game_overlays.dart';
import 'ui/game_provider.dart';

void main() {
  logv('App', 'main() starting');
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Screenshot automation defines
    const String startLevel = String.fromEnvironment('START_LEVEL', defaultValue: '');
    const String startScreen = String.fromEnvironment('START_SCREEN', defaultValue: ''); // '', 'level_select'

    Widget home;
    if (startLevel.isNotEmpty) {
      home = GamePage(initialLevelPath: startLevel);
    } else if (startScreen == 'level_select') {
      home = const MenuPage(openLevelSelectOnStart: true);
    } else {
      home = const MenuPage();
    }

    return MaterialApp(
      title: 'Retaliation',
      theme: ThemeData.dark(useMaterial3: true),
      home: home,
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
  bool _showIntro = false;

  // Tunables

  @override
  void initState() {
    super.initState();
    logv('Game', 'initState');
    _gc = GameController(rng: _rng, log: logv);
    _ticker = createTicker(_onTick)..start();
    SpriteStore.instance.addListener(_onSpritesChanged);
    _bootstrap(widget.initialLevelPath);

    // Screenshot automation: force overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const String forceOverlay = String.fromEnvironment('FORCE_OVERLAY', defaultValue: ''); // '', 'win', 'lose'
      if (forceOverlay == 'win' || forceOverlay == 'lose') {
        setState(() {
          _gc.won = forceOverlay == 'win';
          _gc.lost = forceOverlay == 'lose';
        });
      }
    });
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
    if (_showIntro) {
      return; // pause game/timer during intro overlay
    }

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
    if (_gc.projectiles.isNotEmpty || _gc.players.isNotEmpty) {
      if (_gc.elapsedSeconds - _lastTelemetry >= 1.0) {
        _lastTelemetry = _gc.elapsedSeconds;
        logv('State', 'aliens=${_gc.aliens.length}, obstacles=${_gc.obstacles.length}, projectiles=${_gc.projectiles.length}, players=${_gc.players.length}');
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
          _showIntro = lvl.description.isNotEmpty;
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
        for (final s in (lvl.ships.isNotEmpty ? lvl.ships : [lvl.ship])) s.asset,
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

  Future<void> _retryLevel() async {
    final path = _currentLevelPath;
    if (path == null) return;
    try {
      final lvl = await LevelConfig.loadFromAsset(path);
      final validation = validateLevel(lvl);
      if (!validation.isValid) {
        if (!mounted) return;
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
        _showIntro = lvl.description.isNotEmpty;
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

  Future<void> _goToNextLevel() async {
    try {
      final order = await LevelList.loadFromAsset('assets/levels/levels.json');
      final idx = order.levels.indexOf(_currentLevelPath ?? '');
      final nextIdx = (idx >= 0 && idx + 1 < order.levels.length) ? idx + 1 : -1;
      if (nextIdx < 0) {
        // No next level; go to menu.
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenuPage()),
          (route) => false,
        );
        return;
      }
      final nextPath = order.levels[nextIdx];
      final lvl = await LevelConfig.loadFromAsset(nextPath);
      final validation = validateLevel(lvl);
      if (!validation.isValid) {
        if (!mounted) return;
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
      // Unlock up to next level
      final prefs = await SharedPreferences.getInstance();
      final unlocked = (prefs.getInt('unlocked_count') ?? 1);
      if (unlocked < nextIdx + 1) {
        await prefs.setInt('unlocked_count', nextIdx + 1);
      }
      if (!mounted) return;
      setState(() {
        _level = lvl;
        _currentLevelPath = nextPath;
        _lastLayoutLevelId = null;
        _lastTick = Duration.zero;
        _showIntro = lvl.description.isNotEmpty;
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
    GameOverlayState overlayState;
    VoidCallback? overlaySelectLevel;
    VoidCallback? overlayMenu;
    VoidCallback? overlayRetry;
    VoidCallback? overlayNext;
    if (_loadError != null) {
      overlayState = GameOverlayState.error(_loadError!);
    } else if (_level == null) {
      overlayState = const GameOverlayState.loading();
    } else if (_showIntro && _level!.description.isNotEmpty) {
      overlayState = GameOverlayState.intro(title: _level!.title, description: _level!.description);
    } else if (_won) {
      overlayState = GameOverlayState.win(_level!.winMessage);
      overlayNext = _goToNextLevel;
      overlaySelectLevel = () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenuPage(openLevelSelectOnStart: true)),
          (route) => false,
        );
      };
      overlayMenu = () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenuPage()),
          (route) => false,
        );
      };
    } else if (_lost) {
      overlayState = GameOverlayState.lose(_level!.loseMessage);
      overlayRetry = _retryLevel;
      overlayMenu = () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenuPage()),
          (route) => false,
        );
      };
    } else {
      overlayState = const GameOverlayState.none();
    }

    return GameControllerProvider(
      controller: _gc,
      child: GameScaffold(
      canvas: GameCanvas(
        aliens: _gc.aliens,
        players: _gc.players,
        obstacles: _gc.obstacles,
        projectiles: _gc.projectiles,
        now: _gc.elapsedSeconds,
        forceField: _gc.forceField,
      ),
        overlays: overlayState,
        onOpenMenu: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MenuPage()),
            (route) => false,
          );
        },
        onTapDown: _handleTap,
        onLayout: _layout,
        showTimer: _level?.timeLimitSeconds != null,
        timerText: _formatTimer(),
        onOverlaySelectLevel: overlaySelectLevel,
        onOverlayMenu: overlayMenu,
        onOverlayRetry: overlayRetry,
        onOverlayNext: overlayNext,
        onOverlayIntroDone: () => setState(() => _showIntro = false),
      ),
    );
  }
}
 
