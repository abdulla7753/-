import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/geometry.dart';

/// World (metres, y up/north) <-> screen (logical pixels, y down) transform.
class MapViewport extends ChangeNotifier {
  double scale; // pixels per metre
  Offset origin; // screen position of world (0, 0)

  MapViewport({this.scale = 2.0, this.origin = Offset.zero});

  static const minScale = 0.05;
  static const maxScale = 60.0;

  Offset toScreen(Vec2 p) => Offset(origin.dx + p.x * scale, origin.dy - p.y * scale);
  Vec2 toWorld(Offset s) => Vec2((s.dx - origin.dx) / scale, (origin.dy - s.dy) / scale);

  /// Length on screen of [m] metres.
  double px(double m) => m * scale;

  /// Metres covered by [p] pixels.
  double metres(double p) => p / scale;

  void set(double newScale, Offset newOrigin) {
    scale = newScale.clamp(minScale, maxScale);
    origin = newOrigin;
    notifyListeners();
  }

  void panBy(Offset delta) {
    origin += delta;
    notifyListeners();
  }

  void zoomAt(Offset focal, double factor) {
    final newScale = (scale * factor).clamp(minScale, maxScale);
    final world = toWorld(focal);
    scale = newScale;
    origin = Offset(focal.dx - world.x * scale, focal.dy + world.y * scale);
    notifyListeners();
  }

  void fit(Vec2 min, Vec2 max, Size size, {double padding = 60}) {
    final w = math.max(max.x - min.x, 20.0), h = math.max(max.y - min.y, 20.0);
    scale = math.min((size.width - 2 * padding) / w, (size.height - 2 * padding) / h).clamp(minScale, maxScale);
    final c = (min + max) * 0.5;
    origin = Offset(size.width / 2 - c.x * scale, size.height / 2 + c.y * scale);
    notifyListeners();
  }

  /// A "nice" grid spacing in metres for the current zoom (about 40-100 px apart).
  double gridSpacing() {
    const steps = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0];
    for (final s in steps) {
      if (s * scale >= 40) return s;
    }
    return steps.last;
  }
}
