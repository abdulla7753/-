import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../editor/editor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../model/network.dart';
import '../../model/results.dart';
import '../../services/simulation_controller.dart';
import '../format.dart';
import '../widgets/common.dart';

Color losColor(String? los) => switch (los) {
      'A' => const Color(0xFF2E7D32),
      'B' => const Color(0xFF689F38),
      'C' => const Color(0xFFAFB42B),
      'D' => const Color(0xFFFFA000),
      'E' => const Color(0xFFF4511E),
      'F' => const Color(0xFFC62828),
      _ => Colors.grey,
    };

class ResultsPanel extends StatelessWidget {
  final EditorController editor;
  final SimulationController sim;
  const ResultsPanel({super.key, required this.editor, required this.sim});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = sim.result;
    if (r == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.analytics_outlined, size: 56, color: theme.hintColor),
            const SizedBox(height: 8),
            Text(l.noResultsYet, textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    final lang = l.localeName.startsWith('ar') ? 'ar' : 'en';
    final net = editor.network;
    final stored = editor.variant.lastResult!;
    final highWarnings = r.warnings.where((w) => w.severity == 'high').length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (sim.resultStale)
        InfoBanner(icon: Icons.update, color: Colors.orange, text: l.resultsStale),
      InfoBanner(
        icon: r.reliabilityLevel == 'low' ? Icons.report_gmailerrorred : Icons.science_outlined,
        color: r.reliabilityLevel == 'low' ? theme.colorScheme.error : Colors.indigo,
        text: '${l.reliability}: ${r.reliabilityText(lang)}',
      ),
      Text(
        l.resultMeta(
          DateFormat.yMMMd(l.localeName).add_Hm().format(stored.completedAt),
          r.replications,
          fmtClock(r.durationS),
          fmtClock(r.warmupS),
        ),
        style: theme.textTheme.bodySmall,
      ),
      Text(r.engineLabel, style: theme.textTheme.bodySmall, textDirection: TextDirection.ltr),
      Text(r.demandSource == 'observed' ? l.demandWasObserved : l.demandWasAssumed, style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),

      // ------------------------------------------------------------ KPIs
      GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 116,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          MetricTile(label: l.kpiDelay, value: fmtNum(r.metric('avgDelayS').mean), unit: l.unitSecPerVeh, sub: _ci(l, r.metric('avgDelayS'))),
          MetricTile(
              label: l.kpiThroughput,
              value: fmtNum(r.metric('throughputVehPerHour').mean, decimals: 0),
              unit: l.vehPerHour,
              sub: _ci(l, r.metric('throughputVehPerHour'), decimals: 0)),
          MetricTile(label: l.kpiMaxQueue, value: fmtNum(r.metric('maxQueueM').mean), unit: 'm', sub: _ci(l, r.metric('maxQueueM'))),
          MetricTile(
              label: l.kpiWorstAvgQueue,
              value: fmtNum(r.metric('worstApproachAvgQueueM').mean),
              unit: 'm',
              sub: _ci(l, r.metric('worstApproachAvgQueueM'))),
          MetricTile(
              label: l.kpiTravelTime, value: fmtNum(r.metric('avgTravelTimeS').mean), unit: 's', sub: _ci(l, r.metric('avgTravelTimeS'))),
          MetricTile(label: l.kpiSpeed, value: fmtNum(r.metric('avgSpeedKmh').mean), unit: 'km/h', sub: _ci(l, r.metric('avgSpeedKmh'))),
          MetricTile(label: l.kpiStops, value: fmtNum(r.metric('avgStops').mean, decimals: 2), sub: _ci(l, r.metric('avgStops'), decimals: 2)),
          MetricTile(
              label: l.kpiCompleted,
              value: fmtNum(r.metric('vehiclesCompleted').mean, decimals: 0),
              sub: l.perReplication),
        ],
      ),
      const SizedBox(height: 16),

      // ------------------------------------------------------------ intersections
      if (r.nodes.isNotEmpty)
        PanelSection(title: l.intersections, children: [
          for (final n in r.nodes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _LosBadge(n.los),
              title: Text('${gateName(net, n.node)} · ${controlNameApi(l, n.control)}'),
              subtitle: Text(
                '${l.delay}: ${fmtStat(n.delay)} ${l.unitSecPerVeh}   ${l.kpiThroughput}: ${fmtNum(n.throughput.mean, decimals: 0)} ${l.vehPerHour}',
                textDirection: TextDirection.ltr,
                textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
              ),
            ),
          Text(l.losNote, style: theme.textTheme.bodySmall),
        ]),

      // ------------------------------------------------------------ approaches
      if (r.approaches.isNotEmpty)
        PanelSection(title: l.approaches, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              columns: [
                DataColumn(label: Text(l.approach)),
                DataColumn(label: Text(l.losShort)),
                DataColumn(label: Text('${l.delay} (s)'), numeric: true),
                DataColumn(label: Text('${l.queueAvg} (m)'), numeric: true),
                DataColumn(label: Text('${l.queueP95} (m)'), numeric: true),
                DataColumn(label: Text('${l.queueMax} (m)'), numeric: true),
                DataColumn(label: Text('${l.flow} (${l.vehPerHour})'), numeric: true),
              ],
              rows: [
                for (final a in r.approaches)
                  DataRow(cells: [
                    DataCell(Text(_approachName(net, a))),
                    DataCell(_LosBadge(a.los, small: true)),
                    DataCell(Text(fmtStat(a.delay))),
                    DataCell(Text(fmtNum(a.avgQueue.mean))),
                    DataCell(Text(fmtNum(a.p95Queue.mean))),
                    DataCell(Text(fmtNum(a.maxQueue.mean))),
                    DataCell(Text(fmtNum(a.throughput.mean, decimals: 0))),
                  ]),
              ],
            ),
          ),
        ]),

      // ------------------------------------------------------------ movements
      if (r.movements.isNotEmpty)
        PanelSection(title: l.movements, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              columns: [
                DataColumn(label: Text(l.fromTo)),
                DataColumn(label: Text(l.vehicles), numeric: true),
                DataColumn(label: Text('${l.delay} (s)'), numeric: true),
                DataColumn(label: Text('${l.kpiTravelTime} (s)'), numeric: true),
                DataColumn(label: Text(l.kpiStops), numeric: true),
              ],
              rows: [
                for (final m in r.movements)
                  DataRow(cells: [
                    DataCell(Text('${gateName(net, m.origin)} → ${gateName(net, m.destination)}')),
                    DataCell(Text(fmtNum(m.vehicles.mean, decimals: 0))),
                    DataCell(Text(fmtStat(m.delay))),
                    DataCell(Text(fmtNum(m.travelTime.mean))),
                    DataCell(Text(fmtNum(m.stops.mean, decimals: 2))),
                  ]),
              ],
            ),
          ),
        ]),

      // ------------------------------------------------------------ warnings & assumptions
      PanelSection(title: l.warningsCount(r.warnings.length, highWarnings), children: [
        for (final w in r.warnings)
          InfoBanner(
            icon: switch (w.severity) {
              'high' => Icons.error_outline,
              'medium' => Icons.warning_amber_outlined,
              _ => Icons.info_outline,
            },
            color: switch (w.severity) {
              'high' => theme.colorScheme.error,
              'medium' => Colors.orange,
              _ => Colors.blueGrey,
            },
            text: w.text(lang),
          ),
      ]),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(l.assumptions),
        children: [
          for (final a in r.assumptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• '),
                Expanded(child: Text(lang == 'ar' ? a.ar : a.en)),
              ]),
            ),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(l.definitions),
        children: [
          for (final e in r.definitions.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${e.key}: ${e.value}', textDirection: TextDirection.ltr, style: theme.textTheme.bodySmall),
            ),
          Text(l.definitionsLanguageNote, style: theme.textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.file_download_outlined),
        label: Text(l.exportCsv),
        onPressed: () async {
          final path = await editor.store.export(
            '${_safe(editor.project.name)}_${_safe(editor.variant.name)}_results.csv',
            resultsCsv(r, net),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.exportedTo(path))));
          }
        },
      ),
    ]);
  }

  String? _ci(AppLocalizations l, Stat s, {int decimals = 1}) {
    if (s.lo == null || s.hi == null) return s.n == 1 ? l.singleRun : null;
    return '${l.ci95} ${fmtNum(s.lo, decimals: decimals)} – ${fmtNum(s.hi, decimals: decimals)}';
  }

  static String _approachName(Network net, ApproachResult a) {
    final road = net.roads[a.road];
    final from = road == null ? null : (a.direction == 'forward' ? road.from : road.to);
    final label = from == null ? a.road : gateName(net, from);
    return '$label → ${a.node} (${a.lanesAtStopLine})';
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9؀-ۿ_-]+'), '_');
}

class _LosBadge extends StatelessWidget {
  final String? los;
  final bool small;
  const _LosBadge(this.los, {this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 26.0 : 36.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: losColor(los), borderRadius: BorderRadius.circular(6)),
      child: Text(los ?? '–', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: small ? 13 : 18)),
    );
  }
}

/// CSV with summary, approach and movement tables (UTF-8, comma separated).
String resultsCsv(SimulationResult r, Network net) {
  final b = StringBuffer();
  String q(Object? v) {
    final s = v == null ? '' : '$v';
    return s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String n(double? v) => v == null ? '' : v.toStringAsFixed(3);
  b.writeln('section,metric,mean,ci95_low,ci95_high,replications');
  for (final key in [
    'avgDelayS',
    'avgTimeLossS',
    'avgEntryDelayS',
    'avgTravelTimeS',
    'avgSpeedKmh',
    'avgStops',
    'throughputVehPerHour',
    'vehiclesCompleted',
    'maxQueueM',
    'worstApproachAvgQueueM',
    'worstApproachP95QueueM',
    'unfinishedShare',
  ]) {
    final s = r.metric(key);
    b.writeln('summary,$key,${n(s.mean)},${n(s.lo)},${n(s.hi)},${s.n}');
  }
  b.writeln();
  b.writeln('approach_node,road,direction,control,lanes_at_stop_line,los,delay_s,delay_ci_low,delay_ci_high,avg_queue_m,p95_queue_m,max_queue_m,throughput_veh_h');
  for (final a in r.approaches) {
    b.writeln([
      a.node,
      a.road,
      a.direction,
      a.control,
      a.lanesAtStopLine,
      a.los,
      n(a.delay.mean),
      n(a.delay.lo),
      n(a.delay.hi),
      n(a.avgQueue.mean),
      n(a.p95Queue.mean),
      n(a.maxQueue.mean),
      n(a.throughput.mean),
    ].map(q).join(','));
  }
  b.writeln();
  b.writeln('origin,destination,vehicles,delay_s,travel_time_s,stops');
  for (final m in r.movements) {
    b.writeln([m.origin, m.destination, n(m.vehicles.mean), n(m.delay.mean), n(m.travelTime.mean), n(m.stops.mean)].map(q).join(','));
  }
  b.writeln();
  b.writeln('warning_severity,warning');
  for (final w in r.warnings) {
    b.writeln('${w.severity},${q(w.en)}');
  }
  return b.toString();
}
