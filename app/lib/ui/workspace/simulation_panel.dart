import 'package:flutter/material.dart';

import '../../editor/editor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../model/network.dart';
import '../../model/request_builder.dart';
import '../../services/app_settings.dart';
import '../../services/simulation_controller.dart';
import '../format.dart';
import '../widgets/common.dart';

class SimulationPanel extends StatelessWidget {
  final EditorController editor;
  final SimulationController sim;
  final AppSettings settings;
  final VoidCallback onShowResults;
  const SimulationPanel({super.key, required this.editor, required this.sim, required this.settings, required this.onShowResults});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = editor.variant;
    final run = v.run;
    final sig = v.signals;
    final drv = v.drivers;
    final issues = validate(v);
    final blocking = issues.where((i) => i.blocking).toList();
    final hasSignals = v.network.nodes.values.any((n) => n.control == NodeControl.trafficLight);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ------------------------------------------------------------ run / status
      PanelSection(title: l.runSimulation, children: [
        Text(l.serverLine(settings.serverUrl), style: theme.textTheme.bodySmall, textDirection: TextDirection.ltr),
        const SizedBox(height: 8),
        for (final i in issues)
          InfoBanner(
            icon: i.blocking ? Icons.error_outline : Icons.warning_amber_outlined,
            color: i.blocking ? theme.colorScheme.error : Colors.orange,
            text: issueText(l, i),
          ),
        if (sim.busy) ...[
          LinearProgressIndicator(value: sim.phase == SimPhase.running ? sim.progress : null),
          const SizedBox(height: 6),
          Text(switch (sim.phase) {
            SimPhase.submitting => l.phaseSubmitting,
            SimPhase.running => l.phaseRunning((sim.progress * 100).toStringAsFixed(0), sim.message),
            SimPhase.fetching => l.phaseFetching,
            _ => '',
          }),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: sim.cancel, icon: const Icon(Icons.stop), label: Text(l.cancel)),
        ] else
          FilledButton.icon(
            key: const Key('runSimulation'),
            onPressed: blocking.isEmpty ? sim.run : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.runButton(run.replications)),
          ),
        if (sim.phase == SimPhase.failed && sim.errors.isNotEmpty)
          InfoBanner(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            text: '${l.simulationFailed}\n${sim.errors.join('\n')}',
          ),
        if (sim.phase == SimPhase.done)
          InfoBanner(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            text: l.simulationDone,
            action: TextButton(onPressed: onShowResults, child: Text(l.viewResults)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('validateOnServer'),
          onPressed: sim.validating || sim.busy ? null : sim.validateOnServer,
          icon: const Icon(Icons.rule),
          label: Text(l.validateDesign),
        ),
        if (sim.validating) const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator()),
        if (sim.buildErrors != null && sim.buildErrors!.isNotEmpty)
          InfoBanner(icon: Icons.error_outline, color: theme.colorScheme.error, text: sim.buildErrors!.join('\n')),
        if (sim.buildErrors != null && sim.buildErrors!.isEmpty)
          InfoBanner(
            icon: Icons.verified_outlined,
            color: Colors.green,
            text: sim.buildWarnings!.isEmpty ? l.validationOk : '${l.validationOkWithWarnings}\n${sim.buildWarnings!.join('\n')}',
          ),
      ]),

      // ------------------------------------------------------------ run settings
      PanelSection(title: l.runSettings, children: [
        Row(children: [
          Expanded(
            child: NumberField(
              label: l.duration,
              suffix: 'min',
              value: run.durationS / 60,
              min: 1,
              max: 240,
              onChanged: (m) => editor.updateRun(run.copyWith(durationS: m * 60)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumberField(
              label: l.warmup,
              suffix: 'min',
              value: run.warmupS / 60,
              min: 0,
              max: 60,
              onChanged: (m) => editor.updateRun(run.copyWith(warmupS: m * 60)),
            ),
          ),
        ]),
        Text(l.warmupHelp, style: theme.textTheme.bodySmall),
        Row(children: [
          Expanded(
            child: NumberField(
              label: l.replications,
              value: run.replications.toDouble(),
              min: 1,
              max: 30,
              onChanged: (n) => editor.updateRun(run.copyWith(replications: n.round())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumberField(
              label: l.baseSeed,
              value: run.baseSeed.toDouble(),
              min: 0,
              max: 1e9,
              onChanged: (n) => editor.updateRun(run.copyWith(baseSeed: n.round())),
            ),
          ),
        ]),
        Text(l.replicationsHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<double>(
          key: ValueKey('step_${run.stepLengthS}'),
          initialValue: run.stepLengthS,
          decoration: InputDecoration(labelText: l.timeStep, border: const OutlineInputBorder()),
          items: [for (final s in [0.1, 0.2, 0.25, 0.5, 1.0]) DropdownMenuItem(value: s, child: Text('$s s'))],
          onChanged: (s) => editor.updateRun(run.copyWith(stepLengthS: s)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.recordPlayback),
          subtitle: Text(l.recordPlaybackHelp(fmtNum(run.trajectoryMaxS / 60, decimals: 0))),
          value: run.trajectory,
          onChanged: (b) => editor.updateRun(run.copyWith(trajectory: b)),
        ),
        if (run.trajectory)
          NumberField(
            label: l.playbackWindow,
            suffix: 'min',
            value: run.trajectoryMaxS / 60,
            min: 1,
            max: 60,
            onChanged: (m) => editor.updateRun(run.copyWith(trajectoryMaxS: m * 60)),
          ),
      ]),

      // ------------------------------------------------------------ drivers
      PanelSection(title: l.driverBehaviour, children: [
        DropdownButtonFormField<String>(
          key: ValueKey('cf_${drv.carFollowModel}'),
          initialValue: drv.carFollowModel,
          decoration: InputDecoration(labelText: l.carFollowingModel, border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 'EIDM', child: Text(l.modelEidm)),
            DropdownMenuItem(value: 'IDM', child: Text(l.modelIdm)),
            DropdownMenuItem(value: 'Krauss', child: Text(l.modelKrauss)),
          ],
          onChanged: (m) => editor.updateDrivers(drv.copyWith(carFollowModel: m)),
        ),
        const SizedBox(height: 4),
        Text(l.carFollowingHelp, style: theme.textTheme.bodySmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.driverHeterogeneity),
          subtitle: Text(l.driverHeterogeneityHelp),
          value: drv.heterogeneity,
          onChanged: (b) => editor.updateDrivers(drv.copyWith(heterogeneity: b)),
        ),
        if (drv.heterogeneity)
          Row(children: [
            Expanded(
              child: NumberField(
                label: l.reactionMin,
                suffix: 's',
                decimals: 1,
                value: drv.reactionTimeMinS,
                min: 0.1,
                max: 3,
                onChanged: (x) => editor.updateDrivers(drv.copyWith(reactionTimeMinS: x)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(
                label: l.reactionMax,
                suffix: 's',
                decimals: 1,
                value: drv.reactionTimeMaxS,
                min: 0.1,
                max: 3,
                onChanged: (x) => editor.updateDrivers(drv.copyWith(reactionTimeMaxS: x)),
              ),
            ),
          ]),
        NumberField(
          label: l.gapAcceptance,
          decimals: 2,
          value: drv.impatience,
          min: 0,
          max: 1,
          helper: l.gapAcceptanceHelp,
          onChanged: (x) => editor.updateDrivers(drv.copyWith(impatience: x)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.strictStop),
          subtitle: Text(l.strictStopHelp),
          value: drv.stopSignFullStop,
          onChanged: (b) => editor.updateDrivers(drv.copyWith(stopSignFullStop: b)),
        ),
      ]),

      // ------------------------------------------------------------ signals
      if (hasSignals)
        PanelSection(title: l.signalTiming, children: [
          Text(l.signalTimingHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          NumberField(
            label: l.cycleTime,
            suffix: 's',
            value: sig.cycleTimeS.toDouble(),
            min: 30,
            max: 240,
            onChanged: (x) => editor.updateSignals(sig.copyWith(cycleTimeS: x.round())),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.autoYellow),
            value: sig.yellowTimeS == null,
            onChanged: (b) => editor.updateSignals(b ? sig.copyWith(autoYellow: true) : sig.copyWith(yellowTimeS: 3)),
          ),
          if (sig.yellowTimeS != null)
            NumberField(
              label: l.yellowTime,
              suffix: 's',
              value: sig.yellowTimeS!.toDouble(),
              min: 2,
              max: 8,
              onChanged: (x) => editor.updateSignals(sig.copyWith(yellowTimeS: x.round())),
            ),
          NumberField(
            label: l.allRedTime,
            suffix: 's',
            value: sig.allRedTimeS.toDouble(),
            min: 0,
            max: 6,
            onChanged: (x) => editor.updateSignals(sig.copyWith(allRedTimeS: x.round())),
          ),
          NumberField(
            label: l.leftGreen,
            suffix: 's',
            value: sig.leftTurnGreenS.toDouble(),
            min: 0,
            max: 60,
            helper: l.leftGreenHelp,
            onChanged: (x) => editor.updateSignals(sig.copyWith(leftTurnGreenS: x.round())),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('layout_${sig.layout}'),
            initialValue: sig.layout,
            decoration: InputDecoration(labelText: l.phaseLayout, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'opposites', child: Text(l.layoutOpposites)),
              DropdownMenuItem(value: 'incoming', child: Text(l.layoutIncoming)),
            ],
            onChanged: (s) => editor.updateSignals(sig.copyWith(layout: s)),
          ),
        ]),
    ]);
  }
}
