import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roadflow_ai/core/geometry.dart';
import 'package:roadflow_ai/model/network.dart';
import 'package:roadflow_ai/model/project.dart';
import 'package:roadflow_ai/model/project_factory.dart';
import 'package:roadflow_ai/model/request_builder.dart';
import 'package:roadflow_ai/model/results.dart';
import 'package:roadflow_ai/model/scenario.dart';

/// The server's test-suite validates the same fixtures, so these tests pin the
/// JSON contract from both sides (see shared/fixtures and docs/API.md).
/// Compare JSON values numerically (the server accepts 60 and 60.0 alike).
Object? _num(Object? v) => switch (v) {
      num n => n.toDouble(),
      Map m => {for (final e in m.entries) e.key: _num(e.value)},
      List l => [for (final x in l) _num(x)],
      _ => v,
    };

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('../shared/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  for (final name in ['four_way_signalized', 't_junction_stop', 'roundabout_two_lane']) {
    test('network block of $name round-trips through the app model', () {
      final f = fixture(name);
      final net = Network.fromJson(f['network'] as Map<String, dynamic>);
      final api = net.toApiJson();
      final fn = f['network'] as Map<String, dynamic>;
      expect(api['drivingSide'], fn['drivingSide'] ?? 'right');
      final fNodes = {for (final n in fn['nodes'] as List) n['id']: n};
      for (final n in api['nodes'] as List) {
        final src = fNodes[n['id']] as Map<String, dynamic>;
        expect(n['x'], (src['x'] as num).toDouble());
        expect(n['y'], (src['y'] as num).toDouble());
        expect(n['control'], src['control'] ?? 'priority');
        if (src['roundabout'] != null) expect(n['roundabout'], src['roundabout']);
      }
      final fRoads = {for (final r in fn['roads'] as List) r['id']: r};
      for (final r in api['roads'] as List) {
        final src = fRoads[r['id']] as Map<String, dynamic>;
        for (final k in ['from', 'to', 'forward', 'backward', 'speedLimitKmh']) {
          expect(_num(r[k]), _num(src[k]), reason: '$name road ${r['id']} $k');
        }
        expect((r['shape'] as List).length, (src['shape'] as List? ?? const []).length);
      }
    });
  }

  test('simulation request has the server schema shape', () {
    final p = createProject('x', ProjectTemplate.signalised);
    final req = buildSimulationRequest(p.active, label: 'demo');
    expect(req.keys.toSet(), {'schemaVersion', 'label', 'network', 'signals', 'demand', 'drivers', 'run'});
    expect(req['schemaVersion'], 1);
    final demand = req['demand'] as Map<String, dynamic>;
    expect(demand['source'], 'assumed');
    expect(demand['arrivals'], 'poisson');
    for (final o in demand['origins'] as List) {
      final shares = (o['destinations'] as List).fold<double>(0, (a, d) => a + (d['share'] as num));
      expect(shares, closeTo(1, 1e-9));
      final mix = o['mix'] as Map<String, dynamic>;
      expect((mix['car'] as num) + (mix['truck'] as num) + (mix['bus'] as num), closeTo(1, 1e-9));
    }
    final run = req['run'] as Map<String, dynamic>;
    expect((run['trajectory'] as Map)['periodS'], greaterThanOrEqualTo(run['stepLengthS'] as num));
    // Editor-only fields never reach the server (it rejects unknown fields).
    for (final n in (req['network'] as Map)['nodes'] as List) {
      expect((n as Map).containsKey('name'), isFalse);
    }
    expect((req['network'] as Map).containsKey('nextNodeSeq'), isFalse);
    expect(validate(p.active).where((i) => i.blocking), isEmpty);
  });

  test('fingerprint changes with the design and ignores the label', () {
    final p = createProject('x', ProjectTemplate.signalised);
    final a = requestFingerprint(buildSimulationRequest(p.active, label: 'one'));
    final b = requestFingerprint(buildSimulationRequest(p.active, label: 'two'));
    expect(a, b);
    final changed = p.active.copyWith(run: p.active.run.copyWith(replications: 9));
    expect(requestFingerprint(buildSimulationRequest(changed)), isNot(a));
  });

  test('validation catches demand errors', () {
    final p = createProject('x', ProjectTemplate.signalised);
    final v = p.active;
    final origin = v.demand.origins.keys.first;
    final bad = v.copyWith(
      demand: v.demand.copyWith(origins: {
        ...v.demand.origins,
        origin: v.demand.origins[origin]!.copyWith(shares: {v.demand.origins[origin]!.shares.keys.first: 0.5}),
      }),
    );
    final codes = validate(bad).map((i) => i.code).toSet();
    expect(codes, contains('shareSum'));
    final empty = Variant(id: 'e', name: 'e');
    expect(validate(empty).map((i) => i.code), contains('noRoads'));
  });

  test('turn classification on a four-arm junction (right-hand traffic)', () {
    final p = createProject('x', ProjectTemplate.signalised);
    final net = p.active.network;
    String at(Vec2 pos) => net.nodes.values.firstWhere((n) => n.pos.distanceTo(pos) < 1).id;
    final s = at(const Vec2(0, -250)), n = at(const Vec2(0, 250)), e = at(const Vec2(250, 0)), w = at(const Vec2(-250, 0));
    expect(turnKind(net, s, n), TurnKind.through);
    expect(turnKind(net, s, w), TurnKind.left);
    expect(turnKind(net, s, e), TurnKind.right);
  });

  test('template demand is assumed and 60 % straight on', () {
    final p = createProject('x', ProjectTemplate.signalised);
    expect(p.active.demand.source, DemandSource.assumed);
    final net = p.active.network;
    for (final e in p.active.demand.origins.entries) {
      final through = e.value.shares.entries.where((s) => turnKind(net, e.key, s.key) == TurnKind.through);
      expect(through.fold<double>(0, (a, s) => a + s.value), closeTo(0.6, 1e-9));
    }
  });

  test('trajectory parsing and frame lookup', () {
    final t = Trajectory.fromJson({
      'periodS': 0.5,
      'beginS': 0,
      'endS': 1,
      'stride': 5,
      'vehicles': [
        {'id': 'a', 'cls': 'car', 'length': 5, 'width': 1.8}
      ],
      'times': [0, 0.5, 1.0],
      'frames': [
        [0, 0, 0, 90, 10],
        [0, 5, 0, 90, 10],
        [],
      ],
      'signals': [
        {'t': 0, 'tl': 'c', 'state': 'Gr'},
        {'t': 0.7, 'tl': 'c', 'state': 'yr'},
      ],
    });
    expect(t.frameAt(0.6), 1);
    expect(t.frameAt(5), 2);
    expect(t.signalState('c', 0.5), 'Gr');
    expect(t.signalState('c', 0.8), 'yr');
  });
}
