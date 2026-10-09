import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/app_localizations.dart';
import '../../model/results.dart';
import '../../services/simulation_controller.dart';
import '../canvas/viewport.dart';
import '../format.dart';
import 'playback_painter.dart';

/// Replays replication 1 exactly as SUMO computed it (positions and signal states).
class PlaybackView extends StatefulWidget {
  final SimulationController sim;
  final MapViewport vp;
  final VoidCallback onRun;
  const PlaybackView({super.key, required this.sim, required this.vp, required this.onRun});

  @override
  State<PlaybackView> createState() => _PlaybackViewState();
}

class _PlaybackViewState extends State<PlaybackView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration? _last;
  double time = 0;
  bool playing = false;
  double speed = 1;
  bool heatmap = false;
  VehicleColoring coloring = VehicleColoring.byClass;
  int? selected;
  bool follow = false;
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;

  static const speeds = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0];

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = _last == null ? 0.0 : (elapsed - _last!).inMicroseconds / 1e6;
    _last = elapsed;
    final tr = widget.sim.trajectory;
    if (!playing || tr == null) return;
    var t = time + dt * speed;
    if (t >= tr.lastTime) {
      t = tr.lastTime;
      playing = false;
    }
    setState(() => time = t);
    _followSelected();
  }

  void _followSelected() {
    final tr = widget.sim.trajectory;
    if (!follow || selected == null || tr == null) return;
    for (final v in vehiclesAt(tr, time)) {
      if (v.index == selected) {
        final size = context.size;
        if (size == null) return;
        final s = widget.vp.toScreen(v.front);
        widget.vp.panBy(Offset(size.width / 2, size.height / 2) - s);
        return;
      }
    }
  }

  void _tap(TapUpDetails d) {
    final tr = widget.sim.trajectory;
    if (tr == null) return;
    final p = widget.vp.toWorld(d.localPosition);
    int? best;
    var bestD = widget.vp.metres(24);
    for (final v in vehiclesAt(tr, time)) {
      final info = tr.vehicles[v.index];
      final c = v.front - v.heading * (info.length / 2);
      final dd = c.distanceTo(p);
      if (dd < bestD) {
        bestD = dd;
        best = v.index;
      }
    }
    setState(() {
      selected = best;
      if (best == null) follow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sim = widget.sim;
    final net = sim.simNetwork;
    final tr = sim.trajectory;
    if (net == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_circle_outline, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 8),
          Text(sim.result == null ? l.playbackNeedsRun : l.playbackNotRecorded),
          const SizedBox(height: 8),
          FilledButton(onPressed: widget.onRun, child: Text(l.goToSimulation)),
        ]),
      );
    }
    if (tr != null && (time < tr.firstTime || time > tr.lastTime)) time = tr.firstTime;
    final laneRatio = <String, double?>{for (final s in sim.result?.lanes ?? const <LaneStat>[]) s.lane: s.speedRatio};

    return Stack(children: [
      Positioned.fill(
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) widget.vp.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 400));
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _tap,
            onScaleStart: (d) {
              _lastFocal = d.localFocalPoint;
              _lastScale = 1;
            },
            onScaleUpdate: (d) {
              widget.vp.panBy(d.localFocalPoint - _lastFocal);
              if (d.pointerCount >= 2 && _lastScale > 0) widget.vp.zoomAt(d.localFocalPoint, d.scale / _lastScale);
              _lastFocal = d.localFocalPoint;
              _lastScale = d.scale;
              if (follow) setState(() => follow = false);
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: PlaybackPainter(
                net: net,
                traj: tr,
                time: time,
                vp: widget.vp,
                laneSpeedRatio: laneRatio,
                heatmap: heatmap,
                coloring: coloring,
                selectedVehicle: selected,
              ),
            ),
          ),
        ),
      ),
      Positioned(top: 8, left: 8, right: 8, child: Center(child: _info(context, l))),
      if (heatmap) Positioned(top: 64, right: 12, child: _HeatLegend(l: l)),
      if (selected != null && tr != null) Positioned(top: 64, left: 12, child: _vehicleCard(context, l)),
      Positioned(left: 12, right: 12, bottom: 12, child: _controls(context, l)),
    ]);
  }

  Widget _info(BuildContext context, AppLocalizations l) {
    final r = widget.sim.result;
    final tr = widget.sim.trajectory;
    final text = tr == null
        ? l.playbackNoTrajectory
        : l.playbackInfo(r?.replications ?? 1, fmtClock(tr.firstTime), fmtClock(tr.lastTime));
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_outlined, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          if (widget.sim.resultStale) ...[
            const SizedBox(width: 8),
            Icon(Icons.update, size: 16, color: Colors.orange.shade800),
            const SizedBox(width: 4),
            Text(l.staleShort, style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, AppLocalizations l) {
    final tr = widget.sim.trajectory!;
    final info = tr.vehicles[selected!];
    final state = vehiclesAt(tr, time).where((v) => v.index == selected).firstOrNull;
    final cls = switch (info.cls) {
      'truck' => l.trucks,
      'bus' => l.buses,
      _ => l.cars,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$cls · ${info.id}', style: const TextStyle(fontWeight: FontWeight.w700), textDirection: TextDirection.ltr),
          Text(state == null ? l.vehicleLeft : l.vehicleSpeed((state.speed * 3.6).toStringAsFixed(1))),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(value: follow, onChanged: (v) => setState(() => follow = v ?? false)),
            Text(l.followVehicle),
          ]),
        ]),
      ),
    );
  }

  Widget _controls(BuildContext context, AppLocalizations l) {
    final tr = widget.sim.trajectory;
    final has = tr != null && tr.frameCount > 1;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            key: const Key('playPause'),
            tooltip: playing ? l.pause : l.play,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: has
                ? () => setState(() {
                      if (!playing && time >= tr.lastTime) time = tr.firstTime;
                      playing = !playing;
                    })
                : null,
          ),
          IconButton(
            tooltip: l.restart,
            icon: const Icon(Icons.replay),
            onPressed: has ? () => setState(() => time = tr.firstTime) : null,
          ),
          IconButton(
            tooltip: l.stepBack,
            icon: const Icon(Icons.skip_previous),
            onPressed: has ? () => setState(() => time = math.max(tr.firstTime, time - tr.periodS)) : null,
          ),
          IconButton(
            tooltip: l.stepForward,
            icon: const Icon(Icons.skip_next),
            onPressed: has ? () => setState(() => time = math.min(tr.lastTime, time + tr.periodS)) : null,
          ),
          SizedBox(width: 56, child: Text(fmtClock(time), textDirection: TextDirection.ltr)),
          Expanded(
            child: Slider(
              value: has ? time.clamp(tr.firstTime, tr.lastTime) : 0,
              min: has ? tr.firstTime : 0,
              max: has ? tr.lastTime : 1,
              onChanged: has ? (v) => setState(() => time = v) : null,
            ),
          ),
          PopupMenuButton<double>(
            tooltip: l.playbackSpeed,
            initialValue: speed,
            onSelected: (v) => setState(() => speed = v),
            itemBuilder: (_) => [for (final s in speeds) PopupMenuItem(value: s, child: Text('×$s'))],
            child: Padding(padding: const EdgeInsets.all(8), child: Text('×$speed', textDirection: TextDirection.ltr)),
          ),
          IconButton(
            tooltip: l.heatmap,
            isSelected: heatmap,
            icon: const Icon(Icons.thermostat_outlined),
            selectedIcon: const Icon(Icons.thermostat),
            onPressed: () => setState(() => heatmap = !heatmap),
          ),
          IconButton(
            tooltip: l.colorBySpeed,
            isSelected: coloring == VehicleColoring.bySpeed,
            icon: const Icon(Icons.palette_outlined),
            selectedIcon: const Icon(Icons.palette),
            onPressed: () => setState(() => coloring =
                coloring == VehicleColoring.byClass ? VehicleColoring.bySpeed : VehicleColoring.byClass),
          ),
        ]),
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  final AppLocalizations l;
  const _HeatLegend({required this.l});

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14, color: c),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(l.heatmapTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          row(speedRatioColor(0.9), '≥ 85%'),
          row(speedRatioColor(0.7), '65–85%'),
          row(speedRatioColor(0.5), '45–65%'),
          row(speedRatioColor(0.3), '25–45%'),
          row(speedRatioColor(0.1), '< 25%'),
          row(speedRatioColor(null), l.noData),
        ]),
      ),
    );
  }
}
