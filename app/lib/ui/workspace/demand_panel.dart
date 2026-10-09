import 'package:flutter/material.dart';

import '../../editor/editor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../model/request_builder.dart';
import '../../model/scenario.dart';
import '../format.dart';
import '../widgets/common.dart';

class DemandPanel extends StatelessWidget {
  final EditorController editor;
  const DemandPanel({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final net = editor.network;
    final demand = editor.variant.demand;
    final gs = gates(net);
    final entries = gs.where((g) => g.lanesIn > 0).toList();
    final exits = gs.where((g) => g.lanesOut > 0).toList();
    final theme = Theme.of(context);

    return ListView(padding: const EdgeInsets.all(16), children: [
      PanelSection(title: l.demandSource, children: [
        SegmentedButton<DemandSource>(
          segments: [
            ButtonSegment(value: DemandSource.observed, icon: const Icon(Icons.fact_check_outlined), label: Text(l.sourceObserved)),
            ButtonSegment(value: DemandSource.assumed, icon: const Icon(Icons.science_outlined), label: Text(l.sourceAssumed)),
          ],
          selected: {demand.source},
          onSelectionChanged: (s) => editor.updateDemand(demand.copyWith(source: s.first)),
        ),
        const SizedBox(height: 6),
        Text(demand.source == DemandSource.observed ? l.sourceObservedHelp : l.sourceAssumedHelp,
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('note_${editor.variant.id}'),
          initialValue: demand.note,
          maxLines: 2,
          decoration: InputDecoration(labelText: l.sourceNote, border: const OutlineInputBorder(), hintText: l.sourceNoteHint),
          onFieldSubmitted: (v) => editor.updateDemand(demand.copyWith(note: v.trim())),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.poissonArrivals),
          subtitle: Text(l.poissonArrivalsHelp),
          value: demand.poissonArrivals,
          onChanged: (v) => editor.updateDemand(demand.copyWith(poissonArrivals: v)),
        ),
      ]),
      if (entries.isEmpty)
        InfoBanner(icon: Icons.info_outline, text: l.noEntriesYet, color: Colors.blueGrey)
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.totalDemand(demand.totalFlow.toStringAsFixed(0)), style: theme.textTheme.titleSmall),
        ),
      for (final g in entries)
        _OriginCard(
          key: ValueKey('origin_${g.node.id}'),
          editor: editor,
          originId: g.node.id,
          destinations: [for (final e in exits) if (e.node.id != g.node.id) e.node.id],
        ),
    ]);
  }
}

class _OriginCard extends StatelessWidget {
  final EditorController editor;
  final String originId;
  final List<String> destinations;
  const _OriginCard({super.key, required this.editor, required this.originId, required this.destinations});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final net = editor.network;
    final demand = editor.variant.demand;
    final o = demand.origins[originId] ?? const OriginDemand();
    final theme = Theme.of(context);
    void set(OriginDemand next) => editor.updateDemand(demand.copyWith(origins: {...demand.origins, originId: next}));

    final shareTotal = destinations.fold(0.0, (a, d) => a + (o.shares[d] ?? 0));
    final shareOk = o.flowVehPerHour == 0 || (shareTotal - 1).abs() < 0.001;
    final mixOk = (o.mix.total - 1).abs() < 0.001;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.login, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(l.entryFrom(gateName(net, originId)), style: theme.textTheme.titleSmall)),
          ]),
          NumberField(
            key: ValueKey('flow_$originId'),
            label: l.flowVehPerHour,
            suffix: l.vehPerHour,
            value: o.flowVehPerHour,
            min: 0,
            max: 12000,
            onChanged: (v) => set(o.copyWith(flowVehPerHour: v)),
          ),
          const SizedBox(height: 4),
          Text(l.vehicleMix, style: theme.textTheme.labelLarge),
          Row(children: [
            Expanded(
              child: NumberField(
                key: ValueKey('car_$originId'),
                label: l.cars,
                suffix: '%',
                decimals: 1,
                value: o.mix.car * 100,
                min: 0,
                max: 100,
                onChanged: (v) => set(o.copyWith(mix: o.mix.copyWith(car: v / 100))),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: NumberField(
                key: ValueKey('truck_$originId'),
                label: l.trucks,
                suffix: '%',
                decimals: 1,
                value: o.mix.truck * 100,
                min: 0,
                max: 100,
                onChanged: (v) {
                  final truck = v / 100;
                  set(o.copyWith(mix: o.mix.copyWith(truck: truck, car: (1 - truck - o.mix.bus).clamp(0.0, 1.0))));
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: NumberField(
                key: ValueKey('bus_$originId'),
                label: l.buses,
                suffix: '%',
                decimals: 1,
                value: o.mix.bus * 100,
                min: 0,
                max: 100,
                onChanged: (v) {
                  final bus = v / 100;
                  set(o.copyWith(mix: o.mix.copyWith(bus: bus, car: (1 - bus - o.mix.truck).clamp(0.0, 1.0))));
                },
              ),
            ),
          ]),
          if (!mixOk)
            Text(l.mixMustBe100((o.mix.total * 100).toStringAsFixed(1)), style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(l.destinationsTitle, style: theme.textTheme.labelLarge)),
            TextButton(
              onPressed: destinations.isEmpty
                  ? null
                  : () => set(o.copyWith(shares: {for (final d in destinations) d: 1 / destinations.length})),
              child: Text(l.equalSplit),
            ),
            TextButton(
              onPressed: shareTotal <= 0
                  ? null
                  : () => set(o.copyWith(shares: {for (final d in destinations) d: (o.shares[d] ?? 0) / shareTotal})),
              child: Text(l.normalize),
            ),
          ]),
          for (final d in destinations)
            Row(children: [
              SizedBox(
                width: 76,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(turnName(l, turnKind(net, originId, d)), style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(gateName(net, d), overflow: TextOverflow.ellipsis)),
              SizedBox(
                width: 110,
                child: NumberField(
                  key: ValueKey('share_${originId}_$d'),
                  label: '',
                  suffix: '%',
                  decimals: 1,
                  value: (o.shares[d] ?? 0) * 100,
                  min: 0,
                  max: 100,
                  onChanged: (v) => set(o.copyWith(shares: {...o.shares, d: v / 100})),
                ),
              ),
            ]),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              l.shareTotal((shareTotal * 100).toStringAsFixed(1)),
              style: TextStyle(color: shareOk ? theme.hintColor : theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}
