import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../model/results.dart';
import '../canvas/road_drawing.dart';
import '../canvas/viewport.dart';

enum VehicleColoring { byClass, bySpeed }

/// A vehicle's interpolated state at the playback time.
class VehicleState {
  final int index;
  final Vec2 front;
  final double angleDeg; // SUMO convention: clockwise from north
  final double speed;
  const VehicleState(this.index, this.front, this.angleDeg, this.speed);

  Vec2 get heading => Vec2(math.sin(degToRad(angleDeg)), math.cos(degToRad(angleDeg)));
}

/// Interpolates SUMO's sampled positions between neighbouring frames (display only).
List<VehicleState> vehiclesAt(Trajectory tr, double t) {
  if (tr.frameCount == 0) return const [];
  final i = tr.frameAt(t);
  final a = tr.frames[i];
  final hasNext = i + 1 < tr.frameCount;
  final tA = tr.times[i];
  final tB = hasNext ? tr.times[i + 1] : tA;
  final f = (hasNext && tB > tA) ? ((t - tA) / (tB - tA)).clamp(0.0, 1.0) : 0.0;
  final next = <int, int>{};
  if (hasNext && f > 0) {
    final b = tr.frames[i + 1];
    for (var k = 0; k + 4 < b.length; k += 5) {
      next[b[k].toInt()] = k;
    }
  }
  final out = <VehicleState>[];
  for (var k = 0; k + 4 < a.length; k += 5) {
    final idx = a[k].toInt();
    var p = Vec2(a[k + 1], a[k + 2]);
    var ang = a[k + 3].toDouble();
    var spd = a[k + 4].toDouble();
    final kb = next[idx];
    if (kb != null) {
      final b = tr.frames[i + 1];
      p = p.lerp(Vec2(b[kb + 1], b[kb + 2]), f);
      final d = ((b[kb + 3] - ang + 540) % 360) - 180;
      ang = ang + d * f;
      spd = spd + (b[kb + 4] - spd) * f;
    }
    out.add(VehicleState(idx, p, ang, spd));
  }
  return out;
}

Color speedRatioColor(double? r) {
  if (r == null) return const Color(0xFF9E9E9E);
  if (r >= 0.85) return const Color(0xFF2E7D32);
  if (r >= 0.65) return const Color(0xFF9CCC65);
  if (r >= 0.45) return const Color(0xFFFFB300);
  if (r >= 0.25) return const Color(0xFFF4511E);
  return const Color(0xFFB71C1C);
}

class PlaybackPainter extends CustomPainter {
  final SimNetwork net;
  final Trajectory? traj;
  final double time;
  final MapViewport vp;
  final Map<String, double?> laneSpeedRatio;
  final bool heatmap;
  final VehicleColoring coloring;
  final int? selectedVehicle;
  final bool dark;

  PlaybackPainter({
    required this.net,
    required this.traj,
    required this.time,
    required this.vp,
    required this.laneSpeedRatio,
    required this.heatmap,
    required this.coloring,
    required this.selectedVehicle,
    this.dark = false,
  }) : super(repaint: vp);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? RoadColors.groundDark : RoadColors.ground);
    drawGrid(canvas, size, vp);
    final asphalt = Paint()..color = RoadColors.asphalt;
    for (final j in net.junctions) {
      canvas.drawPath(_polygon(j.shape), asphalt);
    }
    for (final l in net.lanes) {
      final paint = heatmap ? (Paint()..color = speedRatioColor(laneSpeedRatio[l.id])) : asphalt;
      canvas.drawPath(bandPath(vp, offsetPolyline(l.shape, l.width / 2), offsetPolyline(l.shape, -l.width / 2)), paint);
    }
    if (vp.scale > 0.7) {
      final line = Paint()
        ..color = RoadColors.marking.withValues(alpha: 0.8)
        ..strokeWidth = math.max(1, vp.px(0.12))
        ..style = PaintingStyle.stroke;
      for (final l in net.lanes) {
        drawDashed(canvas, vp, offsetPolyline(l.shape, -l.width / 2), line, dashM: 3, gapM: 5);
      }
    }
    _drawSignals(canvas);
    _drawVehicles(canvas);
  }

  Path _polygon(List<Vec2> pts) {
    final p = polylinePath(vp, pts);
    return p..close();
  }

  void _drawSignals(Canvas canvas) {
    if (net.signals.isEmpty) return;
    final laneWidth = {for (final l in net.lanes) l.id: l.width};
    for (final s in net.signals) {
      final state = traj?.signalState(s.tl, time) ?? _programState(s.tl, time);
      final ch = (state != null && s.linkIndex < state.length) ? state[s.linkIndex] : '?';
      final color = switch (ch) {
        'G' => const Color(0xFF00C853),
        'g' => const Color(0xFF9CCC65),
        'y' || 'Y' => const Color(0xFFFFD600),
        'r' || 'R' => const Color(0xFFD50000),
        _ => const Color(0xFF9E9E9E),
      };
      final h = degToRad(s.headingDeg);
      final dir = Vec2(math.cos(h), math.sin(h));
      final half = (laneWidth[s.fromLane] ?? 3.2) / 2 * 0.9;
      final a = s.stop + dir.perp * half - dir * 0.5;
      final b = s.stop - dir.perp * half - dir * 0.5;
      canvas.drawLine(
        vp.toScreen(a),
        vp.toScreen(b),
        Paint()
          ..color = color
          ..strokeWidth = math.max(3, vp.px(0.8))
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  /// State from the static program when the trajectory carries no signal log.
  String? _programState(String tl, double t) {
    final phases = net.tlPrograms[tl];
    if (phases == null || phases.isEmpty) return null;
    final cycle = phases.fold(0.0, (a, p) => a + p.duration);
    var x = t % cycle;
    for (final p in phases) {
      if (x < p.duration) return p.state;
      x -= p.duration;
    }
    return phases.last.state;
  }

  void _drawVehicles(Canvas canvas) {
    final tr = traj;
    if (tr == null) return;
    final outline = Paint()
      ..color = const Color(0xFF102027)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final v in vehiclesAt(tr, time)) {
      final info = tr.vehicles[v.index];
      final dir = v.heading;
      final side = dir.perp * (info.width / 2);
      final back = v.front - dir * info.length;
      final pts = [v.front + side, v.front - side, back - side, back + side];
      final path = polylinePath(vp, pts)..close();
      final color = coloring == VehicleColoring.byClass
          ? switch (info.cls) {
              'truck' => RoadColors.truck,
              'bus' => RoadColors.bus,
              _ => RoadColors.car,
            }
          : _speedColor(v.speed);
      canvas.drawPath(path, Paint()..color = color);
      if (vp.scale > 2) canvas.drawPath(path, outline);
      if (v.index == selectedVehicle) {
        canvas.drawCircle(
          vp.toScreen(v.front - dir * (info.length / 2)),
          math.max(14, vp.px(info.length * 0.8)),
          Paint()
            ..color = RoadColors.selection
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  Color _speedColor(double ms) {
    final kmh = ms * 3.6;
    if (kmh < 5) return const Color(0xFFD50000);
    if (kmh < 20) return const Color(0xFFFF6D00);
    if (kmh < 40) return const Color(0xFFFFD600);
    return const Color(0xFF00C853);
  }

  @override
  bool shouldRepaint(covariant PlaybackPainter old) =>
      old.time != time ||
      old.heatmap != heatmap ||
      old.coloring != coloring ||
      old.selectedVehicle != selectedVehicle ||
      old.net != net ||
      old.traj != traj ||
      old.dark != dark;
}
