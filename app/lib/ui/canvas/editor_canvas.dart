import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../editor/editor_controller.dart';
import '../../editor/network_ops.dart';
import 'editor_painter.dart';
import 'viewport.dart';

enum _Mode { none, pan, zoom, drawRoad, drawCurve, moveNode, moveShape }

/// Interactive design canvas: two fingers always pan/zoom; one finger or the pen
/// uses the active tool (in pen-only mode a single finger pans instead of drawing).
class EditorCanvas extends StatefulWidget {
  final EditorController ctrl;
  final MapViewport vp;
  final Map<String, String> gateLabels;
  const EditorCanvas({super.key, required this.ctrl, required this.vp, required this.gateLabels});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  _Mode _mode = _Mode.none;
  DraftState? _draft;
  SnapTarget? _start;
  final List<Vec2> _stroke = [];
  String? _dragNode;
  (String, int)? _dragShape;
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;

  EditorController get c => widget.ctrl;
  MapViewport get vp => widget.vp;
  double get _tol => vp.metres(18);

  double? get _grid => c.gridSnap ? math.max(0.5, vp.gridSpacing() / 5) : null;

  SnapTarget _snapAt(Vec2 p) => snap(c.network, p, _tol, grid: _grid);

  Vec2 _snapFree(Vec2 p) {
    final g = _grid;
    return g == null ? p : Vec2((p.x / g).roundToDouble() * g, (p.y / g).roundToDouble() * g);
  }

  bool get _drawingTool => c.tool == EditorTool.road || c.tool == EditorTool.curve;

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocal = d.localFocalPoint;
    _lastScale = 1;
    if (d.pointerCount >= 2) {
      _mode = _Mode.zoom;
      return;
    }
    final p = vp.toWorld(d.localFocalPoint);
    if (_drawingTool && c.penOnlyDrawing && _kind != PointerDeviceKind.stylus) {
      _mode = _Mode.pan;
      return;
    }
    switch (c.tool) {
      case EditorTool.select:
        final node = findNodeAt(c.network, p, _tol);
        if (node != null) {
          _mode = _Mode.moveNode;
          _dragNode = node;
          c.select(NodeSelection(node));
          return;
        }
        final sel = c.selection;
        if (sel is RoadSelection) {
          final road = c.network.roads[sel.id];
          if (road != null) {
            for (var i = 0; i < road.shape.length; i++) {
              if (road.shape[i].distanceTo(p) <= _tol) {
                _mode = _Mode.moveShape;
                _dragShape = (road.id, i);
                return;
              }
            }
          }
        }
        _mode = _Mode.pan;
      case EditorTool.road:
        _mode = _Mode.drawRoad;
        _start = _snapAt(p);
        setState(() => _draft = DraftState([_start!.point, _start!.point], _start, null));
      case EditorTool.curve:
        _mode = _Mode.drawCurve;
        _start = _snapAt(p);
        _stroke
          ..clear()
          ..add(_start!.point);
        setState(() => _draft = DraftState(List.of(_stroke), _start, null));
      case EditorTool.junction:
      case EditorTool.measure:
        _mode = _Mode.pan;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2 && _mode != _Mode.zoom) {
      // A second finger joined: abandon the stroke and navigate instead.
      if (_mode == _Mode.moveNode || _mode == _Mode.moveShape) c.endDrag();
      _mode = _Mode.zoom;
      _lastFocal = d.localFocalPoint;
      _lastScale = d.scale;
      setState(() => _draft = null);
      return;
    }
    final p = vp.toWorld(d.localFocalPoint);
    switch (_mode) {
      case _Mode.zoom:
        vp.panBy(d.localFocalPoint - _lastFocal);
        if (_lastScale > 0 && d.scale > 0) vp.zoomAt(d.localFocalPoint, d.scale / _lastScale);
        _lastFocal = d.localFocalPoint;
        _lastScale = d.scale;
      case _Mode.pan:
        vp.panBy(d.focalPointDelta);
      case _Mode.drawRoad:
        var end = _snapAt(p);
        if (c.angleSnap && end is SnapFree) end = SnapFree(_snapFree(snapAngle(_start!.point, p, 15)));
        setState(() => _draft = DraftState([_start!.point, end.point], _start, end));
      case _Mode.drawCurve:
        if (_stroke.isEmpty || _stroke.last.distanceTo(p) > vp.metres(5)) _stroke.add(p);
        final end = _snapAt(p);
        setState(() => _draft = DraftState([..._stroke, end.point], _start, end));
      case _Mode.moveNode:
        c.previewNodeMove(_dragNode!, _snapFree(p));
      case _Mode.moveShape:
        c.previewShapePointMove(_dragShape!.$1, _dragShape!.$2, _snapFree(p));
      case _Mode.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    switch (_mode) {
      case _Mode.drawRoad:
        final draft = _draft;
        if (draft != null && draft.end != null) c.addRoad(_start!, draft.end!, const []);
      case _Mode.drawCurve:
        if (_stroke.length >= 2 && _draft != null) {
          final end = _draft!.end ?? _snapAt(_stroke.last);
          c.addRoad(_start!, end, _smoothInterior(_start!.point, end.point));
        }
      case _Mode.moveNode:
      case _Mode.moveShape:
        c.endDrag();
      default:
        break;
    }
    _mode = _Mode.none;
    _dragNode = null;
    _dragShape = null;
    _stroke.clear();
    setState(() => _draft = null);
  }

  /// Freehand stroke -> simplified, smoothed interior shape points.
  List<Vec2> _smoothInterior(Vec2 a, Vec2 b) {
    final raw = [a, ..._stroke.skip(1), b];
    final ctrl = simplify(raw, vp.metres(4));
    if (ctrl.length < 3) return const [];
    final smooth = simplify(catmullRom(ctrl, spacing: math.max(2.0, polylineLength(ctrl) / 60)), 0.2);
    return smooth.length > 2 ? smooth.sublist(1, smooth.length - 1) : const [];
  }

  void _onTapUp(TapUpDetails d) {
    final p = vp.toWorld(d.localPosition);
    switch (c.tool) {
      case EditorTool.select:
      case EditorTool.road:
      case EditorTool.curve:
        final node = findNodeAt(c.network, p, _tol);
        if (node != null) {
          c.select(NodeSelection(node));
          return;
        }
        final road = findRoadAt(c.network, p, vp.metres(8));
        c.select(road == null ? null : RoadSelection(road.roadId));
      case EditorTool.junction:
        c.insertJunction(_snapFree(p));
      case EditorTool.measure:
        c.addMeasurePoint(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _kind = e.kind,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) vp.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 400));
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: EditorPainter(
              net: c.network,
              vp: vp,
              selection: c.selection,
              tool: c.tool,
              draft: _draft,
              measure: List.of(c.measurePoints),
              gateLabels: widget.gateLabels,
              draftWidthM: (c.roadDefaults.lanesForward + c.roadDefaults.lanesBackward) * c.roadDefaults.laneWidthM,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}
