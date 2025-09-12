import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../game/level.dart';
import '../gfx/sprites.dart';
import 'dart:ui' as ui;

enum _SelType { alien, obstacle, ship }

class DesignerPage extends StatefulWidget {
  final LevelConfig initial;
  const DesignerPage({super.key, required this.initial});

  @override
  State<DesignerPage> createState() => _DesignerPageState();
}

class _DesignerPageState extends State<DesignerPage> {
  late LevelConfig _level;

  // Alien presets (5 types)
  final List<AlienSpec> _presets = [];
  int _activeTool = 0; // 0..4 aliens, 5 obstacle, 6 ship, 7 forcefield

  // Obstacle tool params
  double _obsW = 0.18; // normalized
  double _obsH = 0.04; // normalized
  int _obsRows = 3;
  int _obsCols = 6;
  int _obsHealth = 1;
  String _obsColorHex = '#9AA0A6';

  // Ship params (editable via fields)
  late TextEditingController _shipColor;
  // Toolbar controller for scroll thumb
  final ScrollController _toolbarCtl = ScrollController();
  // Selection state
  _SelType? _selType;
  int? _selIndex; // for alien/obstacle

  // no-op

  @override
  void initState() {
    super.initState();
    _level = widget.initial;
    _initPresets();
    _shipColor = TextEditingController(text: colorToHex(_level.ship.color ?? const Color(0xFF5AA9E6)));
    // Repaint when sprites load
    SpriteStore.instance.addListener(_onSpritesChanged);
  }

  void _initPresets() {
    final defaults = [
      const Color(0xFFE84D4D), // red
      const Color(0xFF38D66B), // green
      const Color(0xFF5AA9E6), // blue
      const Color(0xFFFFCC00), // yellow
      const Color(0xFFBB66FF), // purple
    ];
    _presets.clear();
    for (int i = 0; i < 5; i++) {
      _presets.add(AlienSpec(
        x: 0.2 + i * 0.12,
        y: 0.2,
        w: 0.09,
        h: 0.05,
        health: 1,
        asset: 'assets/sprites/simple_space/aliens/alien${i + 1}.png',
        color: defaults[i],
        speed: 0,
        shooter: const ShooterSpec(power: 1, reloadSeconds: 0.8, bulletSpeed: 280),
      ));
    }
  }

  @override
  void dispose() {
    _shipColor.dispose();
    SpriteStore.instance.removeListener(_onSpritesChanged);
    super.dispose();
  }

  void _onSpritesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Designer'),
        actions: [
          IconButton(
            tooltip: 'Share JSON',
            icon: const Icon(Icons.ios_share),
            onPressed: _shareJson,
          ),
          IconButton(
            tooltip: 'Use Level',
            icon: const Icon(Icons.save),
            onPressed: () => Navigator.of(context).pop(_level),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _handleTap(d.localPosition, size),
                  onDoubleTapDown: (d) => _deleteAt(d.localPosition, size),
                  onPanStart: (d) => _panStart(d.localPosition, size),
                  onPanUpdate: (d) => _panUpdate(d.localPosition, size),
                  child: CustomPaint(
                    painter: _DesignerPainter(level: _level, selType: _selType, selIndex: _selIndex),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF000000).withValues(alpha: 0.2), border: const Border(top: BorderSide(color: Colors.white24))),
      child: Scrollbar(
        controller: _toolbarCtl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _toolbarCtl,
          scrollDirection: Axis.horizontal,
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Tool:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            for (int i = 0; i < 5; i++) _alienToolButton(i),
            _toolButton(5, Icons.shield, 'Obstacle'),
            _toolButton(6, Icons.directions_boat_filled, 'Ship'),
            _toolButton(7, Icons.shield_moon, 'ForceField'),
            const SizedBox(width: 16),
            _danceControls(),
            const SizedBox(width: 16),
            _shipControls(),
            const SizedBox(width: 16),
            if (_activeTool == 5) _obstacleControls(),
            if (_activeTool == 7) _forceFieldControls(),
          ],
          ),
        ),
      ),
    );
  }

  Widget _alienToolButton(int idx) {
    final preset = _presets[idx];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: () => _editPreset(idx),
        child: ChoiceChip(
          label: Text('Alien ${idx + 1}'),
          selected: _activeTool == idx,
          onSelected: (_) => setState(() => _activeTool = idx),
          avatar: CircleAvatar(backgroundColor: preset.color ?? Colors.white),
        ),
      ),
    );
  }

  Future<void> _editPreset(int idx) async {
    final p = _presets[idx];
    final colorCtl = TextEditingController(text: colorToHex(p.color ?? const Color(0xFF38D66B)));
    final wCtl = TextEditingController(text: (p.w * 100).toStringAsFixed(1));
    final hCtl = TextEditingController(text: (p.h * 100).toStringAsFixed(1));
    final hpCtl = TextEditingController(text: p.health.toString());
    final powerCtl = TextEditingController(text: p.shooter.power.toString());
    final reloadCtl = TextEditingController(text: p.shooter.reloadSeconds.toStringAsFixed(2));
    final bulletCtl = TextEditingController(text: p.shooter.bulletSpeed.toStringAsFixed(0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Alien ${idx + 1}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _rowField('Color', colorCtl, hint: '#RRGGBB'),
                _rowField('Width %', wCtl),
                _rowField('Height %', hCtl),
                _rowField('Health', hpCtl),
                _rowField('Power', powerCtl),
                _rowField('Reload s', reloadCtl),
                _rowField('Bullet px/s', bulletCtl),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      },
    );
    if (ok == true) {
      setState(() {
        _presets[idx] = AlienSpec(
          x: p.x,
          y: p.y,
          w: (double.tryParse(wCtl.text) ?? (p.w * 100)) / 100,
          h: (double.tryParse(hCtl.text) ?? (p.h * 100)) / 100,
          health: int.tryParse(hpCtl.text) ?? p.health,
          asset: p.asset,
          color: parseColorHex(colorCtl.text) ?? p.color,
          speed: p.speed,
          shooter: ShooterSpec(
            power: int.tryParse(powerCtl.text) ?? p.shooter.power,
            reloadSeconds: double.tryParse(reloadCtl.text) ?? p.shooter.reloadSeconds,
            bulletSpeed: double.tryParse(bulletCtl.text) ?? p.shooter.bulletSpeed,
          ),
        );
      });
    }
  }

  Widget _rowField(String label, TextEditingController ctl, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: TextField(controller: ctl, decoration: InputDecoration(isDense: true, hintText: hint)),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(int id, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _activeTool == id,
        onSelected: (_) => setState(() => _activeTool = id),
        avatar: Icon(icon, size: 18),
      ),
    );
  }

  Widget _danceControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Dance hSpeed:'),
        _numField(_level.dance.hSpeed, (v) => setState(() => _level = LevelConfig(
              id: _level.id,
              title: _level.title,
              description: _level.description,
              winMessage: _level.winMessage,
              loseMessage: _level.loseMessage,
              timeLimitSeconds: _level.timeLimitSeconds,
              winConditions: _level.winConditions,
              loseConditions: _level.loseConditions,
              aliens: _level.aliens,
              obstacles: _level.obstacles,
              ship: _level.ship,
              dance: DanceSpec(hSpeed: v, vStep: _level.dance.vStep),
            ))),
        const SizedBox(width: 8),
        const Text('vStep:'),
        _numField(_level.dance.vStep, (v) => setState(() => _level = LevelConfig(
              id: _level.id,
              title: _level.title,
              description: _level.description,
              winMessage: _level.winMessage,
              loseMessage: _level.loseMessage,
              timeLimitSeconds: _level.timeLimitSeconds,
              winConditions: _level.winConditions,
              loseConditions: _level.loseConditions,
              aliens: _level.aliens,
              obstacles: _level.obstacles,
              ship: _level.ship,
              dance: DanceSpec(hSpeed: _level.dance.hSpeed, vStep: v),
            ))),
      ],
    );
  }

  Widget _shipControls() {
    final s = _level.ship;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Ship color:'),
        SizedBox(
          width: 90,
          child: TextField(controller: _shipColor, onSubmitted: (_) => _applyShipColor(), decoration: const InputDecoration(isDense: true, hintText: '#RRGGBB')),
        ),
        const SizedBox(width: 8),
        const Text('Health:'),
        _intField(s.health, (v) => _setShip(s.copyWith(health: v))),
        const SizedBox(width: 8),
        const Text('Power:'),
        _intField(s.shooter.power, (v) => _setShip(s.copyWithShooter(power: v))),
        const SizedBox(width: 8),
        const Text('Reload:'),
        _numField(s.shooter.reloadSeconds, (v) => _setShip(s.copyWithShooter(reloadSeconds: v))),
        const SizedBox(width: 8),
        const Text('Bullet:'),
        _numField(s.shooter.bulletSpeed, (v) => _setShip(s.copyWithShooter(bulletSpeed: v))),
      ],
    );
  }

  void _setShip(ShipSpec newShip) {
    setState(() {
      _level = LevelConfig(
        id: _level.id,
        title: _level.title,
        description: _level.description,
        winMessage: _level.winMessage,
        loseMessage: _level.loseMessage,
        timeLimitSeconds: _level.timeLimitSeconds,
        winConditions: _level.winConditions,
        loseConditions: _level.loseConditions,
        aliens: _level.aliens,
        obstacles: _level.obstacles,
        ship: newShip,
        dance: _level.dance,
      );
    });
  }

  void _applyShipColor() {
    final hex = _shipColor.text.trim();
    final c = parseColorHex(hex) ?? _level.ship.color ?? const Color(0xFF5AA9E6);
    _setShip(_level.ship.copyWith(color: c));
  }

  Widget _obstacleControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('W%:'), _numField(_obsW * 100, (v) => setState(() => _obsW = v / 100)),
        const SizedBox(width: 8),
        const Text('H%:'), _numField(_obsH * 100, (v) => setState(() => _obsH = v / 100)),
        const SizedBox(width: 8),
        const Text('Rows:'), _intField(_obsRows, (v) => setState(() => _obsRows = v.clamp(1, 20))),
        const SizedBox(width: 8),
        const Text('Cols:'), _intField(_obsCols, (v) => setState(() => _obsCols = v.clamp(1, 20))),
        const SizedBox(width: 8),
        const Text('HP:'), _intField(_obsHealth, (v) => setState(() => _obsHealth = v.clamp(1, 99))),
        const SizedBox(width: 8),
        const Text('Color:'),
        SizedBox(width: 90, child: TextField(onSubmitted: (s) => setState(() => _obsColorHex = s), decoration: const InputDecoration(isDense: true, hintText: '#9AA0A6'))),
      ],
    );
  }

  Widget _numField(double value, ValueChanged<double> onChanged) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(2));
    return SizedBox(
      width: 70,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (s) => onChanged(double.tryParse(s) ?? value),
        decoration: const InputDecoration(isDense: true),
      ),
    );
  }

  Widget _intField(int value, ValueChanged<int> onChanged) {
    final ctrl = TextEditingController(text: value.toString());
    return SizedBox(
      width: 50,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onSubmitted: (s) => onChanged(int.tryParse(s) ?? value),
        decoration: const InputDecoration(isDense: true),
      ),
    );
  }

  void _handleTap(Offset pos, Size surface) {
    // If tapping an existing object, select it
    if (_selectAtTap(pos, surface)) return;
    final nx = (pos.dx / surface.width).clamp(0.0, 1.0);
    final ny = (pos.dy / surface.height).clamp(0.0, 1.0);
    setState(() {
      if (_activeTool <= 4) {
        final p = _presets[_activeTool];
        _level.aliens.add(AlienSpec(
          x: nx,
          y: ny,
          w: p.w,
          h: p.h,
          health: p.health,
          asset: p.asset,
          color: p.color,
          speed: p.speed,
          shooter: p.shooter,
        ));
      } else if (_activeTool == 5) {
        _level.obstacles.add(ObstacleSpec(
          x: nx,
          y: ny,
          w: _obsW,
          h: _obsH,
          health: _obsHealth,
          asset: null,
          color: parseColorHex(_obsColorHex),
          tileRows: _obsRows,
          tileCols: _obsCols,
        ));
      } else if (_activeTool == 7) {
        // Toggle force field present
        if (_level.forceField == null) {
          _level = LevelConfig(
            id: _level.id,
            title: _level.title,
            description: _level.description,
            winMessage: _level.winMessage,
            loseMessage: _level.loseMessage,
            timeLimitSeconds: _level.timeLimitSeconds,
            winConditions: _level.winConditions,
            loseConditions: _level.loseConditions,
            aliens: _level.aliens,
            obstacles: _level.obstacles,
            ship: _level.ship,
            dance: _level.dance,
            forceField: const ForceFieldSpec(transparent: true, health: 999999),
          );
        } else {
          _level = LevelConfig(
            id: _level.id,
            title: _level.title,
            description: _level.description,
            winMessage: _level.winMessage,
            loseMessage: _level.loseMessage,
            timeLimitSeconds: _level.timeLimitSeconds,
            winConditions: _level.winConditions,
            loseConditions: _level.loseConditions,
            aliens: _level.aliens,
            obstacles: _level.obstacles,
            ship: _level.ship,
            dance: _level.dance,
            forceField: null,
          );
        }
      } else {
        final s = _level.ship;
        _setShip(ShipSpec(
          x: nx,
          y: ny,
          w: s.w,
          h: s.h,
          health: s.health,
          asset: s.asset,
          color: s.color,
          shooter: s.shooter,
          ai: s.ai,
        ));
      }
    });
  }

  void _deleteAt(Offset pos, Size surface) {
    final tapRect = Rect.fromCenter(center: pos, width: 16, height: 16);
    setState(() {
      // delete first matching alien or obstacle
      final aw = surface.width;
      final ah = surface.height;
      _level.aliens.removeWhere((a) {
        final r = Rect.fromCenter(center: Offset(a.x * aw, a.y * ah), width: a.w * aw, height: a.h * ah);
        return r.overlaps(tapRect);
      });
      _level.obstacles.removeWhere((o) {
        final r = Rect.fromCenter(center: Offset(o.x * aw, o.y * ah), width: o.w * aw, height: o.h * ah);
        return r.overlaps(tapRect);
      });
      _selType = null;
      _selIndex = null;
    });
  }

  bool _selectAtTap(Offset pos, Size surface) {
    final aw = surface.width;
    final ah = surface.height;
    for (int i = _level.aliens.length - 1; i >= 0; i--) {
      final a = _level.aliens[i];
      final r = Rect.fromCenter(center: Offset(a.x * aw, a.y * ah), width: a.w * aw, height: a.h * ah);
      if (r.contains(pos)) {
        setState(() {
          _selType = _SelType.alien;
          _selIndex = i;
        });
        return true;
      }
    }
    for (int i = _level.obstacles.length - 1; i >= 0; i--) {
      final o = _level.obstacles[i];
      final r = Rect.fromCenter(center: Offset(o.x * aw, o.y * ah), width: o.w * aw, height: o.h * ah);
      if (r.contains(pos)) {
        setState(() {
          _selType = _SelType.obstacle;
          _selIndex = i;
        });
        return true;
      }
    }
    final s = _level.ship;
    final rs = Rect.fromCenter(center: Offset(s.x * aw, s.y * ah), width: s.w * aw, height: s.h * ah);
    if (rs.contains(pos)) {
      setState(() {
        _selType = _SelType.ship;
        _selIndex = null;
      });
      return true;
    }
    return false;
  }

  void _panStart(Offset pos, Size surface) {
    if (_selType == null) {
      _selectAtTap(pos, surface);
    }
  }

  void _panUpdate(Offset pos, Size surface) {
    if (_selType == null) return;
    final nx = (pos.dx / surface.width).clamp(0.0, 1.0);
    final ny = (pos.dy / surface.height).clamp(0.0, 1.0);
    setState(() {
      switch (_selType!) {
        case _SelType.alien:
          final i = _selIndex ?? -1;
          if (i >= 0 && i < _level.aliens.length) {
            final a = _level.aliens[i];
            final hw = a.w / 2;
            final hh = a.h / 2;
            _level.aliens[i] = AlienSpec(
              x: nx.clamp(hw, 1 - hw),
              y: ny.clamp(hh, 1 - hh),
              w: a.w,
              h: a.h,
              health: a.health,
              asset: a.asset,
              color: a.color,
              speed: a.speed,
              shooter: a.shooter,
            );
          }
          break;
        case _SelType.obstacle:
          final i = _selIndex ?? -1;
          if (i >= 0 && i < _level.obstacles.length) {
            final o = _level.obstacles[i];
            final hw = o.w / 2;
            final hh = o.h / 2;
            _level.obstacles[i] = ObstacleSpec(
              x: nx.clamp(hw, 1 - hw),
              y: ny.clamp(hh, 1 - hh),
              w: o.w,
              h: o.h,
              health: o.health,
              asset: o.asset,
              color: o.color,
              tileRows: o.tileRows,
              tileCols: o.tileCols,
            );
          }
          break;
        case _SelType.ship:
          final s = _level.ship;
          final hw = s.w / 2;
          final hh = s.h / 2;
          _setShip(s.copyWith(x: nx.clamp(hw, 1 - hw), y: ny.clamp(hh, 1 - hh)));
          break;
      }
    });
  }

  Future<void> _shareJson() async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_level.toJson());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/level_${_level.id}.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], text: 'Level: ${_level.title}');
  }

  Widget _forceFieldControls() {
    final hasFF = _level.forceField != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ForceField:'),
        const SizedBox(width: 8),
        Switch(
          value: hasFF,
          onChanged: (v) {
            setState(() {
              if (v) {
                _level = LevelConfig(
                  id: _level.id,
                  title: _level.title,
                  description: _level.description,
                  winMessage: _level.winMessage,
                  loseMessage: _level.loseMessage,
                  timeLimitSeconds: _level.timeLimitSeconds,
                  winConditions: _level.winConditions,
                  loseConditions: _level.loseConditions,
                  aliens: _level.aliens,
                  obstacles: _level.obstacles,
                  ship: _level.ship,
                  dance: _level.dance,
                  forceField: const ForceFieldSpec(transparent: true, health: 999999),
                );
              } else {
                _level = LevelConfig(
                  id: _level.id,
                  title: _level.title,
                  description: _level.description,
                  winMessage: _level.winMessage,
                  loseMessage: _level.loseMessage,
                  timeLimitSeconds: _level.timeLimitSeconds,
                  winConditions: _level.winConditions,
                  loseConditions: _level.loseConditions,
                  aliens: _level.aliens,
                  obstacles: _level.obstacles,
                  ship: _level.ship,
                  dance: _level.dance,
                  forceField: null,
                );
              }
            });
          },
        ),
        const SizedBox(width: 12),
        const Text('Transparent:'),
        const SizedBox(width: 4),
        Switch(
          value: _level.forceField?.transparent ?? true,
          onChanged: hasFF
              ? (v) => setState(() => _level = LevelConfig(
                    id: _level.id,
                    title: _level.title,
                    description: _level.description,
                    winMessage: _level.winMessage,
                    loseMessage: _level.loseMessage,
                    timeLimitSeconds: _level.timeLimitSeconds,
                    winConditions: _level.winConditions,
                    loseConditions: _level.loseConditions,
                    aliens: _level.aliens,
                    obstacles: _level.obstacles,
                    ship: _level.ship,
                    dance: _level.dance,
                    forceField: ForceFieldSpec(transparent: v, health: _level.forceField?.health ?? 999999, color: _level.forceField?.color),
                  ))
              : null,
        ),
      ],
    );
  }
}

class _DesignerPainter extends CustomPainter {
  final LevelConfig level;
  final _SelType? selType;
  final int? selIndex;
  _DesignerPainter({required this.level, required this.selType, required this.selIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // draw aliens (sprite with tint if available, else colored rect)
    for (final a in level.aliens) {
      final r = Rect.fromCenter(center: Offset(a.x * size.width, a.y * size.height), width: a.w * size.width, height: a.h * size.height);
      final path = a.asset;
      final ui.Image? img = (path != null) ? SpriteStore.instance.imageFor(path) : null;
      if (path != null && img == null) {
        // ignore: discarded_futures
        SpriteStore.instance.ensure(path);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final p = Paint()
          ..colorFilter = (a.color != null ? ColorFilter.mode(a.color!, BlendMode.modulate) : null);
        canvas.drawImageRect(img, src, r, p);
      } else {
        final paint = Paint()..color = a.color ?? const Color(0xFF38D66B);
        canvas.drawRect(r, paint);
      }
    }
    // obstacles (sprite if provided, otherwise outline)
    for (final o in level.obstacles) {
      final r = Rect.fromCenter(center: Offset(o.x * size.width, o.y * size.height), width: o.w * size.width, height: o.h * size.height);
      final path = o.asset;
      final ui.Image? img = (path != null) ? SpriteStore.instance.imageFor(path) : null;
      if (path != null && img == null) {
        // ignore: discarded_futures
        SpriteStore.instance.ensure(path);
      }
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, r, Paint());
      } else {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (o.color ?? const Color(0xFF9AA0A6)).withValues(alpha: 0.9);
        canvas.drawRect(r, paint);
      }
    }
    // ship
    final s = level.ship;
    final rs = Rect.fromCenter(center: Offset(s.x * size.width, s.y * size.height), width: s.w * size.width, height: s.h * size.height);
    final spath = s.asset;
    final ui.Image? simg = (spath != null) ? SpriteStore.instance.imageFor(spath) : null;
    if (spath != null && simg == null) {
      // ignore: discarded_futures
      SpriteStore.instance.ensure(spath);
    }
    if (simg != null) {
      final src = Rect.fromLTWH(0, 0, simg.width.toDouble(), simg.height.toDouble());
      canvas.drawImageRect(simg, src, rs, Paint());
    } else {
      final sp = Paint()..color = s.color ?? const Color(0xFF5AA9E6);
      canvas.drawRect(rs, sp);
    }

    // selection highlight
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFFFFF);
    if (selType != null) {
      switch (selType!) {
        case _SelType.alien:
          final i = selIndex ?? -1;
          if (i >= 0 && i < level.aliens.length) {
            final a = level.aliens[i];
            final r = Rect.fromCenter(center: Offset(a.x * size.width, a.y * size.height), width: a.w * size.width, height: a.h * size.height);
            canvas.drawRect(r.inflate(2), hi);
          }
          break;
        case _SelType.obstacle:
          final i = selIndex ?? -1;
          if (i >= 0 && i < level.obstacles.length) {
            final o = level.obstacles[i];
            final r = Rect.fromCenter(center: Offset(o.x * size.width, o.y * size.height), width: o.w * size.width, height: o.h * size.height);
            canvas.drawRect(r.inflate(2), hi);
          }
          break;
        case _SelType.ship:
          final s = level.ship;
          final r = Rect.fromCenter(center: Offset(s.x * size.width, s.y * size.height), width: s.w * size.width, height: s.h * size.height);
          canvas.drawRect(r.inflate(2), hi);
          break;
      }
    }

    // guide grid
    final grid = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _DesignerPainter oldDelegate) => oldDelegate.level != level;
}

extension _ShipSpecCopy on ShipSpec {
  ShipSpec copyWith({double? x, double? y, double? w, double? h, int? health, String? asset, Color? color, ShooterSpec? shooter, ShipAISpec? ai}) {
    return ShipSpec(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      health: health ?? this.health,
      asset: asset ?? this.asset,
      color: color ?? this.color,
      shooter: shooter ?? this.shooter,
      ai: ai ?? this.ai,
    );
  }

  ShipSpec copyWithShooter({int? power, double? reloadSeconds, double? bulletSpeed}) {
    return copyWith(
      shooter: ShooterSpec(
        power: power ?? shooter.power,
        reloadSeconds: reloadSeconds ?? shooter.reloadSeconds,
        bulletSpeed: bulletSpeed ?? shooter.bulletSpeed,
      ),
    );
  }
}


