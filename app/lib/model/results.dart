import 'dart:typed_data';

import '../core/geometry.dart';

/// Mean across replications with its 95 % confidence interval.
class Stat {
  final double? mean;
  final double? sd;
  final double? lo;
  final double? hi;
  final int n;
  const Stat({this.mean, this.sd, this.lo, this.hi, this.n = 0});

  factory Stat.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Stat();
    final ci = j['ci95'] as List?;
    return Stat(
      mean: (j['mean'] as num?)?.toDouble(),
      sd: (j['sd'] as num?)?.toDouble(),
      lo: (ci?[0] as num?)?.toDouble(),
      hi: (ci?[1] as num?)?.toDouble(),
      n: (j['n'] as num?)?.toInt() ?? 0,
    );
  }

  double? get halfWidth => (lo != null && hi != null && mean != null) ? (hi! - mean!) : null;
}

class ResultWarning {
  final String code;
  final String severity; // high | medium | info
  final String en;
  final String ar;
  const ResultWarning(this.code, this.severity, this.en, this.ar);
  String text(String lang) => lang == 'ar' ? ar : en;
}

class ApproachResult {
  final String node;
  final String road;
  final String direction;
  final String control;
  final int lanesAtStopLine;
  final double? lengthM;
  final Stat delay;
  final Stat avgQueue;
  final Stat p95Queue;
  final Stat maxQueue;
  final Stat throughput;
  final String? los;

  ApproachResult.fromJson(Map<String, dynamic> j)
      : node = j['node'] as String,
        road = j['road'] as String,
        direction = j['direction'] as String,
        control = j['control'] as String? ?? 'priority',
        lanesAtStopLine = (j['lanesAtStopLine'] as num?)?.toInt() ?? 0,
        lengthM = (j['lengthM'] as num?)?.toDouble(),
        delay = Stat.fromJson(j['metrics']?['avgDelayS'] as Map<String, dynamic>?),
        avgQueue = Stat.fromJson(j['metrics']?['avgQueueM'] as Map<String, dynamic>?),
        p95Queue = Stat.fromJson(j['metrics']?['p95QueueM'] as Map<String, dynamic>?),
        maxQueue = Stat.fromJson(j['metrics']?['maxQueueM'] as Map<String, dynamic>?),
        throughput = Stat.fromJson(j['metrics']?['throughputVehPerHour'] as Map<String, dynamic>?),
        los = j['los'] as String?;
}

class NodeResult {
  final String node;
  final String control;
  final Stat delay;
  final Stat throughput;
  final String? los;
  NodeResult.fromJson(Map<String, dynamic> j)
      : node = j['node'] as String,
        control = j['control'] as String? ?? 'priority',
        delay = Stat.fromJson(j['avgDelayS'] as Map<String, dynamic>?),
        throughput = Stat.fromJson(j['throughputVehPerHour'] as Map<String, dynamic>?),
        los = j['los'] as String?;
}

class MovementResult {
  final String origin;
  final String destination;
  final Stat vehicles;
  final Stat delay;
  final Stat travelTime;
  final Stat stops;
  MovementResult.fromJson(Map<String, dynamic> j)
      : origin = j['origin'] as String,
        destination = j['destination'] as String,
        vehicles = Stat.fromJson(j['metrics']?['vehicles'] as Map<String, dynamic>?),
        delay = Stat.fromJson(j['metrics']?['avgDelayS'] as Map<String, dynamic>?),
        travelTime = Stat.fromJson(j['metrics']?['avgTravelTimeS'] as Map<String, dynamic>?),
        stops = Stat.fromJson(j['metrics']?['avgStops'] as Map<String, dynamic>?);
}

class LaneStat {
  final String lane;
  final double? speedKmh;
  final double? speedRatio;
  final double? occupancyPct;
  LaneStat.fromJson(Map<String, dynamic> j)
      : lane = j['lane'] as String,
        speedKmh = (j['speedKmh'] as num?)?.toDouble(),
        speedRatio = (j['speedRatio'] as num?)?.toDouble(),
        occupancyPct = (j['occupancyPct'] as num?)?.toDouble();
}

/// Read-only typed view over the server's result JSON.
class SimulationResult {
  final Map<String, dynamic> raw;
  SimulationResult(this.raw);

  Map<String, dynamic> get _summary => (raw['summary'] as Map<String, dynamic>?) ?? const {};
  Stat metric(String key) => Stat.fromJson(_summary[key] as Map<String, dynamic>?);

  List<ApproachResult> get approaches =>
      ((raw['approaches'] as List?) ?? const []).map((e) => ApproachResult.fromJson(e as Map<String, dynamic>)).toList();
  List<NodeResult> get nodes =>
      ((raw['nodes'] as List?) ?? const []).map((e) => NodeResult.fromJson(e as Map<String, dynamic>)).toList();
  List<MovementResult> get movements =>
      ((raw['movements'] as List?) ?? const []).map((e) => MovementResult.fromJson(e as Map<String, dynamic>)).toList();
  List<LaneStat> get lanes =>
      ((raw['lanes'] as List?) ?? const []).map((e) => LaneStat.fromJson(e as Map<String, dynamic>)).toList();

  List<ResultWarning> get warnings => ((raw['warnings'] as List?) ?? const [])
      .map((e) => e as Map<String, dynamic>)
      .map((w) => ResultWarning(w['code'] as String, w['severity'] as String, w['en'] as String, w['ar'] as String))
      .toList();

  List<({String en, String ar})> get assumptions => ((raw['assumptions'] as List?) ?? const [])
      .map((e) => e as Map<String, dynamic>)
      .map((a) => (en: a['en'] as String, ar: a['ar'] as String))
      .toList();

  Map<String, String> get definitions =>
      ((raw['definitions'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String));

  String get reliabilityLevel => (raw['reliability']?['level'] as String?) ?? 'indicative';
  String reliabilityText(String lang) => (raw['reliability']?[lang] as String?) ?? '';
  bool get calibrated => (raw['reliability']?['calibrated'] as bool?) ?? false;

  String get engineLabel {
    final e = raw['engine'] as Map<String, dynamic>? ?? const {};
    return '${e['name'] ?? 'SUMO'} ${e['version'] ?? ''} · ${e['carFollowModel'] ?? ''}';
  }

  int get replications => (raw['run']?['replications'] as num?)?.toInt() ?? 0;
  double get durationS => (raw['run']?['durationS'] as num?)?.toDouble() ?? 0;
  double get warmupS => (raw['run']?['warmupS'] as num?)?.toDouble() ?? 0;
  String get demandSource => (raw['run']?['demandSource'] as String?) ?? 'assumed';
  bool get hasTrajectory => raw['hasTrajectory'] as bool? ?? false;
}

// --------------------------------------------------------------------------
// Simulated network geometry (what SUMO actually built) and trajectories.

class SimLane {
  final String id;
  final String edge;
  final String? road;
  final String? direction;
  final String? role;
  final int index;
  final double width;
  final double speedKmh;
  final List<Vec2> shape;
  SimLane.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        edge = j['edge'] as String,
        road = j['road'] as String?,
        direction = j['direction'] as String?,
        role = j['role'] as String?,
        index = (j['index'] as num).toInt(),
        width = (j['width'] as num).toDouble(),
        speedKmh = (j['speedKmh'] as num).toDouble(),
        shape = (j['shape'] as List).map((p) => Vec2.fromJson(p as List)).toList();
}

class SimJunction {
  final String id;
  final String? editorNode;
  final String type;
  final List<Vec2> shape;
  SimJunction.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        editorNode = j['editorNode'] as String?,
        type = j['type'] as String? ?? '',
        shape = (j['shape'] as List).map((p) => Vec2.fromJson(p as List)).toList();
}

class SimSignalLink {
  final String tl;
  final int linkIndex;
  final String fromLane;
  final Vec2 stop;
  final double headingDeg;
  SimSignalLink.fromJson(Map<String, dynamic> j)
      : tl = j['tl'] as String,
        linkIndex = (j['linkIndex'] as num).toInt(),
        fromLane = j['fromLane'] as String,
        stop = Vec2.fromJson(j['stop'] as List),
        headingDeg = (j['heading'] as num).toDouble();
}

class TlPhase {
  final double duration;
  final String state;
  const TlPhase(this.duration, this.state);
}

class SimNetwork {
  final List<SimLane> lanes;
  final List<SimJunction> junctions;
  final List<SimSignalLink> signals;
  final Map<String, List<TlPhase>> tlPrograms;
  final Vec2 min;
  final Vec2 max;

  SimNetwork.fromJson(Map<String, dynamic> j)
      : lanes = (j['lanes'] as List).map((e) => SimLane.fromJson(e as Map<String, dynamic>)).toList(),
        junctions = (j['junctions'] as List).map((e) => SimJunction.fromJson(e as Map<String, dynamic>)).toList(),
        signals = (j['signals'] as List).map((e) => SimSignalLink.fromJson(e as Map<String, dynamic>)).toList(),
        tlPrograms = {
          for (final p in (j['tlPrograms'] as List? ?? const []))
            (p['id'] as String): [
              for (final ph in (p['phases'] as List))
                TlPhase((ph['duration'] as num).toDouble(), ph['state'] as String)
            ]
        },
        min = Vec2(((j['bounds'] as List)[0] as num).toDouble(), ((j['bounds'] as List)[1] as num).toDouble()),
        max = Vec2(((j['bounds'] as List)[2] as num).toDouble(), ((j['bounds'] as List)[3] as num).toDouble());
}

class TrajVehicle {
  final String id;
  final String cls;
  final double length;
  final double width;
  const TrajVehicle(this.id, this.cls, this.length, this.width);
}

class SignalChange {
  final double t;
  final String tl;
  final String state;
  const SignalChange(this.t, this.tl, this.state);
}

/// Vehicle positions per sampled time step, exactly as written by SUMO.
class Trajectory {
  final double periodS;
  final double beginS;
  final double endS;
  final List<TrajVehicle> vehicles;
  final Float64List times;

  /// Per frame: vehicle index, x, y, SUMO angle (deg, clockwise from north), speed (m/s).
  final List<Float32List> frames;
  final List<SignalChange> signals;

  Trajectory._(this.periodS, this.beginS, this.endS, this.vehicles, this.times, this.frames, this.signals);

  factory Trajectory.fromJson(Map<String, dynamic> j) {
    final stride = (j['stride'] as num?)?.toInt() ?? 5;
    if (stride != 5) throw const FormatException('unsupported trajectory stride');
    final vehicles = [
      for (final v in (j['vehicles'] as List))
        TrajVehicle(v['id'] as String, v['cls'] as String, (v['length'] as num).toDouble(), (v['width'] as num).toDouble())
    ];
    final times = Float64List.fromList([for (final t in (j['times'] as List)) (t as num).toDouble()]);
    final frames = [
      for (final f in (j['frames'] as List)) Float32List.fromList([for (final x in (f as List)) (x as num).toDouble()])
    ];
    final signals = [
      for (final s in (j['signals'] as List? ?? const []))
        SignalChange((s['t'] as num).toDouble(), s['tl'] as String, s['state'] as String)
    ];
    return Trajectory._(
      (j['periodS'] as num).toDouble(),
      (j['beginS'] as num).toDouble(),
      (j['endS'] as num).toDouble(),
      vehicles,
      times,
      frames,
      signals,
    );
  }

  int get frameCount => times.length;
  double get firstTime => times.isEmpty ? beginS : times.first;
  double get lastTime => times.isEmpty ? beginS : times.last;

  /// Index of the last frame at or before [t].
  int frameAt(double t) {
    if (times.isEmpty) return 0;
    var lo = 0, hi = times.length - 1;
    if (t <= times[0]) return 0;
    if (t >= times[hi]) return hi;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Signal state string of [tl] at time [t].
  String? signalState(String tl, double t) {
    String? state;
    for (final s in signals) {
      if (s.t > t) break;
      if (s.tl == tl) state = s.state;
    }
    return state;
  }
}
