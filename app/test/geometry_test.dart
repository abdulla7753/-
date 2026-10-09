import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roadflow_ai/core/geometry.dart';

void main() {
  test('offsetPolyline shifts a straight line to the left', () {
    final out = offsetPolyline(const [Vec2(0, 0), Vec2(10, 0)], 2);
    expect(out[0], const Vec2(0, 2));
    expect(out[1], const Vec2(10, 2));
  });

  test('offsetPolyline keeps constant distance around a right-angle corner', () {
    final out = offsetPolyline(const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)], -1);
    // Mitre point of a 90° corner offset by 1 m lies sqrt(2) m from the corner.
    expect(out[1].distanceTo(const Vec2(10, 0)), closeTo(math.sqrt2, 1e-9));
  });

  test('segmentIntersection finds proper crossings only', () {
    final hit = segmentIntersection(const Vec2(-5, 0), const Vec2(5, 0), const Vec2(0, -5), const Vec2(0, 5));
    expect(hit, isNotNull);
    expect(hit!.point.x, closeTo(0, 1e-9));
    expect(hit.t, closeTo(0.5, 1e-9));
    // Touching at an end point is not a crossing.
    expect(segmentIntersection(const Vec2(0, 0), const Vec2(5, 0), const Vec2(5, 0), const Vec2(5, 5)), isNull);
    // Parallel segments never intersect.
    expect(segmentIntersection(const Vec2(0, 0), const Vec2(5, 0), const Vec2(0, 1), const Vec2(5, 1)), isNull);
  });

  test('splitPolylineAt preserves total length', () {
    const pts = [Vec2(0, 0), Vec2(100, 0), Vec2(100, 50)];
    final (a, b) = splitPolylineAt(pts, 120);
    expect(a.last, const Vec2(100, 20));
    expect(b.first, a.last);
    expect(polylineLength(a) + polylineLength(b), closeTo(150, 1e-9));
  });

  test('projectOnPolyline returns along-distance', () {
    final p = projectOnPolyline(const Vec2(50, 3), const [Vec2(0, 0), Vec2(100, 0)]);
    expect(p.along, closeTo(50, 1e-9));
    expect(p.distance, closeTo(3, 1e-9));
  });

  test('simplify removes collinear noise', () {
    final noisy = [for (var i = 0; i <= 20; i++) Vec2(i.toDouble(), i.isEven ? 0.05 : -0.05)];
    expect(simplify(noisy, 0.2).length, 2);
  });

  test('catmullRom passes through control points and ends', () {
    const ctrl = [Vec2(0, 0), Vec2(50, 20), Vec2(100, 0)];
    final s = catmullRom(ctrl, spacing: 5);
    expect(s.first, ctrl.first);
    expect(s.last.distanceTo(ctrl.last), lessThan(1e-9));
    expect(s.any((p) => p.distanceTo(ctrl[1]) < 1e-6), isTrue);
  });

  test('polygon area and compass bearing', () {
    expect(polygonArea(const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 5), Vec2(0, 5)]), closeTo(50, 1e-9));
    expect(bearingDeg(Vec2.zero, const Vec2(0, 10)), closeTo(0, 1e-9));
    expect(bearingDeg(Vec2.zero, const Vec2(10, 0)), closeTo(90, 1e-9));
    expect(bearingDeg(Vec2.zero, const Vec2(-10, 0)), closeTo(270, 1e-9));
  });
}
