import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import '../util/log.dart';

class ShooterSpec {
  final int power;
  final double reloadSeconds;
  final double bulletSpeed;

  const ShooterSpec({required this.power, required this.reloadSeconds, required this.bulletSpeed});

  factory ShooterSpec.fromJson(Map<String, dynamic> j) => ShooterSpec(
        power: (j['power'] ?? 1) as int,
        reloadSeconds: (j['reloadSeconds'] ?? 1.0).toDouble(),
        bulletSpeed: (j['bulletSpeed'] ?? 280).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'power': power,
        'reloadSeconds': reloadSeconds,
        'bulletSpeed': bulletSpeed,
      };
}

class AlienSpec {
  final double x; // normalized 0..1 (center)
  final double y; // normalized 0..1 (center)
  final double w; // normalized width
  final double h; // normalized height
  final int health;
  final String? asset;
  final Color? color;
  final double speed; // reserved for movement
  final ShooterSpec shooter;

  AlienSpec({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.health,
    required this.asset,
    required this.color,
    required this.speed,
    required this.shooter,
  });

  factory AlienSpec.fromJson(Map<String, dynamic> j) => AlienSpec(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        health: (j['health'] ?? 1) as int,
        asset: j['asset'] as String?,
        color: _parseColor(j['color']),
        speed: (j['speed'] ?? 0).toDouble(),
        shooter: ShooterSpec.fromJson(j['shooter'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'health': health,
        'asset': asset,
        'color': color == null ? null : colorToHex(color!),
        'speed': speed,
        'shooter': shooter.toJson(),
      }..removeWhere((k, v) => v == null);
}

class ObstacleSpec {
  final double x;
  final double y;
  final double w;
  final double h;
  final int health;
  final String? asset;
  final Color? color;
  final int tileRows;
  final int tileCols;

  ObstacleSpec({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.health,
    required this.asset,
    required this.color,
    this.tileRows = 1,
    this.tileCols = 1,
  });

  factory ObstacleSpec.fromJson(Map<String, dynamic> j) => ObstacleSpec(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        health: (j['health'] ?? 5) as int,
        asset: j['asset'] as String?,
        color: _parseColor(j['color']),
        tileRows: (j['tileRows'] ?? 1) is num ? (j['tileRows'] as num).toInt() : 1,
        tileCols: (j['tileCols'] ?? 1) is num ? (j['tileCols'] as num).toInt() : 1,
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'health': health,
        'asset': asset,
        'color': color == null ? null : colorToHex(color!),
        'tileRows': tileRows,
        'tileCols': tileCols,
      }..removeWhere((k, v) => v == null);
}

class ShipAISpec {
  final double moveChancePerSecond;
  final double avoidChance;
  final double moveSpeed;

  const ShipAISpec({required this.moveChancePerSecond, required this.avoidChance, required this.moveSpeed});

  factory ShipAISpec.fromJson(Map<String, dynamic> j) => ShipAISpec(
        moveChancePerSecond: (j['moveChancePerSecond'] ?? 0.5).toDouble(),
        avoidChance: (j['avoidChance'] ?? 0.5).toDouble(),
        moveSpeed: (j['moveSpeed'] ?? 220).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'moveChancePerSecond': moveChancePerSecond,
        'avoidChance': avoidChance,
        'moveSpeed': moveSpeed,
      };
}

class ShipSpec {
  final double x;
  final double y;
  final double w;
  final double h;
  final int health;
  final String? asset;
  final Color? color;
  final ShooterSpec shooter;
  final ShipAISpec ai;

  ShipSpec({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.health,
    required this.asset,
    required this.color,
    required this.shooter,
    required this.ai,
  });

  factory ShipSpec.fromJson(Map<String, dynamic> j) => ShipSpec(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        health: (j['health'] ?? 3) as int,
        asset: j['asset'] as String?,
        color: _parseColor(j['color']),
        shooter: ShooterSpec.fromJson(j['shooter'] as Map<String, dynamic>? ?? const {}),
        ai: ShipAISpec.fromJson(j['ai'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'health': health,
        'asset': asset,
        'color': color == null ? null : colorToHex(color!),
        'shooter': shooter.toJson(),
        'ai': ai.toJson(),
      }..removeWhere((k, v) => v == null);
}

enum ConditionKind { shipDestroyed, aliensDestroyed, surviveTime, timerElapsed }

ConditionKind _parseCondition(String s) {
  switch (s) {
    case 'ship_destroyed':
      return ConditionKind.shipDestroyed;
    case 'aliens_destroyed':
      return ConditionKind.aliensDestroyed;
    case 'survive_time':
      return ConditionKind.surviveTime;
    case 'timer_elapsed':
      return ConditionKind.timerElapsed;
  }
  return ConditionKind.shipDestroyed;
}

class LevelConfig {
  final String id;
  final String title;
  final String description;
  final String winMessage;
  final String loseMessage;
  final double? timeLimitSeconds;
  final List<ConditionKind> winConditions;
  final List<ConditionKind> loseConditions;
  final List<AlienSpec> aliens;
  final List<ObstacleSpec> obstacles;
  final ShipSpec ship;
  final DanceSpec dance;

  LevelConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.winMessage,
    required this.loseMessage,
    required this.timeLimitSeconds,
    required this.winConditions,
    required this.loseConditions,
    required this.aliens,
    required this.obstacles,
    required this.ship,
    required this.dance,
  });

  factory LevelConfig.fromJson(Map<String, dynamic> j) => LevelConfig(
        id: (j['id'] ?? 'level').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        winMessage: (j['winMessage'] ?? 'You win!').toString(),
        loseMessage: (j['loseMessage'] ?? 'You lose!').toString(),
        timeLimitSeconds: (j['timeLimitSeconds'] as num?)?.toDouble(),
        winConditions: ((j['winConditions'] as List?) ?? ['ship_destroyed']).map((e) => _parseCondition(e.toString())).toList(),
        loseConditions: ((j['loseConditions'] as List?) ?? ['timer_elapsed']).map((e) => _parseCondition(e.toString())).toList(),
        aliens: ((j['aliens'] as List?) ?? []).map((e) => AlienSpec.fromJson(Map<String, dynamic>.from(e))).toList(),
        obstacles: ((j['obstacles'] as List?) ?? []).map((e) => ObstacleSpec.fromJson(Map<String, dynamic>.from(e))).toList(),
        ship: ShipSpec.fromJson(Map<String, dynamic>.from(j['ship'] as Map? ?? {})),
        dance: DanceSpec.fromJson(Map<String, dynamic>.from(j['dance'] as Map? ?? {})),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'winMessage': winMessage,
        'loseMessage': loseMessage,
        'timeLimitSeconds': timeLimitSeconds,
        'winConditions': winConditions.map((e) => _conditionToString(e)).toList(),
        'loseConditions': loseConditions.map((e) => _conditionToString(e)).toList(),
        'aliens': aliens.map((e) => e.toJson()).toList(),
        'obstacles': obstacles.map((e) => e.toJson()).toList(),
        'ship': ship.toJson(),
        'dance': dance.toJson(),
      }..removeWhere((k, v) => v == null);

  static Future<LevelConfig> loadFromAsset(String assetPath) async {
    logv('Level', 'Loading asset: $assetPath');
    final raw = await rootBundle.loadString(assetPath);
    logv('Level', 'Loaded ${raw.length} chars. Stripping comments...');
    final cleaned = _stripComments(raw);
    final map = json.decode(cleaned) as Map<String, dynamic>;
    logv('Level', 'Parsed JSON, building LevelConfig...');
    final lvl = LevelConfig.fromJson(map);
    logv('Level', 'Level loaded: id=${lvl.id}, aliens=${lvl.aliens.length}, obstacles=${lvl.obstacles.length}');
    return lvl;
  }
}

class DanceSpec {
  final double hSpeed; // horizontal speed in px/s
  final double vStep; // vertical step in px when bouncing

  const DanceSpec({this.hSpeed = 0, this.vStep = 0});

  factory DanceSpec.fromJson(Map<String, dynamic> j) => DanceSpec(
        hSpeed: (j['hSpeed'] ?? 0).toDouble(),
        vStep: (j['vStep'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'hSpeed': hSpeed,
        'vStep': vStep,
      };
}

Color? _parseColor(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  // Accept formats like "#RRGGBB" or "#AARRGGBB"
  String hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}

String _stripComments(String input) {
  // Remove /* */ block comments and // line comments (outside of strings in most simple cases)
  final noBlock = input.replaceAll(RegExp(r"/\*.*?\*/", dotAll: true), "");
  final noLine = noBlock.replaceAll(RegExp(r"^\s*//.*", multiLine: true), "");
  return noLine;
}

String colorToHex(Color c, {bool includeAlpha = false}) {
  // Prefer channel accessors to avoid deprecation warnings
  final a = includeAlpha ? ((c.a * 255.0).round() & 0xff) : 0xff;
  final r = (c.r * 255.0).round() & 0xff;
  final g = (c.g * 255.0).round() & 0xff;
  final b = (c.b * 255.0).round() & 0xff;
  final v = (a << 24) | (r << 16) | (g << 8) | b;
  final full = v.toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${includeAlpha ? full : full.substring(2)}';
}

Color? parseColorHex(String? s) => _parseColor(s);

String _conditionToString(ConditionKind k) {
  switch (k) {
    case ConditionKind.shipDestroyed:
      return 'ship_destroyed';
    case ConditionKind.aliensDestroyed:
      return 'aliens_destroyed';
    case ConditionKind.surviveTime:
      return 'survive_time';
    case ConditionKind.timerElapsed:
      return 'timer_elapsed';
  }
}
