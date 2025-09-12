import 'dart:ui';
import '../game/projectile.dart';

class ForceField {
  bool transparent;
  int health;
  final Color color;
  double thickness;
  Path path = Path();
  List<Offset> _polyline = const [];
  double _hitStart = -1;
  bool alive = true;
  final double _hitThickness = 20.0;

  ForceField({required this.transparent, required this.health, required this.color, this.thickness = 3});

  void layout(Size size, Rect shipRect) {
    final baseY = (shipRect.top - size.height * 0.035).clamp(0.0, size.height);
    final arcH = size.height * 0.05;
    final c1 = Offset(size.width / 3, baseY - arcH);
    final c2 = Offset(2 * size.width / 3, baseY - arcH);
    final p0 = Offset(0, baseY);
    final p3 = Offset(size.width, baseY);
    final p = Path()..moveTo(p0.dx, p0.dy)..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy);
    path = p;
    const steps = 48;
    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      pts.add(_cubicPoint(p0, c1, c2, p3, t));
    }
    _polyline = pts;
  }

  bool hitTest(Projectile proj) {
    if (!alive) return false;
    final pt = proj.center;
    double minD2 = double.infinity;
    for (int i = 0; i + 1 < _polyline.length; i++) {
      final a = _polyline[i];
      final b = _polyline[i + 1];
      final d2 = _pointToSegmentDist2(pt, a, b);
      if (d2 < minD2) minD2 = d2;
    }
    final rad = (_hitThickness / 2) + (proj.size.shortestSide / 2);
    return minD2 <= rad * rad;
  }

  void onHit(double now, int damage) {
    _hitStart = now;
    health -= damage;
    if (health <= 0) alive = false;
  }

  double glowWidth(double now) {
    if (_hitStart < 0) return 0;
    final t = now - _hitStart;
    if (t < 0) return 0;
    if (t < 0.05) return 0;
    if (t < 0.15) return 3;
    if (t < 0.25) return 1;
    _hitStart = -1;
    return 0;
  }

  static Offset _cubicPoint(Offset p0, Offset c1, Offset c2, Offset p3, double t) {
    final mt = 1 - t;
    final x = mt * mt * mt * p0.dx + 3 * mt * mt * t * c1.dx + 3 * mt * t * t * c2.dx + t * t * t * p3.dx;
    final y = mt * mt * mt * p0.dy + 3 * mt * mt * t * c1.dy + 3 * mt * t * t * c2.dy + t * t * t * p3.dy;
    return Offset(x, y);
  }

  static double _pointToSegmentDist2(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy + 1e-6);
    final tt = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * tt, a.dy + ab.dy * tt);
    final dx = p.dx - proj.dx;
    final dy = p.dy - proj.dy;
    return dx * dx + dy * dy;
  }
}
