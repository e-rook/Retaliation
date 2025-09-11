import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

class Projectile {
  Offset position; // center position
  final double speed; // logical px per second
  final double width;
  final double height;

  Projectile({
    required this.position,
    required this.speed,
    this.width = 4,
    this.height = 12,
  });

  Rect get rect => Rect.fromCenter(center: position, width: width, height: height);
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
  List<Rect> _aliens = [];
  Rect _ship = Rect.zero;
  final List<Projectile> _projectiles = [];

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

    if (_projectiles.isEmpty) return;

    bool changed = false;
    for (final p in _projectiles) {
      p.position = Offset(p.position.dx, p.position.dy + _projectileSpeed * dt);
      changed = true;
    }
    // Remove projectiles off-screen
    _projectiles.removeWhere((p) => p.position.dy - p.height / 2 > _size.height);

    if (changed) setState(() {});
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

    final aliens = <Rect>[];
    for (int r = 0; r < alienRows; r++) {
      for (int c = 0; c < alienCols; c++) {
        final x = startX + c * (alienW + size.width * _colSpacingFactor);
        final y = top + r * (alienH + rowGap);
        aliens.add(Rect.fromLTWH(x, y, alienW, alienH));
      }
    }
    _aliens = aliens;

    final shipW = size.width * _shipWidthFactor;
    final shipH = size.height * _shipHeightFactor;
    _ship = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - shipH * 1.5),
      width: shipW,
      height: shipH,
    );
    // Do not call setState here; we're in the build/layout phase via LayoutBuilder.
    // The new geometry is immediately used in this build pass.
  }

  void _handleTap(TapDownDetails details) {
    final pos = details.localPosition;
    for (final alien in _aliens) {
      if (alien.contains(pos)) {
        // Fire a projectile from the bottom-center of the tapped alien
        final start = Offset(alien.center.dx, alien.bottom + 6);
        _projectiles.add(Projectile(position: start, speed: _projectileSpeed));
        setState(() {});
        break;
      }
    }
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
                  ship: _ship,
                  projectiles: _projectiles,
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
  final List<Rect> aliens;
  final Rect ship;
  final List<Projectile> projectiles;

  _GamePainter({required this.aliens, required this.ship, required this.projectiles});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Aliens
    final alienPaint = Paint()..color = const Color(0xFF38D66B);
    for (final rect in aliens) {
      canvas.drawRect(rect, alienPaint);
    }

    // Ship
    final shipPaint = Paint()..color = const Color(0xFF5AA9E6);
    canvas.drawRect(ship, shipPaint);

    // Projectiles
    final projPaint = Paint()..color = const Color(0xFFE84D4D);
    for (final p in projectiles) {
      canvas.drawRect(p.rect, projPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return oldDelegate.aliens != aliens ||
        oldDelegate.ship != ship ||
        oldDelegate.projectiles != projectiles;
  }
}
