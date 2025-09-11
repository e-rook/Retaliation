import 'level.dart';

class LevelValidationResult {
  final List<String> errors;
  bool get isValid => errors.isEmpty;
  LevelValidationResult(this.errors);
}

LevelValidationResult validateLevel(LevelConfig lvl) {
  final e = <String>[];

  bool in01(double v) => v >= 0 && v <= 1;
  bool pos(double v) => v > 0;
  bool posInt(int v) => v > 0;

  // Time limit
  final t = lvl.timeLimitSeconds;
  if (t != null && t <= 0) e.add('timeLimitSeconds must be > 0');

  // Dance
  if (lvl.dance.hSpeed < 0) e.add('dance.hSpeed must be >= 0');
  if (lvl.dance.vStep < 0) e.add('dance.vStep must be >= 0');

  // Ship
  final s = lvl.ship;
  if (!in01(s.x) || !in01(s.y)) e.add('ship x,y must be in [0,1]');
  if (!pos(s.w) || !pos(s.h) || s.w > 1 || s.h > 1) e.add('ship w,h must be in (0,1]');
  if (!posInt(s.health)) e.add('ship health must be > 0');
  if (!posInt(s.shooter.power)) e.add('ship shooter.power must be > 0');
  if (!pos(s.shooter.reloadSeconds)) e.add('ship shooter.reloadSeconds must be > 0');
  if (!pos(s.shooter.bulletSpeed)) e.add('ship shooter.bulletSpeed must be > 0');

  // Aliens
  for (var i = 0; i < lvl.aliens.length; i++) {
    final a = lvl.aliens[i];
    if (!in01(a.x) || !in01(a.y)) e.add('alien[$i] x,y must be in [0,1]');
    if (!pos(a.w) || !pos(a.h) || a.w > 1 || a.h > 1) e.add('alien[$i] w,h must be in (0,1]');
    if (!posInt(a.health)) e.add('alien[$i] health must be > 0');
    if (!posInt(a.shooter.power)) e.add('alien[$i] shooter.power must be > 0');
    if (!pos(a.shooter.reloadSeconds)) e.add('alien[$i] shooter.reloadSeconds must be > 0');
    if (!pos(a.shooter.bulletSpeed)) e.add('alien[$i] shooter.bulletSpeed must be > 0');
  }

  // Obstacles
  for (var i = 0; i < lvl.obstacles.length; i++) {
    final o = lvl.obstacles[i];
    if (!in01(o.x) || !in01(o.y)) e.add('obstacle[$i] x,y must be in [0,1]');
    if (!pos(o.w) || !pos(o.h) || o.w > 1 || o.h > 1) e.add('obstacle[$i] w,h must be in (0,1]');
    if (!posInt(o.health)) e.add('obstacle[$i] health must be > 0');
    if (o.tileRows <= 0 || o.tileCols <= 0) e.add('obstacle[$i] tileRows/tileCols must be >= 1');
  }

  return LevelValidationResult(e);
}

