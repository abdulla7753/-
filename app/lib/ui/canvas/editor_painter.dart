import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../editor/editor_controller.dart';
import '../../editor/network_ops.dart';
import '../../model/network.dart';
import 'road_drawing.dart';
import 'viewport.dart';

/// Lane-boundary offsets of a road (metres, positive = left of the from->to direction).
class RoadCrossSection {
  final double leftEdge;
  final double rightEdge;

  /// Offsets of lane separators within the same direction.
  final List<double> separators;

  /// Offset of the line between opposing directions, if two-way.
  final double? centre;

  /// Offsets bounding forward lanes (toward `to`) and backward lanes.
  final (double, double)? forward;
  final (double, double)? backward;

  const RoadCrossSection(this.leftEdge, this.rightEdge, this.separators, this.centre, this.forward, this.backward);

  factory RoadCrossSection.of(Road r, DrivingSide side) {
    final w = r.laneWidthM;
    final f = r.forward.lanes, b = r.backward.lanes;
    final sign = side == DrivingSide.right ? 1.0 : -1.0;
    if (f > 0 && b > 0) {
      // Forward lanes on the driving side of the centreline, backward lanes on the other.
      final seps = <double>[for (var k = 1; k < f; k++) -sign * k * w, for (var k = 1; k < b; k++) sign * k * w];
      final fwd = (0.0, -sign * f * w), bwd = (0.0, sign * b * w);
      final edges = [-sign * f * w, sign * b * w]..sort();
      return RoadCrossSection(edges[1], edges[0], seps, 0, fwd, bwd);
    }
    final n = math.max(f, b);
    final half = n * w / 2;
    final seps = <double>[for (var k = 1; k < n; k++) half - k * w];
    return RoadCrossSection(half, -half, seps, null, f > 0 ? (half, -half) : null, b > 0 ? (half, -half) : null);
  }

  double get halfWidth => math.max(leftEdge.abs(), rightEdge.abs());
}

class DraftState {
  final List<Vec2> points;
  final SnapTarget? start;
  final SnapTarget? end;
  const DraftState(this.points, this.start, this.end);
}

class EditorPainter extends CustomPainter {
  final Network net;
  final MapViewport vp;
  final Selection? selection;
  final EditorTool tool;
  final DraftState? draft;
  final List<Vec2> measure;
  final Map<String, String> gateLabels;
  final double draftWidthM;
  final bool dark;

  EditorPainter({
    required this.net,
    required this.vp,
    required this.selection,
    required this.tool,
    required this.draft,
    required this.measure,
    required this.gateLabels,
    required this.draftWidthM,
    this.dark = false,
  }) : super(repaint: vp);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? RoadColors.groundDark : RoadColors.ground);
    drawGrid(canvas, size, vp);
    final asphalt = Paint()..color = RoadColors.asphalt;

    // Road surfaces, turn bays and junction patches.
    for (final r in net.roads.values) {
      final pts = net.polyline(r);
      final cs = RoadCrossSection.of(r, net.drivingSide);
      canvas.drawPath(bandPath(vp, offsetPolyline(pts, cs.leftEdge), offsetPolyline(pts, cs.rightEdge)), asphalt);
      _drawBays(canvas, r, pts, cs, asphalt);
    }
    for (final n in net.nodes.values) {
      final deg = net.degree(n.id);
      if (deg >= 2 && n.control != NodeControl.roundabout) {
        final rad = net.roadsAt(n.id).map((r) => RoadCrossSection.of(r, net.drivingSide).halfWidth).fold(0.0, math.max);
        canvas.drawCircle(vp.toScreen(n.pos), vp.px(rad * 1.15), asphalt);
      }
    }
    for (final n in net.nodes.values.where((n) => n.control == NodeControl.roundabout)) {
      _drawRoundabout(canvas, n, asphalt);
    }

    // Markings when zoomed in enough to be legible.
    if (vp.scale > 0.7) {
      for (final r in net.roads.values) {
        _drawMarkings(canvas, r);
      }
    }

    _drawSelection(canvas);
    _drawNodes(canvas);
    _drawDraft(canvas);
    _drawMeasure(canvas);
  }

  void _drawBays(Canvas canvas, Road r, List<Vec2> pts, RoadCrossSection cs, Paint paint) {
    final len = polylineLength(pts);
    void bay(Direction d, (double, double)? span, bool atEnd) {
      if (span == null || d.lanes == 0) return;
      final extra = (d.leftBay?.lanes ?? 0) + (d.rightBay?.lanes ?? 0);
      if (extra == 0) return;
      final bayLen = math.min(math.max(d.leftBay?.lengthM ?? 0, d.rightBay?.lengthM ?? 0), len);
      final (head, tail) = splitPolylineAt(pts, atEnd ? len - bayLen : bayLen);
      final seg = atEnd ? tail : head;
      final outer = span.$2;
      final sign = outer < 0 ? -1.0 : 1.0;
      final widened = outer + sign * extra * r.laneWidthM;
      canvas.drawPath(bandPath(vp, offsetPolyline(seg, outer), offsetPolyline(seg, widened)), paint);
      if (vp.scale > 0.7) {
        final edge = Paint()
          ..color = RoadColors.marking
          ..strokeWidth = math.max(1, vp.px(0.15))
          ..style = PaintingStyle.stroke;
        canvas.drawPath(polylinePath(vp, offsetPolyline(seg, widened)), edge);
        drawDashed(canvas, vp, offsetPolyline(seg, outer), edge, dashM: 2, gapM: 2);
      }
    }

    bay(r.forward, cs.forward, true);
    bay(r.backward, cs.backward, false);
  }

  void _drawRoundabout(Canvas canvas, RoadNode n, Paint asphalt) {
    final spec = n.roundabout ?? const RoundaboutSpec();
    final c = vp.toScreen(n.pos);
    final width = spec.lanes * spec.laneWidthM;
    canvas.drawCircle(c, vp.px(spec.radiusM + width / 2), asphalt);
    canvas.drawCircle(c, vp.px(math.max(spec.radiusM - width / 2, 1)), Paint()..color = RoadColors.island);
    if (vp.scale > 0.7) {
      final p = Paint()
        ..color = RoadColors.marking
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, vp.px(0.15));
      for (var k = 1; k < spec.lanes; k++) {
        final rr = spec.radiusM - width / 2 + k * spec.laneWidthM;
        final ring = [for (var a = 0; a <= 72; a++) n.pos + Vec2(math.cos(a * math.pi / 36), math.sin(a * math.pi / 36)) * rr];
        drawDashed(canvas, vp, ring, p);
      }
      // Circulation arrows: counter-clockwise for right-hand traffic.
      final ccw = net.drivingSide == DrivingSide.right;
      final arrow = Paint()
        ..color = RoadColors.marking
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, vp.px(0.25));
      for (var k = 0; k < 4; k++) {
        final a = k * math.pi / 2 + math.pi / 4;
        final p = n.pos + Vec2(math.cos(a), math.sin(a)) * spec.radiusM;
        final tangent = Vec2(-math.sin(a), math.cos(a)) * (ccw ? 1 : -1);
        drawChevron(canvas, vp, p, tangent, math.min(3.0, spec.laneWidthM), arrow);
      }
    }
  }

  /// Radius of the junction patch drawn at [nodeId] (0 for road ends and simple bends).
  double _junctionRadius(String nodeId) {
    final n = net.nodes[nodeId]!;
    if (n.control == NodeControl.roundabout) {
      final rb = n.roundabout ?? const RoundaboutSpec();
      return rb.radiusM + rb.lanes * rb.laneWidthM / 2;
    }
    if (net.degree(nodeId) < 3 && n.control != NodeControl.trafficLight) return 0;
    return net.roadsAt(nodeId).map((x) => RoadCrossSection.of(x, net.drivingSide).halfWidth).fold(0.0, math.max) * 1.15;
  }

  /// Centreline without the parts inside junction patches, so markings stop at the junction.
  List<Vec2> _markingLine(Road r) {
    var pts = net.polyline(r);
    final len = polylineLength(pts);
    final a = _junctionRadius(r.from), b = _junctionRadius(r.to);
    if (a + b >= len - 1) return const [];
    if (b > 0) pts = splitPolylineAt(pts, len - b).$1;
    if (a > 0) pts = splitPolylineAt(pts, a).$2;
    return pts;
  }

  void _drawMarkings(Canvas canvas, Road r) {
    final pts = _markingLine(r);
    if (pts.length < 2) return;
    final cs = RoadCrossSection.of(r, net.drivingSide);
    final w = math.max(1.0, vp.px(0.15));
    final white = Paint()
      ..color = RoadColors.marking
      ..strokeWidth = w
      ..style = PaintingStyle.stroke;
    canvas.drawPath(polylinePath(vp, offsetPolyline(pts, cs.leftEdge)), white);
    canvas.drawPath(polylinePath(vp, offsetPolyline(pts, cs.rightEdge)), white);
    for (final s in cs.separators) {
      drawDashed(canvas, vp, offsetPolyline(pts, s), white);
    }
    if (cs.centre != null) {
      final yellow = Paint()
        ..color = RoadColors.centreLine
        ..strokeWidth = w
        ..style = PaintingStyle.stroke;
      canvas.drawPath(polylinePath(vp, offsetPolyline(pts, cs.centre! + 0.12)), yellow);
      canvas.drawPath(polylinePath(vp, offsetPolyline(pts, cs.centre! - 0.12)), yellow);
    }
    // Travel-direction chevrons at mid-road, one per lane.
    if (vp.scale > 1.2) {
      final len = polylineLength(pts);
      final mid = pointAlong(pts, len / 2);
      final arrow = Paint()
        ..color = RoadColors.marking.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, vp.px(0.2));
      void lanes((double, double)? span, int n, Vec2 dir) {
        if (span == null || n == 0) return;
        final step = (span.$2 - span.$1) / n;
        for (var k = 0; k < n; k++) {
          final off = span.$1 + step * (k + 0.5);
          drawChevron(canvas, vp, mid.point + mid.dir.perp * off, dir, math.min(2.5, r.laneWidthM * 0.7), arrow);
        }
      }

      lanes(cs.forward, r.forward.lanes, mid.dir);
      lanes(cs.backward, r.backward.lanes, -mid.dir);
    }
    if (vp.scale > 1.5) {
      final full = net.polyline(r);
      final mid = pointAlong(full, polylineLength(full) / 2).point;
      final label = r.name?.isNotEmpty == true ? '${r.name} · ${r.id}' : r.id;
      drawLabel(canvas, vp.toScreen(mid) + Offset(0, -vp.px(cs.halfWidth) - 10), label,
          size: 11, background: const Color(0xCCFFFFFF));
    }
  }

  void _drawSelection(Canvas canvas) {
    final s = selection;
    final hl = Paint()
      ..color = RoadColors.selection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    if (s is RoadSelection) {
      final r = net.roads[s.id];
      if (r == null) return;
      final pts = net.polyline(r);
      final cs = RoadCrossSection.of(r, net.drivingSide);
      canvas.drawPath(bandPath(vp, offsetPolyline(pts, cs.leftEdge + 0.4), offsetPolyline(pts, cs.rightEdge - 0.4)), hl);
      final handle = Paint()..color = Colors.white;
      for (final p in r.shape) {
        final sp = vp.toScreen(p);
        canvas.drawCircle(sp, 7, handle);
        canvas.drawCircle(sp, 7, hl..strokeWidth = 2);
      }
      final len = polylineLength(pts);
      drawLabel(canvas, vp.toScreen(pointAlong(pts, len / 2).point), '${len.toStringAsFixed(1)} m',
          background: const Color(0xEE1E88E5), color: Colors.white, size: 12);
    } else if (s is NodeSelection) {
      final n = net.nodes[s.id];
      if (n != null) canvas.drawCircle(vp.toScreen(n.pos), 14, hl);
    }
  }

  void _drawNodes(Canvas canvas) {
    final showHandles = tool == EditorTool.select || tool == EditorTool.road || tool == EditorTool.curve;
    for (final n in net.nodes.values) {
      final c = vp.toScreen(n.pos);
      final deg = net.degree(n.id);
      if (deg == 1) {
        canvas.drawCircle(c, 9, Paint()..color = RoadColors.gate);
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        final label = gateLabels[n.id];
        if (label != null) {
          drawLabel(canvas, c + const Offset(0, -22), label, color: Colors.white, background: RoadColors.gate, size: 12);
        }
        continue;
      }
      switch (n.control) {
        case NodeControl.trafficLight:
          _signalIcon(canvas, c + const Offset(16, -16));
        case NodeControl.priorityStop:
        case NodeControl.allwayStop:
          _stopIcon(canvas, c + const Offset(16, -16), n.control == NodeControl.allwayStop);
        default:
          break;
      }
      if (showHandles) {
        canvas.drawCircle(c, 6, Paint()..color = Colors.white);
        canvas.drawCircle(
            c,
            6,
            Paint()
              ..color = const Color(0xFF37474F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }
  }

  void _signalIcon(Canvas canvas, Offset at) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 12, height: 28), const Radius.circular(3));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF212121));
    const colors = [Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF43A047)];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(at + Offset(0, -8.0 + i * 8), 3, Paint()..color = colors[i]);
    }
  }

  void _stopIcon(Canvas canvas, Offset at, bool allWay) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 8 + i * math.pi / 4;
      final p = at + Offset(math.cos(a), math.sin(a)) * 11;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = const Color(0xFFC62828));
    drawLabel(canvas, at, allWay ? '4' : 'S', color: Colors.white, size: 10);
  }

  void _drawDraft(Canvas canvas) {
    final d = draft;
    if (d == null || d.points.length < 2) return;
    final pts = d.points;
    canvas.drawPath(
      bandPath(vp, offsetPolyline(pts, draftWidthM / 2), offsetPolyline(pts, -draftWidthM / 2)),
      Paint()..color = RoadColors.draft,
    );
    for (final t in [d.start, d.end]) {
      if (t == null) continue;
      final color = switch (t) {
        SnapNode() => RoadColors.snapNode,
        SnapRoad() => RoadColors.snapRoad,
        SnapFree() => Colors.white,
      };
      canvas.drawCircle(vp.toScreen(t.point), 9, Paint()..color = color);
      canvas.drawCircle(
          vp.toScreen(t.point),
          9,
          Paint()
            ..color = const Color(0xFF263238)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    final len = polylineLength(pts);
    final bearing = bearingDeg(pts.first, pts.last);
    drawLabel(canvas, vp.toScreen(pts.last) + const Offset(0, -28), '${len.toStringAsFixed(1)} m · ${bearing.toStringAsFixed(0)}°',
        background: const Color(0xEE263238), color: Colors.white);
  }

  void _drawMeasure(Canvas canvas) {
    if (measure.isEmpty) return;
    final line = Paint()
      ..color = const Color(0xFFD81B60)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (measure.length >= 3) {
      final poly = Path();
      for (var i = 0; i < measure.length; i++) {
        final s = vp.toScreen(measure[i]);
        i == 0 ? poly.moveTo(s.dx, s.dy) : poly.lineTo(s.dx, s.dy);
      }
      poly.close();
      canvas.drawPath(poly, Paint()..color = const Color(0x22D81B60));
    }
    canvas.drawPath(polylinePath(vp, measure), line);
    for (var i = 0; i < measure.length; i++) {
      canvas.drawCircle(vp.toScreen(measure[i]), 5, Paint()..color = const Color(0xFFD81B60));
      if (i > 0) {
        final a = measure[i - 1], b = measure[i];
        drawLabel(canvas, vp.toScreen(a.lerp(b, 0.5)), '${a.distanceTo(b).toStringAsFixed(1)} m',
            background: const Color(0xEEFFFFFF), size: 11);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EditorPainter old) =>
      old.net != net ||
      old.selection != selection ||
      old.tool != tool ||
      old.draft != draft ||
      old.measure.length != measure.length ||
      old.gateLabels != gateLabels ||
      old.dark != dark;
}
