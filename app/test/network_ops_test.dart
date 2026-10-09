import 'package:flutter_test/flutter_test.dart';
import 'package:roadflow_ai/core/geometry.dart';
import 'package:roadflow_ai/editor/editor_controller.dart';
import 'package:roadflow_ai/editor/network_ops.dart';
import 'package:roadflow_ai/model/network.dart';
import 'package:roadflow_ai/model/project.dart';
import 'package:roadflow_ai/model/project_factory.dart';
import 'package:roadflow_ai/model/scenario.dart';
import 'package:roadflow_ai/services/project_store_memory.dart';

const d = RoadDefaults();

Network draw(Network n, Vec2 a, Vec2 b, {bool junctions = true}) {
  final r = addRoad(n, snap(n, a, 2), snap(n, b, 2), const [], d, autoJunctions: junctions);
  expect(r, isNotNull);
  return r!.net;
}

void main() {
  test('drawing a road creates two nodes and one road', () {
    final n = draw(Network.empty, const Vec2(0, 0), const Vec2(100, 0));
    expect(n.nodes.length, 2);
    expect(n.roads.length, 1);
    final r = n.roads.values.first;
    expect(n.roadLength(r), closeTo(100, 1e-9));
    expect(r.forward.lanes, d.lanesForward);
  });

  test('ending on an existing road splits it into a T-junction', () {
    var n = draw(Network.empty, const Vec2(-100, 0), const Vec2(100, 0));
    n = draw(n, const Vec2(0, -80), const Vec2(0, 0.5));
    expect(n.roads.length, 3);
    final junction = n.nodes.values.firstWhere((x) => n.degree(x.id) == 3);
    expect(junction.pos.distanceTo(Vec2.zero), lessThan(1e-6));
    expect(n.boundaryNodes.length, 3);
  });

  test('crossing roads get a four-way junction', () {
    var n = draw(Network.empty, const Vec2(-100, 0), const Vec2(100, 0));
    n = draw(n, const Vec2(0, -100), const Vec2(0, 100));
    expect(n.roads.length, 4);
    expect(n.nodes.values.where((x) => n.degree(x.id) == 4).length, 1);
  });

  test('grade-separated crossing when automatic junctions are off', () {
    var n = draw(Network.empty, const Vec2(-100, 0), const Vec2(100, 0));
    n = draw(n, const Vec2(0, -100), const Vec2(0, 100), junctions: false);
    expect(n.roads.length, 2);
    expect(n.nodes.values.every((x) => n.degree(x.id) == 1), isTrue);
  });

  test('splitting keeps turn bays at the ends they serve', () {
    var n = draw(Network.empty, const Vec2(0, 0), const Vec2(200, 0));
    final r = n.roads.values.first;
    n = updateRoad(
      n,
      r.copyWith(
        forward: r.forward.copyWith(leftBay: const TurnBay(lanes: 1, lengthM: 40)),
        backward: r.backward.copyWith(rightBay: const TurnBay(lanes: 1, lengthM: 30)),
      ),
    );
    final res = splitRoad(n, r.id, 100);
    final first = res.net.roads[r.id]!;
    final second = res.net.roads.values.firstWhere((x) => x.id != r.id);
    expect(first.forward.leftBay, isNull);
    expect(first.backward.rightBay, isNotNull); // backward traffic ends at the original start
    expect(second.forward.leftBay, isNotNull); // forward traffic ends at the original end
    expect(second.backward.rightBay, isNull);
    expect(res.net.roadLength(first) + res.net.roadLength(second), closeTo(200, 1e-9));
  });

  test('deleting a road removes orphaned nodes', () {
    var n = draw(Network.empty, const Vec2(-100, 0), const Vec2(100, 0));
    n = draw(n, const Vec2(0, -80), const Vec2(0, 0.5));
    final stem = n.roads.values.firstWhere((r) => n.nodes[r.from]!.pos.y < -1 || n.nodes[r.to]!.pos.y < -1);
    n = deleteRoad(n, stem.id);
    expect(n.roads.length, 2);
    expect(n.nodes.length, 3);
  });

  test('junction templates', () {
    final four = insertTemplate(Network.empty, JunctionTemplate.fourWay, Vec2.zero, d);
    expect(four.roads.length, 4);
    expect(four.nodes.values.where((n) => n.control == NodeControl.trafficLight).length, 1);
    final rb = insertTemplate(Network.empty, JunctionTemplate.roundabout, Vec2.zero, d);
    expect(rb.nodes.values.firstWhere((n) => n.control == NodeControl.roundabout).roundabout, isNotNull);
    final t = insertTemplate(Network.empty, JunctionTemplate.tJunction, Vec2.zero, d);
    expect(t.boundaryNodes.length, 3);
  });

  group('EditorController', () {
    late EditorController c;
    setUp(() => c = EditorController(MemoryProjectStore(), createProject('t', ProjectTemplate.blank)));

    test('undo and redo restore network states', () {
      c.addRoad(SnapFree(const Vec2(0, 0)), SnapFree(const Vec2(100, 0)), const []);
      c.addRoad(snap(c.network, const Vec2(50, 0), 2), SnapFree(const Vec2(50, 80)), const []);
      expect(c.network.roads.length, 3);
      c.undo();
      expect(c.network.roads.length, 1);
      c.undo();
      expect(c.network.roads, isEmpty);
      expect(c.canUndo, isFalse);
      c.redo();
      c.redo();
      expect(c.network.roads.length, 3);
    });

    test('node drag is one history step', () {
      c.addRoad(SnapFree(const Vec2(0, 0)), SnapFree(const Vec2(100, 0)), const []);
      final id = c.network.nodes.keys.first;
      for (var x = 1; x <= 10; x++) {
        c.previewNodeMove(id, Vec2(x.toDouble(), 5));
      }
      c.endDrag();
      expect(c.network.nodes[id]!.pos, const Vec2(10, 5));
      c.undo();
      expect(c.network.nodes[id]!.pos, const Vec2(0, 0));
    });

    test('extending a road end carries its traffic demand to the new end', () {
      c.addRoad(SnapFree(const Vec2(0, 0)), SnapFree(const Vec2(100, 0)), const []);
      final gateA = c.network.nodes.values.firstWhere((n) => n.pos == const Vec2(0, 0)).id;
      final gateB = c.network.nodes.values.firstWhere((n) => n.pos == const Vec2(100, 0)).id;
      c.updateDemand(Demand(origins: {gateA: OriginDemand(flowVehPerHour: 500, shares: {gateB: 1})}));
      c.addRoad(snap(c.network, Vec2.zero, 2), SnapFree(const Vec2(-150, 0)), const []);
      final newGate = c.network.nodes.values.firstWhere((n) => n.pos == const Vec2(-150, 0)).id;
      expect(c.variant.demand.origins.keys, [newGate]);
      expect(c.variant.demand.origins[newGate]!.flowVehPerHour, 500);
    });

    test('variants are independent copies', () {
      c.addRoad(SnapFree(const Vec2(0, 0)), SnapFree(const Vec2(100, 0)), const []);
      final original = c.variant.id;
      c.duplicateVariant('B');
      c.addRoad(SnapFree(const Vec2(0, 50)), SnapFree(const Vec2(100, 50)), const []);
      expect(c.network.roads.length, 2);
      c.switchVariant(original);
      expect(c.network.roads.length, 1);
      expect(c.project.variants.length, 2);
    });

    test('project JSON round trip', () {
      c.addRoad(SnapFree(const Vec2(0, 0)), SnapFree(const Vec2(100, 0)), const [Vec2(50, 20)]);
      final copy = Project.fromJson(c.project.toJson());
      expect(copy.active.network.roads.values.first.shape, [const Vec2(50, 20)]);
      expect(copy.toJson(), c.project.toJson());
    });
  });
}
