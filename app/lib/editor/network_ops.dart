import 'dart:math' as math;

import '../core/geometry.dart';
import '../model/network.dart';

/// Attributes given to newly drawn roads.
class RoadDefaults {
  final int lanesForward;
  final int lanesBackward;
  final double laneWidthM;
  final double speedLimitKmh;
  const RoadDefaults({this.lanesForward = 2, this.lanesBackward = 2, this.laneWidthM = 3.65, this.speedLimitKmh = 60});

  RoadDefaults copyWith({int? lanesForward, int? lanesBackward, double? laneWidthM, double? speedLimitKmh}) => RoadDefaults(
        lanesForward: lanesForward ?? this.lanesForward,
        lanesBackward: lanesBackward ?? this.lanesBackward,
        laneWidthM: laneWidthM ?? this.laneWidthM,
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      );
}

/// What a point snaps to while drawing.
sealed class SnapTarget {
  Vec2 get point;
}

class SnapNode extends SnapTarget {
  final String nodeId;
  @override
  final Vec2 point;
  SnapNode(this.nodeId, this.point);
}

class SnapRoad extends SnapTarget {
  final String roadId;
  final double along;
  @override
  final Vec2 point;
  SnapRoad(this.roadId, this.along, this.point);
}

class SnapFree extends SnapTarget {
  @override
  final Vec2 point;
  SnapFree(this.point);
}

const _minRoadLength = 2.0;

String? findNodeAt(Network net, Vec2 p, double tol) {
  String? best;
  var bestD = tol;
  for (final n in net.nodes.values) {
    final d = n.pos.distanceTo(p);
    if (d <= bestD) {
      bestD = d;
      best = n.id;
    }
  }
  return best;
}

/// Road whose centreline (widened by its half width) is within [tol] of p.
({String roadId, double along, Vec2 point})? findRoadAt(Network net, Vec2 p, double tol) {
  ({String roadId, double along, Vec2 point})? best;
  var bestD = double.infinity;
  for (final r in net.roads.values) {
    final pr = projectOnPolyline(p, net.polyline(r));
    final half = (r.forward.lanes + r.backward.lanes) * r.laneWidthM / 2;
    final d = math.max(0.0, pr.distance - half);
    if (d <= tol && d < bestD) {
      bestD = d;
      best = (roadId: r.id, along: pr.along, point: pr.point);
    }
  }
  return best;
}

SnapTarget snap(Network net, Vec2 p, double tol, {double? grid}) {
  final nodeId = findNodeAt(net, p, tol);
  if (nodeId != null) return SnapNode(nodeId, net.nodes[nodeId]!.pos);
  for (final r in net.roads.values) {
    final pr = projectOnPolyline(p, net.polyline(r));
    if (pr.distance <= tol) return SnapRoad(r.id, pr.along, pr.point);
  }
  if (grid != null && grid > 0) {
    return SnapFree(Vec2((p.x / grid).roundToDouble() * grid, (p.y / grid).roundToDouble() * grid));
  }
  return SnapFree(p);
}

/// Constrain the direction a→p to multiples of [stepDeg] degrees.
Vec2 snapAngle(Vec2 a, Vec2 p, double stepDeg) {
  final d = p - a;
  final len = d.length;
  if (len == 0) return p;
  final step = degToRad(stepDeg);
  final ang = (d.angle / step).roundToDouble() * step;
  return a + Vec2(math.cos(ang), math.sin(ang)) * len;
}

({Network net, String nodeId}) _newNode(Network net, Vec2 p, {NodeControl control = NodeControl.priority}) {
  final id = 'n${net.nextNodeSeq}';
  final nodes = Map.of(net.nodes)..[id] = RoadNode(id: id, pos: p, control: control);
  return (net: net.copyWith(nodes: nodes, nextNodeSeq: net.nextNodeSeq + 1), nodeId: id);
}

String _nextRoadId(Network net) => 'r${net.nextRoadSeq}';

/// Split [roadId] at arc length [along], inserting a node. Turn bays stay at the road ends they belong to.
({Network net, String nodeId}) splitRoad(Network net, String roadId, double along) {
  final road = net.roads[roadId]!;
  final pts = net.polyline(road);
  final total = polylineLength(pts);
  final s = along.clamp(0.0, total);
  if (s < 0.5) return (net: net, nodeId: road.from);
  if (total - s < 0.5) return (net: net, nodeId: road.to);
  final (head, tail) = splitPolylineAt(pts, s);
  final created = _newNode(net, head.last);
  var n = created.net;
  final mid = created.nodeId;
  final first = road.copyWith(
    to: mid,
    shape: head.sublist(1, head.length - 1),
    forward: road.forward.copyWith(clearLeft: true, clearRight: true),
  );
  final secondId = _nextRoadId(n);
  final second = Road(
    id: secondId,
    from: mid,
    to: road.to,
    shape: tail.sublist(1, tail.length - 1),
    laneWidthM: road.laneWidthM,
    speedLimitKmh: road.speedLimitKmh,
    forward: road.forward,
    backward: road.backward.copyWith(clearLeft: true, clearRight: true),
    priority: road.priority,
    name: road.name,
  );
  final roads = Map.of(n.roads)
    ..[road.id] = first
    ..[secondId] = second;
  n = n.copyWith(roads: roads, nextRoadSeq: n.nextRoadSeq + 1);
  return (net: n, nodeId: mid);
}

/// Road whose centreline passes within [tol] of p (used to re-locate points after splits).
({String roadId, double along})? _roadOnCentreline(Network net, Vec2 p, {double tol = 0.5}) {
  for (final r in net.roads.values) {
    final pr = projectOnPolyline(p, net.polyline(r));
    if (pr.distance <= tol) return (roadId: r.id, along: pr.along);
  }
  return null;
}

/// Resolve a snap target to a node id, creating/splitting as needed. Road snaps are
/// re-located on the current network because earlier splits may have renamed the road.
({Network net, String nodeId}) _materialize(Network net, SnapTarget t) {
  switch (t) {
    case SnapNode(:final nodeId):
      return (net: net, nodeId: nodeId);
    case SnapRoad(:final point):
      final existing = findNodeAt(net, point, 0.5);
      if (existing != null) return (net: net, nodeId: existing);
      final hit = _roadOnCentreline(net, point);
      return hit == null ? _newNode(net, point) : splitRoad(net, hit.roadId, hit.along);
    case SnapFree(:final point):
      return _newNode(net, point);
  }
}

class AddRoadResult {
  final Network net;
  final List<String> createdRoads;

  /// Old gate node -> new gate node, when a road was extended from a road end.
  final Map<String, String> gateMoves;
  const AddRoadResult(this.net, this.createdRoads, this.gateMoves);
}

/// Add a road along [points] (first/last snapped by the caller), creating junctions where it
/// meets existing roads. With [autoJunctions] false, crossings stay grade-separated (bridge/tunnel).
AddRoadResult? addRoad(
  Network net,
  SnapTarget start,
  SnapTarget end,
  List<Vec2> interior,
  RoadDefaults d, {
  bool autoJunctions = true,
}) {
  final pts = [start.point, ...interior, end.point];
  if (polylineLength(pts) < _minRoadLength) return null;
  if (start is SnapNode && end is SnapNode && start.nodeId == end.nodeId) return null;
  final oldGates = net.boundaryNodes.map((n) => n.id).toSet();

  // Crossings with existing roads (excluding the roads we snap onto at the ends).
  final crossings = <({double along, String roadId, double roadAlong})>[];
  if (autoJunctions) {
    var walked = 0.0;
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i], b = pts[i + 1];
      for (final r in net.roads.values) {
        final rp = net.polyline(r);
        var rWalked = 0.0;
        for (var k = 0; k + 1 < rp.length; k++) {
          final hit = segmentIntersection(a, b, rp[k], rp[k + 1]);
          final segLen = rp[k].distanceTo(rp[k + 1]);
          if (hit != null) {
            final along = walked + a.distanceTo(b) * hit.t;
            final roadAlong = rWalked + segLen * hit.u;
            final nearEnds = along < 1.0 || polylineLength(pts) - along < 1.0;
            if (!nearEnds) crossings.add((along: along, roadId: r.id, roadAlong: roadAlong));
          }
          rWalked += segLen;
        }
      }
      walked += a.distanceTo(b);
    }
    crossings.sort((x, y) => x.along.compareTo(y.along));
  }

  var n = net;
  final s = _materialize(n, start);
  n = s.net;
  final startNode = s.nodeId;
  // Crossing nodes, in order along the new road. A road may be crossed several times, so
  // re-project each crossing point on the (possibly already split) network.
  final via = <({String nodeId, double along})>[];
  for (final c in crossings) {
    final p = pointAlong(pts, c.along).point;
    final m = _materialize(n, SnapRoad(c.roadId, c.roadAlong, p));
    n = m.net;
    via.add((nodeId: m.nodeId, along: c.along));
  }
  final e = _materialize(n, end);
  n = e.net;
  final endNode = e.nodeId;
  if (startNode == endNode) return null;

  final stops = [(nodeId: startNode, along: 0.0), ...via, (nodeId: endNode, along: polylineLength(pts))];
  final created = <String>[];
  final roads = Map.of(n.roads);
  var seq = n.nextRoadSeq;
  for (var i = 0; i + 1 < stops.length; i++) {
    final a = stops[i], b = stops[i + 1];
    if (a.nodeId == b.nodeId || b.along - a.along < 0.5) continue;
    final (_, rest) = splitPolylineAt(pts, a.along);
    final (piece, _) = splitPolylineAt(rest, b.along - a.along);
    final id = 'r$seq';
    seq++;
    roads[id] = Road(
      id: id,
      from: a.nodeId,
      to: b.nodeId,
      shape: piece.length > 2 ? piece.sublist(1, piece.length - 1) : const [],
      laneWidthM: d.laneWidthM,
      speedLimitKmh: d.speedLimitKmh,
      forward: Direction(lanes: d.lanesForward),
      backward: Direction(lanes: d.lanesBackward),
    );
    created.add(id);
  }
  if (created.isEmpty) return null;
  n = n.copyWith(roads: roads, nextRoadSeq: seq);

  // When a road end is extended, the traffic entering there now enters at the new end.
  final gateMoves = <String, String>{};
  final newGates = n.boundaryNodes.map((x) => x.id).toSet();
  for (final g in oldGates.difference(newGates)) {
    if (g == startNode && newGates.contains(endNode) && !oldGates.contains(endNode)) gateMoves[g] = endNode;
    if (g == endNode && newGates.contains(startNode) && !oldGates.contains(startNode)) gateMoves[g] = startNode;
  }
  return AddRoadResult(n, created, gateMoves);
}

Network moveNode(Network net, String nodeId, Vec2 pos) {
  final node = net.nodes[nodeId];
  if (node == null) return net;
  final nodes = Map.of(net.nodes)..[nodeId] = node.copyWith(pos: pos);
  return net.copyWith(nodes: nodes);
}

Network moveShapePoint(Network net, String roadId, int index, Vec2 pos) {
  final r = net.roads[roadId];
  if (r == null || index < 0 || index >= r.shape.length) return net;
  final shape = List.of(r.shape)..[index] = pos;
  return net.copyWith(roads: Map.of(net.roads)..[roadId] = r.copyWith(shape: shape));
}

Network _dropOrphans(Network net) {
  final used = <String>{for (final r in net.roads.values) ...[r.from, r.to]};
  final nodes = Map.of(net.nodes)..removeWhere((id, _) => !used.contains(id));
  return net.copyWith(nodes: nodes);
}

Network deleteRoad(Network net, String roadId) {
  if (!net.roads.containsKey(roadId)) return net;
  return _dropOrphans(net.copyWith(roads: Map.of(net.roads)..remove(roadId)));
}

Network deleteNode(Network net, String nodeId) {
  final roads = Map.of(net.roads)..removeWhere((_, r) => r.from == nodeId || r.to == nodeId);
  final nodes = Map.of(net.nodes)..remove(nodeId);
  return _dropOrphans(net.copyWith(roads: roads, nodes: nodes));
}

Network updateNode(Network net, RoadNode node) => net.copyWith(nodes: Map.of(net.nodes)..[node.id] = node);
Network updateRoad(Network net, Road road) => net.copyWith(roads: Map.of(net.roads)..[road.id] = road);

// ---------------------------------------------------------------- templates

enum JunctionTemplate { fourWay, tJunction, roundabout }

/// Insert a junction with straight arms of [armM] metres centred at [c].
Network insertTemplate(Network net, JunctionTemplate t, Vec2 c, RoadDefaults d, {double armM = 200}) {
  var n = net;
  final control = switch (t) {
    JunctionTemplate.fourWay => NodeControl.trafficLight,
    JunctionTemplate.tJunction => NodeControl.priorityStop,
    JunctionTemplate.roundabout => NodeControl.roundabout,
  };
  final centre = _newNode(n, c, control: control);
  n = centre.net;
  if (t == JunctionTemplate.roundabout) {
    final nodes = Map.of(n.nodes);
    nodes[centre.nodeId] = nodes[centre.nodeId]!.copyWith(roundabout: const RoundaboutSpec());
    n = n.copyWith(nodes: nodes);
  }
  final dirs = t == JunctionTemplate.tJunction
      ? const [Vec2(1, 0), Vec2(-1, 0), Vec2(0, -1)]
      : const [Vec2(0, 1), Vec2(1, 0), Vec2(0, -1), Vec2(-1, 0)];
  for (final dir in dirs) {
    final end = _newNode(n, c + dir * armM);
    n = end.net;
    final id = _nextRoadId(n);
    final roads = Map.of(n.roads)
      ..[id] = Road(
        id: id,
        from: end.nodeId,
        to: centre.nodeId,
        laneWidthM: d.laneWidthM,
        speedLimitKmh: d.speedLimitKmh,
        forward: Direction(lanes: d.lanesForward),
        backward: Direction(lanes: d.lanesBackward),
      );
    n = n.copyWith(roads: roads, nextRoadSeq: n.nextRoadSeq + 1);
  }
  return n;
}
