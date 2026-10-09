import '../core/geometry.dart';
import '../editor/network_ops.dart';
import 'network.dart';
import 'project.dart';
import 'request_builder.dart';
import 'scenario.dart';

enum ProjectTemplate { blank, signalised, tJunction, roundabout }

String newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

/// Starter projects. Template demand is an explicitly *assumed* scenario so that
/// the first simulation can run immediately; it is labelled as such everywhere.
Project createProject(String name, ProjectTemplate template, {String variantName = 'Existing'}) {
  var net = Network.empty;
  var demand = const Demand();
  const d = RoadDefaults();
  switch (template) {
    case ProjectTemplate.blank:
      break;
    case ProjectTemplate.signalised:
      net = insertTemplate(net, JunctionTemplate.fourWay, Vec2.zero, d, armM: 250);
      demand = _assumedDemand(net, 600);
    case ProjectTemplate.tJunction:
      net = insertTemplate(net, JunctionTemplate.tJunction, Vec2.zero, d.copyWith(lanesForward: 1, lanesBackward: 1), armM: 250);
      demand = _assumedDemand(net, 350);
    case ProjectTemplate.roundabout:
      net = insertTemplate(net, JunctionTemplate.roundabout, Vec2.zero, d, armM: 250);
      demand = _assumedDemand(net, 450);
  }
  final now = DateTime.now();
  final v = Variant(id: newId('v'), name: variantName, network: net, demand: demand);
  return Project(id: newId('p'), name: name, createdAt: now, updatedAt: now, variants: [v], activeVariantId: v.id);
}

/// Every road end sends [flow] veh/h: 60 % straight on, the rest split over the other turns.
Demand _assumedDemand(Network net, double flow) {
  final gs = gates(net);
  final origins = <String, OriginDemand>{};
  for (final o in gs) {
    final dests = gs.where((g) => g.node.id != o.node.id).toList();
    final through = dests.where((g) => turnKind(net, o.node.id, g.node.id) == TurnKind.through).toList();
    final others = dests.where((g) => !through.contains(g)).toList();
    final shares = <String, double>{};
    if (through.isEmpty || others.isEmpty) {
      for (final g in dests) {
        shares[g.node.id] = 1 / dests.length;
      }
    } else {
      for (final g in through) {
        shares[g.node.id] = 0.6 / through.length;
      }
      for (final g in others) {
        shares[g.node.id] = 0.4 / others.length;
      }
    }
    origins[o.node.id] = OriginDemand(flowVehPerHour: flow, shares: shares);
  }
  return Demand(source: DemandSource.assumed, note: 'Template scenario', origins: origins);
}
