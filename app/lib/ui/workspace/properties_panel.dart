import 'package:flutter/material.dart';

import '../../editor/editor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../model/network.dart';
import '../format.dart';
import '../widgets/common.dart';

class PropertiesPanel extends StatelessWidget {
  final EditorController editor;
  const PropertiesPanel({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sel = editor.selection;
    final Widget body;
    if (sel is NodeSelection && editor.network.nodes[sel.id] != null) {
      body = _NodeProperties(editor: editor, node: editor.network.nodes[sel.id]!);
    } else if (sel is RoadSelection && editor.network.roads[sel.id] != null) {
      body = _RoadProperties(editor: editor, road: editor.network.roads[sel.id]!);
    } else {
      body = _NetworkProperties(editor: editor);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (sel == null) InfoBanner(icon: Icons.touch_app_outlined, text: l.propertiesHint, color: Colors.blueGrey),
      body,
    ]);
  }
}

class _NetworkProperties extends StatelessWidget {
  final EditorController editor;
  const _NetworkProperties({required this.editor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final net = editor.network;
    final d = editor.roadDefaults;
    final totalLen = net.roads.values.fold(0.0, (a, r) => a + net.roadLength(r));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelSection(title: l.networkSettings, children: [
        Text(l.drivingSide),
        const SizedBox(height: 4),
        SegmentedButton<DrivingSide>(
          segments: [
            ButtonSegment(value: DrivingSide.right, label: Text(l.drivingRight)),
            ButtonSegment(value: DrivingSide.left, label: Text(l.drivingLeft)),
          ],
          selected: {net.drivingSide},
          onSelectionChanged: (s) => editor.setNetworkOptions(side: s.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.allowUTurns),
          subtitle: Text(l.allowUTurnsHint),
          value: net.allowUTurns,
          onChanged: (v) => editor.setNetworkOptions(uTurns: v),
        ),
      ]),
      PanelSection(title: l.newRoadDefaults, children: [
        StepperField(
            label: l.lanesForward,
            value: d.lanesForward,
            min: 0,
            max: 6,
            onChanged: (v) => editor.setOptions(defaults: d.copyWith(lanesForward: v))),
        StepperField(
            label: l.lanesBackward,
            value: d.lanesBackward,
            min: 0,
            max: 6,
            onChanged: (v) => editor.setOptions(defaults: d.copyWith(lanesBackward: v))),
        NumberField(
            label: l.laneWidth,
            suffix: 'm',
            decimals: 2,
            value: d.laneWidthM,
            min: 2.5,
            max: 5.5,
            onChanged: (v) => editor.setOptions(defaults: d.copyWith(laneWidthM: v))),
        NumberField(
            label: l.speedLimit,
            suffix: 'km/h',
            value: d.speedLimitKmh,
            min: 5,
            max: 140,
            onChanged: (v) => editor.setOptions(defaults: d.copyWith(speedLimitKmh: v))),
        Text(l.defaultsNotStandards, style: Theme.of(context).textTheme.bodySmall),
      ]),
      PanelSection(title: l.networkSummary, children: [
        Text(l.summaryCounts(net.nodes.length, net.roads.length)),
        Text(l.summaryLength((totalLen / 1000).toStringAsFixed(2))),
      ]),
    ]);
  }
}

class _NodeProperties extends StatelessWidget {
  final EditorController editor;
  final RoadNode node;
  const _NodeProperties({required this.editor, required this.node});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final net = editor.network;
    final deg = net.degree(node.id);
    final rb = node.roundabout ?? const RoundaboutSpec();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelSection(
        title: deg == 1 ? l.gateTitle(node.id) : l.nodeTitle(node.id),
        trailing: IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: editor.deleteSelection),
        children: [
          Text(l.nodeDegree(deg)),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('name_${node.id}'),
            initialValue: node.name ?? '',
            decoration: InputDecoration(labelText: l.name, border: const OutlineInputBorder()),
            onFieldSubmitted: (v) => editor.updateNode(v.trim().isEmpty ? node.copyWith(clearName: true) : node.copyWith(name: v.trim())),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: NumberField(
                  key: ValueKey('x_${node.id}'),
                  label: 'X',
                  suffix: 'm',
                  decimals: 1,
                  value: node.pos.x,
                  min: -1e6,
                  max: 1e6,
                  onChanged: (v) => editor.updateNode(node.copyWith(pos: node.pos.copyWithX(v)))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(
                  key: ValueKey('y_${node.id}'),
                  label: 'Y',
                  suffix: 'm',
                  decimals: 1,
                  value: node.pos.y,
                  min: -1e6,
                  max: 1e6,
                  onChanged: (v) => editor.updateNode(node.copyWith(pos: node.pos.copyWithY(v)))),
            ),
          ]),
          NumberField(
            key: ValueKey('z_${node.id}'),
            label: l.elevation,
            suffix: 'm',
            decimals: 2,
            value: node.z,
            min: -100,
            max: 500,
            onChanged: (v) => editor.updateNode(node.copyWith(z: v)),
          ),
        ],
      ),
      if (deg >= 2)
        PanelSection(title: l.junctionControl, children: [
          DropdownButtonFormField<NodeControl>(
            key: ValueKey('nodeControl_${node.id}_${node.control.api}'),
            initialValue: node.control,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [for (final c in NodeControl.values) DropdownMenuItem(value: c, child: Text(controlName(l, c)))],
            onChanged: (c) {
              if (c == null) return;
              editor.updateNode(node.copyWith(control: c, roundabout: c == NodeControl.roundabout ? rb : null));
            },
          ),
          const SizedBox(height: 6),
          Text(_controlHelp(l, node.control), style: Theme.of(context).textTheme.bodySmall),
          if (node.control == NodeControl.roundabout) ...[
            const SizedBox(height: 8),
            NumberField(
                label: l.roundaboutRadius,
                suffix: 'm',
                decimals: 1,
                value: rb.radiusM,
                min: 8,
                max: 150,
                helper: l.roundaboutRadiusHelp,
                onChanged: (v) => editor.updateNode(node.copyWith(roundabout: rb.copyWith(radiusM: v)))),
            StepperField(
                label: l.circulatingLanes,
                value: rb.lanes,
                min: 1,
                max: 4,
                onChanged: (v) => editor.updateNode(node.copyWith(roundabout: rb.copyWith(lanes: v)))),
            NumberField(
                label: l.laneWidth,
                suffix: 'm',
                decimals: 2,
                value: rb.laneWidthM,
                min: 2.5,
                max: 6,
                onChanged: (v) => editor.updateNode(node.copyWith(roundabout: rb.copyWith(laneWidthM: v)))),
            NumberField(
                label: l.circulatingSpeed,
                suffix: 'km/h',
                value: rb.speedLimitKmh,
                min: 10,
                max: 80,
                onChanged: (v) => editor.updateNode(node.copyWith(roundabout: rb.copyWith(speedLimitKmh: v)))),
          ],
        ]),
    ]);
  }

  String _controlHelp(AppLocalizations l, NodeControl c) => switch (c) {
        NodeControl.priority => l.helpPriority,
        NodeControl.priorityStop => l.helpPriorityStop,
        NodeControl.trafficLight => l.helpTrafficLight,
        NodeControl.allwayStop => l.helpAllwayStop,
        NodeControl.rightBeforeLeft => l.helpRightBeforeLeft,
        NodeControl.roundabout => l.helpRoundabout,
      };
}

class _RoadProperties extends StatelessWidget {
  final EditorController editor;
  final Road road;
  const _RoadProperties({required this.editor, required this.road});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final net = editor.network;
    final len = net.roadLength(road);
    final dz = net.nodes[road.to]!.z - net.nodes[road.from]!.z;
    final grade = len > 0 ? dz / len * 100 : 0.0;
    void update(Road r) => editor.updateRoad(r);

    Widget direction(String title, Direction d, String toward, ValueChanged<Direction> onChanged) {
      return PanelSection(title: title, children: [
        Text(l.towardNode(gateName(net, toward)), style: Theme.of(context).textTheme.bodySmall),
        StepperField(
          label: l.throughLanes,
          value: d.lanes,
          min: 0,
          max: 8,
          onChanged: (v) {
            final other = identical(d, road.forward) ? road.backward : road.forward;
            if (v == 0 && other.lanes == 0) return;
            onChanged(d.copyWith(lanes: v));
          },
        ),
        if (d.lanes > 0) ...[
          _BayEditor(
            label: l.leftTurnBay,
            bay: d.leftBay,
            onChanged: (b) => onChanged(b == null ? d.copyWith(clearLeft: true) : d.copyWith(leftBay: b)),
          ),
          _BayEditor(
            label: l.rightTurnBay,
            bay: d.rightBay,
            onChanged: (b) => onChanged(b == null ? d.copyWith(clearRight: true) : d.copyWith(rightBay: b)),
          ),
        ],
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelSection(
        title: l.roadTitle(road.id),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: l.reverseDirection, icon: const Icon(Icons.swap_horiz), onPressed: () => update(road.reversed())),
          IconButton(
              tooltip: l.splitRoad, icon: const Icon(Icons.call_split), onPressed: () => editor.splitRoadAtMiddle(road.id)),
          IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: editor.deleteSelection),
        ]),
        children: [
          Text(l.roadGeometry(len.toStringAsFixed(1), grade.toStringAsFixed(2))),
          if (grade.abs() > 0) Text(l.gradeNote, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('rname_${road.id}'),
            initialValue: road.name ?? '',
            decoration: InputDecoration(labelText: l.name, border: const OutlineInputBorder()),
            onFieldSubmitted: (v) => update(v.trim().isEmpty ? road.copyWith(clearName: true) : road.copyWith(name: v.trim())),
          ),
          const SizedBox(height: 4),
          NumberField(
            key: ValueKey('speed_${road.id}'),
            label: l.speedLimit,
            suffix: 'km/h',
            value: road.speedLimitKmh,
            min: 5,
            max: 140,
            onChanged: (v) => update(road.copyWith(speedLimitKmh: v)),
          ),
          NumberField(
            key: ValueKey('width_${road.id}'),
            label: l.laneWidth,
            suffix: 'm',
            decimals: 2,
            value: road.laneWidthM,
            min: 2.5,
            max: 5.5,
            onChanged: (v) => update(road.copyWith(laneWidthM: v)),
          ),
          const SizedBox(height: 4),
          Text(l.roadPriority),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l.priorityAuto)),
              ButtonSegment(value: 3, label: Text(l.priorityMajor)),
              ButtonSegment(value: 1, label: Text(l.priorityMinor)),
            ],
            selected: {road.priority ?? 0},
            onSelectionChanged: (s) =>
                update(s.first == 0 ? road.copyWith(clearPriority: true) : road.copyWith(priority: s.first)),
          ),
        ],
      ),
      direction(l.directionForward, road.forward, road.to, (d) => update(road.copyWith(forward: d))),
      direction(l.directionBackward, road.backward, road.from, (d) => update(road.copyWith(backward: d))),
      if (road.isOneWay) InfoBanner(icon: Icons.info_outline, text: l.oneWayInfo, color: Colors.blueGrey),
    ]);
  }
}

class _BayEditor extends StatelessWidget {
  final String label;
  final TurnBay? bay;
  final ValueChanged<TurnBay?> onChanged;
  const _BayEditor({required this.label, required this.bay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = bay;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: b != null,
        onChanged: (v) => onChanged(v ? const TurnBay() : null),
      ),
      if (b != null)
        Row(children: [
          Expanded(
            child: StepperField(
                label: l.lanes, value: b.lanes, min: 1, max: 3, onChanged: (v) => onChanged(b.copyWith(lanes: v))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumberField(
                label: l.storageLength,
                suffix: 'm',
                value: b.lengthM,
                min: 10,
                max: 500,
                onChanged: (v) => onChanged(b.copyWith(lengthM: v))),
          ),
        ]),
    ]);
  }
}

