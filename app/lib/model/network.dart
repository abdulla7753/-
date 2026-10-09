import '../core/geometry.dart';

/// Junction control types; names match the simulation server API.
enum NodeControl {
  priority('priority'),
  priorityStop('priority_stop'),
  trafficLight('traffic_light'),
  allwayStop('allway_stop'),
  rightBeforeLeft('right_before_left'),
  roundabout('roundabout');

  final String api;
  const NodeControl(this.api);

  static NodeControl fromApi(String? s) =>
      NodeControl.values.firstWhere((c) => c.api == s, orElse: () => NodeControl.priority);
}

class RoundaboutSpec {
  final double radiusM;
  final int lanes;
  final double laneWidthM;
  final double speedLimitKmh;

  const RoundaboutSpec({this.radiusM = 25, this.lanes = 2, this.laneWidthM = 4.0, this.speedLimitKmh = 30});

  RoundaboutSpec copyWith({double? radiusM, int? lanes, double? laneWidthM, double? speedLimitKmh}) => RoundaboutSpec(
        radiusM: radiusM ?? this.radiusM,
        lanes: lanes ?? this.lanes,
        laneWidthM: laneWidthM ?? this.laneWidthM,
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      );

  Map<String, dynamic> toJson() =>
      {'radiusM': radiusM, 'lanes': lanes, 'laneWidthM': laneWidthM, 'speedLimitKmh': speedLimitKmh};

  factory RoundaboutSpec.fromJson(Map<String, dynamic> j) => RoundaboutSpec(
        radiusM: (j['radiusM'] as num?)?.toDouble() ?? 25,
        lanes: (j['lanes'] as num?)?.toInt() ?? 2,
        laneWidthM: (j['laneWidthM'] as num?)?.toDouble() ?? 4.0,
        speedLimitKmh: (j['speedLimitKmh'] as num?)?.toDouble() ?? 30,
      );
}

class RoadNode {
  final String id;
  final Vec2 pos;
  final double z;
  final NodeControl control;
  final RoundaboutSpec? roundabout;
  final String? name;

  const RoadNode({
    required this.id,
    required this.pos,
    this.z = 0,
    this.control = NodeControl.priority,
    this.roundabout,
    this.name,
  });

  RoadNode copyWith({
    Vec2? pos,
    double? z,
    NodeControl? control,
    RoundaboutSpec? roundabout,
    String? name,
    bool clearName = false,
  }) =>
      RoadNode(
        id: id,
        pos: pos ?? this.pos,
        z: z ?? this.z,
        control: control ?? this.control,
        roundabout: roundabout ?? this.roundabout,
        name: clearName ? null : (name ?? this.name),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': pos.toJson()[0],
        'y': pos.toJson()[1],
        'z': z,
        'control': control.api,
        if (roundabout != null) 'roundabout': roundabout!.toJson(),
        if (name != null) 'name': name,
      };

  /// Server schema: no editor-only fields.
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'x': pos.toJson()[0],
        'y': pos.toJson()[1],
        'z': z,
        'control': control.api,
        if (control == NodeControl.roundabout) 'roundabout': (roundabout ?? const RoundaboutSpec()).toJson(),
      };

  factory RoadNode.fromJson(Map<String, dynamic> j) => RoadNode(
        id: j['id'] as String,
        pos: Vec2((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        z: (j['z'] as num?)?.toDouble() ?? 0,
        control: NodeControl.fromApi(j['control'] as String?),
        roundabout: j['roundabout'] == null ? null : RoundaboutSpec.fromJson(j['roundabout'] as Map<String, dynamic>),
        name: j['name'] as String?,
      );
}

class TurnBay {
  final int lanes;
  final double lengthM;
  const TurnBay({this.lanes = 1, this.lengthM = 50});

  TurnBay copyWith({int? lanes, double? lengthM}) => TurnBay(lanes: lanes ?? this.lanes, lengthM: lengthM ?? this.lengthM);

  Map<String, dynamic> toJson() => {'lanes': lanes, 'lengthM': lengthM};
  factory TurnBay.fromJson(Map<String, dynamic> j) =>
      TurnBay(lanes: (j['lanes'] as num).toInt(), lengthM: (j['lengthM'] as num).toDouble());
}

class Direction {
  final int lanes;
  final TurnBay? leftBay;
  final TurnBay? rightBay;
  const Direction({required this.lanes, this.leftBay, this.rightBay});

  Direction copyWith({int? lanes, TurnBay? leftBay, TurnBay? rightBay, bool clearLeft = false, bool clearRight = false}) =>
      Direction(
        lanes: lanes ?? this.lanes,
        leftBay: clearLeft ? null : (leftBay ?? this.leftBay),
        rightBay: clearRight ? null : (rightBay ?? this.rightBay),
      );

  int get lanesAtStopLine => lanes + (leftBay?.lanes ?? 0) + (rightBay?.lanes ?? 0);

  Map<String, dynamic> toJson() => {
        'lanes': lanes,
        if (lanes > 0 && leftBay != null) 'leftBay': leftBay!.toJson(),
        if (lanes > 0 && rightBay != null) 'rightBay': rightBay!.toJson(),
      };

  factory Direction.fromJson(Map<String, dynamic> j) => Direction(
        lanes: (j['lanes'] as num).toInt(),
        leftBay: j['leftBay'] == null ? null : TurnBay.fromJson(j['leftBay'] as Map<String, dynamic>),
        rightBay: j['rightBay'] == null ? null : TurnBay.fromJson(j['rightBay'] as Map<String, dynamic>),
      );
}

class Road {
  final String id;
  final String from;
  final String to;

  /// Intermediate shape points (excluding the end nodes).
  final List<Vec2> shape;
  final double laneWidthM;
  final double speedLimitKmh;
  final Direction forward;
  final Direction backward;
  final int? priority;
  final String? name;

  const Road({
    required this.id,
    required this.from,
    required this.to,
    this.shape = const [],
    this.laneWidthM = 3.65,
    this.speedLimitKmh = 60,
    this.forward = const Direction(lanes: 2),
    this.backward = const Direction(lanes: 2),
    this.priority,
    this.name,
  });

  bool get isOneWay => forward.lanes == 0 || backward.lanes == 0;

  Road copyWith({
    String? from,
    String? to,
    List<Vec2>? shape,
    double? laneWidthM,
    double? speedLimitKmh,
    Direction? forward,
    Direction? backward,
    int? priority,
    bool clearPriority = false,
    String? name,
    bool clearName = false,
  }) =>
      Road(
        id: id,
        from: from ?? this.from,
        to: to ?? this.to,
        shape: shape ?? this.shape,
        laneWidthM: laneWidthM ?? this.laneWidthM,
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
        forward: forward ?? this.forward,
        backward: backward ?? this.backward,
        priority: clearPriority ? null : (priority ?? this.priority),
        name: clearName ? null : (name ?? this.name),
      );

  /// Same road with id kept, direction reversed (forward <-> backward).
  Road reversed() => Road(
        id: id,
        from: to,
        to: from,
        shape: shape.reversed.toList(),
        laneWidthM: laneWidthM,
        speedLimitKmh: speedLimitKmh,
        forward: backward,
        backward: forward,
        priority: priority,
        name: name,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'shape': shape.map((p) => p.toJson()).toList(),
        'laneWidthM': laneWidthM,
        'speedLimitKmh': speedLimitKmh,
        'forward': forward.toJson(),
        'backward': backward.toJson(),
        if (priority != null) 'priority': priority,
        if (name != null && name!.isNotEmpty) 'name': name,
      };

  factory Road.fromJson(Map<String, dynamic> j) => Road(
        id: j['id'] as String,
        from: j['from'] as String,
        to: j['to'] as String,
        shape: ((j['shape'] as List?) ?? const []).map((p) => Vec2.fromJson(p as List)).toList(),
        laneWidthM: (j['laneWidthM'] as num?)?.toDouble() ?? 3.65,
        speedLimitKmh: (j['speedLimitKmh'] as num).toDouble(),
        forward: Direction.fromJson(j['forward'] as Map<String, dynamic>),
        backward: Direction.fromJson(j['backward'] as Map<String, dynamic>),
        priority: (j['priority'] as num?)?.toInt(),
        name: j['name'] as String?,
      );
}

enum DrivingSide { right, left }

/// Immutable road network as drawn in the editor.
class Network {
  final DrivingSide drivingSide;
  final bool allowUTurns;
  final Map<String, RoadNode> nodes;
  final Map<String, Road> roads;
  final int nextNodeSeq;
  final int nextRoadSeq;

  Network({
    this.drivingSide = DrivingSide.right,
    this.allowUTurns = false,
    Map<String, RoadNode>? nodes,
    Map<String, Road>? roads,
    this.nextNodeSeq = 1,
    this.nextRoadSeq = 1,
  })  : nodes = Map.unmodifiable(nodes ?? const {}),
        roads = Map.unmodifiable(roads ?? const {});

  static final empty = Network();

  Network copyWith({
    DrivingSide? drivingSide,
    bool? allowUTurns,
    Map<String, RoadNode>? nodes,
    Map<String, Road>? roads,
    int? nextNodeSeq,
    int? nextRoadSeq,
  }) =>
      Network(
        drivingSide: drivingSide ?? this.drivingSide,
        allowUTurns: allowUTurns ?? this.allowUTurns,
        nodes: nodes ?? this.nodes,
        roads: roads ?? this.roads,
        nextNodeSeq: nextNodeSeq ?? this.nextNodeSeq,
        nextRoadSeq: nextRoadSeq ?? this.nextRoadSeq,
      );

  Iterable<Road> roadsAt(String nodeId) => roads.values.where((r) => r.from == nodeId || r.to == nodeId);
  int degree(String nodeId) => roadsAt(nodeId).length;

  /// Road ends where traffic can enter or leave the model.
  List<RoadNode> get boundaryNodes => nodes.values.where((n) => degree(n.id) == 1).toList();

  List<Vec2> polyline(Road r) => [nodes[r.from]!.pos, ...r.shape, nodes[r.to]!.pos];

  double roadLength(Road r) => polylineLength(polyline(r));

  /// Unit direction in which [road] leaves [nodeId].
  Vec2 departureDirection(Road road, String nodeId) {
    final pts = polyline(road);
    final seq = road.from == nodeId ? pts : pts.reversed.toList();
    for (var i = 1; i < seq.length; i++) {
      final d = seq[i] - seq[0];
      if (d.length > 0.5) return d.normalized;
    }
    return Vec2.zero;
  }

  /// Lanes a road offers for traffic leaving / entering [nodeId].
  int lanesLeaving(Road r, String nodeId) => r.from == nodeId ? r.forward.lanes : r.backward.lanes;
  int lanesEntering(Road r, String nodeId) => r.to == nodeId ? r.forward.lanes : r.backward.lanes;

  ({Vec2 min, Vec2 max})? get bounds {
    if (nodes.isEmpty) return null;
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    void add(Vec2 p) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }

    for (final n in nodes.values) {
      add(n.pos);
      if (n.control == NodeControl.roundabout) {
        final r = (n.roundabout ?? const RoundaboutSpec()).radiusM;
        add(n.pos + Vec2(r, r));
        add(n.pos - Vec2(r, r));
      }
    }
    for (final r in roads.values) {
      r.shape.forEach(add);
    }
    return (min: Vec2(minX, minY), max: Vec2(maxX, maxY));
  }

  Map<String, dynamic> toJson() => {
        'drivingSide': drivingSide.name,
        'allowUTurns': allowUTurns,
        'nodes': nodes.values.map((n) => n.toJson()).toList(),
        'roads': roads.values.map((r) => r.toJson()).toList(),
        'nextNodeSeq': nextNodeSeq,
        'nextRoadSeq': nextRoadSeq,
      };

  /// Network block of a simulation request: only connected nodes, no editor fields.
  Map<String, dynamic> toApiJson() => {
        'drivingSide': drivingSide.name,
        'allowUTurns': allowUTurns,
        'nodes': nodes.values.where((n) => degree(n.id) > 0).map((n) => n.toApiJson()).toList(),
        'roads': roads.values.map((r) => r.toJson()).toList(),
      };

  factory Network.fromJson(Map<String, dynamic> j) {
    final nodes = <String, RoadNode>{};
    for (final n in (j['nodes'] as List? ?? const [])) {
      final node = RoadNode.fromJson(n as Map<String, dynamic>);
      nodes[node.id] = node;
    }
    final roads = <String, Road>{};
    for (final r in (j['roads'] as List? ?? const [])) {
      final road = Road.fromJson(r as Map<String, dynamic>);
      roads[road.id] = road;
    }
    return Network(
      drivingSide: j['drivingSide'] == 'left' ? DrivingSide.left : DrivingSide.right,
      allowUTurns: j['allowUTurns'] as bool? ?? false,
      nodes: nodes,
      roads: roads,
      nextNodeSeq: (j['nextNodeSeq'] as num?)?.toInt() ?? _nextSeq(nodes.keys, 'n'),
      nextRoadSeq: (j['nextRoadSeq'] as num?)?.toInt() ?? _nextSeq(roads.keys, 'r'),
    );
  }

  static int _nextSeq(Iterable<String> ids, String prefix) {
    var maxSeq = 0;
    for (final id in ids) {
      if (id.startsWith(prefix)) {
        final n = int.tryParse(id.substring(prefix.length));
        if (n != null && n > maxSeq) maxSeq = n;
      }
    }
    return maxSeq + 1;
  }
}
