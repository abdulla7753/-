import 'dart:convert';
import 'dart:math' as math;

import '../core/geometry.dart';
import 'network.dart';
import 'project.dart';

/// A problem found before sending a design to the simulation server.
class DesignIssue {
  final String code;
  final Map<String, String> args;
  final bool blocking;
  const DesignIssue(this.code, {this.args = const {}, this.blocking = true});
  @override
  String toString() => '$code$args';
}

enum TurnKind { left, through, right, uTurn }

/// Entry/exit points of the model: road ends (nodes connected to a single road).
class Gate {
  final RoadNode node;
  final Road road;
  final int lanesIn; // lanes carrying traffic into the network from this gate
  final int lanesOut;
  const Gate(this.node, this.road, this.lanesIn, this.lanesOut);
}

List<Gate> gates(Network net) {
  final out = <Gate>[];
  for (final n in net.boundaryNodes) {
    final road = net.roadsAt(n.id).first;
    out.add(Gate(n, road, net.lanesLeaving(road, n.id), net.lanesEntering(road, n.id)));
  }
  return out;
}

/// Compass label (N, NE, E, ...) of a node relative to the network centre.
String compassLabel(Network net, RoadNode node) {
  final b = net.bounds;
  if (b == null) return '';
  final c = (b.min + b.max) * 0.5;
  if (node.pos.distanceTo(c) < 1) return '';
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final idx = ((bearingDeg(c, node.pos) + 22.5) ~/ 45) % 8;
  return names[idx];
}

/// Overall turn of a trip entering at [origin] and leaving at [destination].
TurnKind turnKind(Network net, String origin, String destination) {
  if (origin == destination) return TurnKind.uTurn;
  final o = net.nodes[origin]!, d = net.nodes[destination]!;
  final inDir = net.departureDirection(net.roadsAt(origin).first, origin); // heading into the network
  final outDir = -net.departureDirection(net.roadsAt(destination).first, destination); // heading when leaving
  if (inDir == Vec2.zero || outDir == Vec2.zero) return TurnKind.through;
  final ang = wrapAngle(outDir.angle - inDir.angle);
  final deg = radToDeg(ang);
  if (deg.abs() > 150) {
    // Opposite headings: a U-turn only if the exit is back on the entry side.
    final side = (d.pos - o.pos).dot(inDir);
    return side < 0 ? TurnKind.uTurn : TurnKind.through;
  }
  if (deg > 40) return TurnKind.left;
  if (deg < -40) return TurnKind.right;
  return TurnKind.through;
}

List<DesignIssue> validate(Variant v) {
  final net = v.network;
  final issues = <DesignIssue>[];
  if (net.roads.isEmpty) {
    return [const DesignIssue('noRoads')];
  }
  for (final n in net.nodes.values) {
    final deg = net.degree(n.id);
    if (deg == 0) issues.add(DesignIssue('isolatedNode', args: {'node': n.id}, blocking: false));
    if (n.control == NodeControl.roundabout && deg < 2) {
      issues.add(DesignIssue('roundaboutNeedsRoads', args: {'node': n.id}));
    }
    if (n.control == NodeControl.trafficLight && deg == 1) {
      issues.add(DesignIssue('signalAtDeadEnd', args: {'node': n.id}, blocking: false));
    }
  }
  for (final r in net.roads.values) {
    final len = net.roadLength(r);
    if (len < 1) issues.add(DesignIssue('roadTooShort', args: {'road': r.id}));
    for (final (dir, spec) in [('forward', r.forward), ('backward', r.backward)]) {
      final bay = math.max(spec.leftBay?.lengthM ?? 0, spec.rightBay?.lengthM ?? 0);
      if (spec.lanes > 0 && bay > 0 && bay > len - 15) {
        issues.add(DesignIssue('bayTooLong', args: {'road': r.id, 'dir': dir, 'bay': bay.toStringAsFixed(0)}));
      }
    }
  }
  final gs = {for (final g in gates(net)) g.node.id: g};
  if (gs.isEmpty) issues.add(const DesignIssue('noGates'));
  final active = v.demand.origins.entries.where((e) => e.value.flowVehPerHour > 0).toList();
  if (active.isEmpty) issues.add(const DesignIssue('noDemand'));
  for (final e in active) {
    final g = gs[e.key];
    if (g == null) {
      issues.add(DesignIssue('originNotGate', args: {'node': e.key}));
      continue;
    }
    if (g.lanesIn == 0) issues.add(DesignIssue('originNoLanes', args: {'node': e.key}));
    final o = e.value;
    if ((o.mix.total - 1).abs() > 0.001) {
      issues.add(DesignIssue('mixSum', args: {'node': e.key, 'sum': (o.mix.total * 100).toStringAsFixed(1)}));
    }
    final valid = o.shares.entries.where((s) => s.value > 0).toList();
    final total = valid.fold(0.0, (a, s) => a + s.value);
    if ((total - 1).abs() > 0.001) {
      issues.add(DesignIssue('shareSum', args: {'node': e.key, 'sum': (total * 100).toStringAsFixed(1)}));
    }
    for (final s in valid) {
      final dg = gs[s.key];
      if (dg == null || dg.lanesOut == 0) {
        issues.add(DesignIssue('destinationInvalid', args: {'node': e.key, 'dest': s.key}));
      } else if (s.key == e.key) {
        issues.add(DesignIssue('sameOriginDestination', args: {'node': e.key}));
      }
    }
  }
  final run = v.run;
  if (run.warmupS >= run.durationS) issues.add(const DesignIssue('warmupTooLong'));
  if (run.replications < 5) {
    issues.add(DesignIssue('fewReplications', args: {'n': '${run.replications}'}, blocking: false));
  }
  if (v.drivers.carFollowModel == 'EIDM' && run.stepLengthS > 0.5) issues.add(const DesignIssue('eidmStep'));
  return issues;
}

Map<String, dynamic> buildBuildRequest(Variant v) => {
      'schemaVersion': 1,
      'network': v.network.toApiJson(),
      'signals': v.signals.toJson(),
    };

Map<String, dynamic> buildSimulationRequest(Variant v, {String? label}) {
  final origins = <Map<String, dynamic>>[];
  for (final e in v.demand.origins.entries) {
    final o = e.value;
    if (o.flowVehPerHour <= 0) continue;
    final dests = [
      for (final s in o.shares.entries)
        if (s.value > 0) {'node': s.key, 'share': s.value}
    ];
    origins.add({'node': e.key, 'flowVehPerHour': o.flowVehPerHour, 'mix': o.mix.toJson(), 'destinations': dests});
  }
  final run = v.run;
  return {
    'schemaVersion': 1,
    'label': ?label,
    'network': v.network.toApiJson(),
    'signals': v.signals.toJson(),
    'demand': {
      'source': v.demand.source.name,
      if (v.demand.note.isNotEmpty) 'sourceNote': v.demand.note,
      'arrivals': v.demand.poissonArrivals ? 'poisson' : 'uniform',
      'origins': origins,
    },
    'drivers': v.drivers.toJson(),
    'run': {
      'durationS': run.durationS,
      'warmupS': run.warmupS,
      'stepLengthS': run.stepLengthS,
      'replications': run.replications,
      'baseSeed': run.baseSeed,
      'trajectory': {
        'enabled': run.trajectory,
        'periodS': math.max(run.trajectoryPeriodS, run.stepLengthS),
        'beginS': 0,
        'maxDurationS': math.min(run.trajectoryMaxS, run.durationS),
      },
    },
  };
}

/// Stable fingerprint of a request (two 32-bit FNV-1a passes over its JSON), excluding the label.
/// 32-bit arithmetic keeps the result identical on native and web builds.
String requestFingerprint(Map<String, dynamic> request) {
  final copy = Map<String, dynamic>.of(request)..remove('label');
  final bytes = utf8.encode(jsonEncode(copy));
  int fnv(int seed) {
    var h = seed;
    for (final b in bytes) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = (((h << 24) & 0xFFFFFFFF) + h * 403) & 0xFFFFFFFF; // h * 16777619 mod 2^32
    }
    return h;
  }

  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return hex(fnv(0x811c9dc5)) + hex(fnv(0x01000193));
}
