import '../l10n/app_localizations.dart';
import '../model/network.dart';
import '../model/request_builder.dart';
import '../model/results.dart';

String fmtNum(double? v, {int decimals = 1}) => v == null || v.isNaN ? '—' : v.toStringAsFixed(decimals);

/// "12.3 ± 1.4" (95 % CI half-width), or just the mean when there is no interval.
String fmtStat(Stat s, {int decimals = 1}) {
  if (s.mean == null) return '—';
  final hw = s.halfWidth;
  return hw == null ? fmtNum(s.mean, decimals: decimals) : '${fmtNum(s.mean, decimals: decimals)} ± ${fmtNum(hw, decimals: decimals)}';
}

String fmtClock(double seconds) {
  final s = seconds.round();
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

String controlName(AppLocalizations l, NodeControl c) => switch (c) {
      NodeControl.priority => l.controlPriority,
      NodeControl.priorityStop => l.controlPriorityStop,
      NodeControl.trafficLight => l.controlTrafficLight,
      NodeControl.allwayStop => l.controlAllwayStop,
      NodeControl.rightBeforeLeft => l.controlRightBeforeLeft,
      NodeControl.roundabout => l.controlRoundabout,
    };

String controlNameApi(AppLocalizations l, String api) => controlName(l, NodeControl.fromApi(api));

String turnName(AppLocalizations l, TurnKind t) => switch (t) {
      TurnKind.left => l.turnLeft,
      TurnKind.through => l.turnThrough,
      TurnKind.right => l.turnRight,
      TurnKind.uTurn => l.turnU,
    };

String issueText(AppLocalizations l, DesignIssue i) {
  final a = i.args;
  return switch (i.code) {
    'noRoads' => l.issueNoRoads,
    'isolatedNode' => l.issueIsolatedNode(a['node'] ?? ''),
    'roundaboutNeedsRoads' => l.issueRoundaboutNeedsRoads(a['node'] ?? ''),
    'signalAtDeadEnd' => l.issueSignalAtDeadEnd(a['node'] ?? ''),
    'roadTooShort' => l.issueRoadTooShort(a['road'] ?? ''),
    'bayTooLong' => l.issueBayTooLong(a['road'] ?? '', a['bay'] ?? ''),
    'noGates' => l.issueNoGates,
    'noDemand' => l.issueNoDemand,
    'originNotGate' => l.issueOriginNotGate(a['node'] ?? ''),
    'originNoLanes' => l.issueOriginNoLanes(a['node'] ?? ''),
    'mixSum' => l.issueMixSum(a['node'] ?? '', a['sum'] ?? ''),
    'shareSum' => l.issueShareSum(a['node'] ?? '', a['sum'] ?? ''),
    'destinationInvalid' => l.issueDestinationInvalid(a['node'] ?? '', a['dest'] ?? ''),
    'sameOriginDestination' => l.issueSameOriginDestination(a['node'] ?? ''),
    'warmupTooLong' => l.issueWarmupTooLong,
    'fewReplications' => l.issueFewReplications(a['n'] ?? ''),
    'eidmStep' => l.issueEidmStep,
    _ => i.toString(),
  };
}

/// Readable name of an entry/exit point: user name or compass + id.
String gateName(Network net, String nodeId) {
  final n = net.nodes[nodeId];
  if (n == null) return nodeId;
  if (n.name != null && n.name!.isNotEmpty) return '${n.name} ($nodeId)';
  final c = compassLabel(net, n);
  return c.isEmpty ? nodeId : '$c · $nodeId';
}
