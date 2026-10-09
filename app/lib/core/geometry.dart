import 'dart:math' as math;

/// Immutable 2D vector in metres (x = east, y = north).
class Vec2 {
  final double x;
  final double y;
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 o) => x * o.x + y * o.y;
  double cross(Vec2 o) => x * o.y - y * o.x;
  double get length => math.sqrt(x * x + y * y);
  double get length2 => x * x + y * y;
  double distanceTo(Vec2 o) => (this - o).length;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? Vec2.zero : Vec2(x / l, y / l);
  }

  /// Left-hand perpendicular (rotated +90°).
  Vec2 get perp => Vec2(-y, x);

  /// Angle in radians from the +x axis, counter-clockwise.
  double get angle => math.atan2(y, x);

  Vec2 copyWithX(double v) => Vec2(v, y);
  Vec2 copyWithY(double v) => Vec2(x, v);

  Vec2 lerp(Vec2 o, double t) => Vec2(x + (o.x - x) * t, y + (o.y - y) * t);

  List<double> toJson() => [_r(x), _r(y)];
  static Vec2 fromJson(List<dynamic> j) => Vec2((j[0] as num).toDouble(), (j[1] as num).toDouble());

  @override
  bool operator ==(Object other) => other is Vec2 && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

double _r(double v) => (v * 1000).roundToDouble() / 1000;

double polylineLength(List<Vec2> pts) {
  var l = 0.0;
  for (var i = 0; i + 1 < pts.length; i++) {
    l += pts[i].distanceTo(pts[i + 1]);
  }
  return l;
}

/// Closest point on segment [a, b] to p, with its parameter t in [0, 1].
({Vec2 point, double t}) projectOnSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final l2 = ab.length2;
  if (l2 == 0) return (point: a, t: 0);
  final t = ((p - a).dot(ab) / l2).clamp(0.0, 1.0);
  return (point: a + ab * t, t: t);
}

/// Closest point on a polyline: the point, segment index, and distance from p.
({Vec2 point, int segment, double distance, double along}) projectOnPolyline(Vec2 p, List<Vec2> pts) {
  var best = (point: pts.first, segment: 0, distance: double.infinity, along: 0.0);
  var walked = 0.0;
  for (var i = 0; i + 1 < pts.length; i++) {
    final pr = projectOnSegment(p, pts[i], pts[i + 1]);
    final d = pr.point.distanceTo(p);
    final segLen = pts[i].distanceTo(pts[i + 1]);
    if (d < best.distance) {
      best = (point: pr.point, segment: i, distance: d, along: walked + segLen * pr.t);
    }
    walked += segLen;
  }
  return best;
}

/// Proper intersection of segments p1-p2 and q1-q2 (excluding touching end points).
({Vec2 point, double t, double u})? segmentIntersection(Vec2 p1, Vec2 p2, Vec2 q1, Vec2 q2, {double eps = 1e-6}) {
  final r = p2 - p1;
  final s = q2 - q1;
  final denom = r.cross(s);
  if (denom.abs() < 1e-12) return null;
  final t = (q1 - p1).cross(s) / denom;
  final u = (q1 - p1).cross(r) / denom;
  if (t <= eps || t >= 1 - eps || u <= eps || u >= 1 - eps) return null;
  return (point: p1 + r * t, t: t, u: u);
}

/// Offset a polyline sideways by [d] metres (positive = to the left of the direction of travel).
/// Uses mitred joins, limited to avoid spikes at sharp corners.
List<Vec2> offsetPolyline(List<Vec2> pts, double d) {
  if (pts.length < 2 || d == 0) return List.of(pts);
  final out = <Vec2>[];
  for (var i = 0; i < pts.length; i++) {
    final Vec2 n;
    if (i == 0) {
      n = (pts[1] - pts[0]).normalized.perp;
    } else if (i == pts.length - 1) {
      n = (pts[i] - pts[i - 1]).normalized.perp;
    } else {
      final n1 = (pts[i] - pts[i - 1]).normalized.perp;
      final n2 = (pts[i + 1] - pts[i]).normalized.perp;
      final m = (n1 + n2).normalized;
      final cos = m.dot(n1);
      final scale = cos.abs() < 0.25 ? 4.0 : 1 / cos;
      out.add(pts[i] + m * (d * scale));
      continue;
    }
    out.add(pts[i] + n * d);
  }
  return out;
}

/// Point at arc length [s] along the polyline and the tangent direction there.
({Vec2 point, Vec2 dir}) pointAlong(List<Vec2> pts, double s) {
  var remaining = s;
  for (var i = 0; i + 1 < pts.length; i++) {
    final seg = pts[i].distanceTo(pts[i + 1]);
    if (remaining <= seg || i == pts.length - 2) {
      final t = seg == 0 ? 0.0 : (remaining / seg).clamp(0.0, 1.0);
      return (point: pts[i].lerp(pts[i + 1], t), dir: (pts[i + 1] - pts[i]).normalized);
    }
    remaining -= seg;
  }
  return (point: pts.last, dir: Vec2.zero);
}

/// Split a polyline at arc length [s]; both halves contain the split point.
(List<Vec2>, List<Vec2>) splitPolylineAt(List<Vec2> pts, double s) {
  var remaining = s;
  for (var i = 0; i + 1 < pts.length; i++) {
    final seg = pts[i].distanceTo(pts[i + 1]);
    if (remaining <= seg || i == pts.length - 2) {
      final t = seg == 0 ? 0.0 : (remaining / seg).clamp(0.0, 1.0);
      final p = pts[i].lerp(pts[i + 1], t);
      return ([...pts.sublist(0, i + 1), p], [p, ...pts.sublist(i + 1)]);
    }
    remaining -= seg;
  }
  return (List.of(pts), [pts.last]);
}

/// Ramer–Douglas–Peucker simplification.
List<Vec2> simplify(List<Vec2> pts, double tolerance) {
  if (pts.length < 3) return List.of(pts);
  var maxD = 0.0;
  var idx = 0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = projectOnSegment(pts[i], pts.first, pts.last).point.distanceTo(pts[i]);
    if (d > maxD) {
      maxD = d;
      idx = i;
    }
  }
  if (maxD <= tolerance) return [pts.first, pts.last];
  final left = simplify(pts.sublist(0, idx + 1), tolerance);
  final right = simplify(pts.sublist(idx), tolerance);
  return [...left.sublist(0, left.length - 1), ...right];
}

/// Smooth a control polyline with a centripetal-ish Catmull–Rom spline, keeping the end points.
List<Vec2> catmullRom(List<Vec2> ctrl, {double spacing = 4.0}) {
  if (ctrl.length < 3) return List.of(ctrl);
  final out = <Vec2>[ctrl.first];
  for (var i = 0; i + 1 < ctrl.length; i++) {
    final p0 = i == 0 ? ctrl[0] : ctrl[i - 1];
    final p1 = ctrl[i];
    final p2 = ctrl[i + 1];
    final p3 = i + 2 < ctrl.length ? ctrl[i + 2] : ctrl[i + 1];
    final n = math.max(2, (p1.distanceTo(p2) / spacing).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      final t2 = t * t, t3 = t2 * t;
      out.add((p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (-p0 + p1 * 3 - p2 * 3 + p3) * t3) * 0.5);
    }
  }
  return out;
}

/// Polygon area (shoelace), absolute value, square metres.
double polygonArea(List<Vec2> pts) {
  if (pts.length < 3) return 0;
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    a += pts[i].cross(pts[(i + 1) % pts.length]);
  }
  return a.abs() / 2;
}

/// Compass bearing in degrees (0 = north, clockwise) of the direction a→b.
double bearingDeg(Vec2 a, Vec2 b) {
  final d = b - a;
  final deg = math.atan2(d.x, d.y) * 180 / math.pi;
  return (deg + 360) % 360;
}

double degToRad(double d) => d * math.pi / 180;
double radToDeg(double r) => r * 180 / math.pi;

/// Normalise an angle to (-pi, pi].
double wrapAngle(double a) {
  var x = a;
  while (x <= -math.pi) {
    x += 2 * math.pi;
  }
  while (x > math.pi) {
    x -= 2 * math.pi;
  }
  return x;
}
