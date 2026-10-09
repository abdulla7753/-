import 'dart:math' as math;
import 'dart:ui';

import '../../core/geometry.dart';
import 'viewport.dart';

/// Shared colours and low-level drawing helpers for road canvases.
class RoadColors {
  static const ground = Color(0xFFE4E8E1);
  static const groundDark = Color(0xFF1E2327);
  static const asphalt = Color(0xFF4A5057);
  static const asphaltLight = Color(0xFF5B626A);
  static const marking = Color(0xFFF4F4F4);
  static const centreLine = Color(0xFFF2C230);
  static const island = Color(0xFF8DB580);
  static const selection = Color(0xFF1E88E5);
  static const gate = Color(0xFF2E7D32);
  static const draft = Color(0x991E88E5);
  static const snapNode = Color(0xFF43A047);
  static const snapRoad = Color(0xFFFB8C00);
  static const gridMinor = Color(0x14000000);
  static const gridMajor = Color(0x26000000);
  static const car = Color(0xFF3F7DD8);
  static const truck = Color(0xFFE08A1E);
  static const bus = Color(0xFF2E9E5B);
}

Path polylinePath(MapViewport vp, List<Vec2> pts) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final s = vp.toScreen(pts[i]);
    i == 0 ? path.moveTo(s.dx, s.dy) : path.lineTo(s.dx, s.dy);
  }
  return path;
}

/// Closed polygon between two offset polylines (left edge forward, right edge backward).
Path bandPath(MapViewport vp, List<Vec2> left, List<Vec2> right) {
  final path = polylinePath(vp, left);
  for (final p in right.reversed) {
    final s = vp.toScreen(p);
    path.lineTo(s.dx, s.dy);
  }
  return path..close();
}

/// Dashed polyline in screen space; dash/gap given in metres.
void drawDashed(Canvas canvas, MapViewport vp, List<Vec2> pts, Paint paint, {double dashM = 3, double gapM = 6}) {
  final dash = vp.px(dashM), gap = vp.px(gapM);
  if (dash < 1.5) {
    canvas.drawPath(polylinePath(vp, pts), paint);
    return;
  }
  var on = true;
  var remaining = dash;
  for (var i = 0; i + 1 < pts.length; i++) {
    var a = vp.toScreen(pts[i]);
    final b = vp.toScreen(pts[i + 1]);
    var segLen = (b - a).distance;
    final dir = segLen == 0 ? Offset.zero : (b - a) / segLen;
    while (segLen > 0) {
      final step = math.min(remaining, segLen);
      final next = a + dir * step;
      if (on) canvas.drawLine(a, next, paint);
      a = next;
      segLen -= step;
      remaining -= step;
      if (remaining <= 1e-6) {
        on = !on;
        remaining = on ? dash : gap;
      }
    }
  }
}

/// Small chevron pointing along [dir] (world direction) at world point [p].
void drawChevron(Canvas canvas, MapViewport vp, Vec2 p, Vec2 dir, double sizeM, Paint paint) {
  final tip = p + dir * (sizeM * 0.6);
  final back = p - dir * (sizeM * 0.6);
  final side = dir.perp * (sizeM * 0.45);
  final path = Path()
    ..moveTo(vp.toScreen(back + side).dx, vp.toScreen(back + side).dy)
    ..lineTo(vp.toScreen(tip).dx, vp.toScreen(tip).dy)
    ..lineTo(vp.toScreen(back - side).dx, vp.toScreen(back - side).dy);
  canvas.drawPath(path, paint);
}

void drawGrid(Canvas canvas, Size size, MapViewport vp) {
  final s = vp.gridSpacing();
  final minor = Paint()
    ..color = RoadColors.gridMinor
    ..strokeWidth = 1;
  final major = Paint()
    ..color = RoadColors.gridMajor
    ..strokeWidth = 1;
  final tl = vp.toWorld(Offset.zero), br = vp.toWorld(Offset(size.width, size.height));
  final x0 = (tl.x / s).floor(), x1 = (br.x / s).ceil();
  final y0 = (br.y / s).floor(), y1 = (tl.y / s).ceil();
  if ((x1 - x0) + (y1 - y0) > 600) return;
  for (var i = x0; i <= x1; i++) {
    final x = vp.toScreen(Vec2(i * s, 0)).dx;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
  }
  for (var j = y0; j <= y1; j++) {
    final y = vp.toScreen(Vec2(0, j * s)).dy;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), j % 5 == 0 ? major : minor);
  }
}

void drawLabel(Canvas canvas, Offset at, String text,
    {Color color = const Color(0xFF263238), double size = 12, Color? background, bool center = true}) {
  final builder = ParagraphBuilder(ParagraphStyle(fontSize: size, fontFamily: 'NotoSans', textDirection: TextDirection.ltr))
    ..pushStyle(TextStyle(color: color, fontSize: size, fontFamily: 'NotoSans', fontFamilyFallback: const ['NotoSansArabic']))
    ..addText(text);
  final p = builder.build()..layout(const ParagraphConstraints(width: 400));
  final w = p.longestLine, h = p.height;
  final origin = center ? at - Offset(w / 2, h / 2) : at;
  if (background != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(origin.dx - 4, origin.dy - 1, w + 8, h + 2), const Radius.circular(4)),
      Paint()..color = background,
    );
  }
  canvas.drawParagraph(p, origin);
}
