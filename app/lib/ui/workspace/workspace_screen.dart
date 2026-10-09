import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../editor/editor_controller.dart';
import '../../editor/network_ops.dart';
import '../../l10n/app_localizations.dart';
import '../../model/project.dart';
import '../../model/request_builder.dart';
import '../../services/api_client.dart';
import '../../services/app_settings.dart';
import '../../services/project_store.dart';
import '../../services/simulation_controller.dart';
import '../canvas/editor_canvas.dart';
import '../canvas/viewport.dart';
import '../format.dart';
import '../playback/playback_view.dart';
import '../settings_dialog.dart';
import 'demand_panel.dart';
import 'properties_panel.dart';
import 'results_panel.dart';
import 'simulation_panel.dart';

enum WorkspaceMode { design, simulation }

class WorkspaceScreen extends StatefulWidget {
  final ProjectStore store;
  final AppSettings settings;
  final Project project;

  /// Overrides how the simulation client is created (tests inject a fake server).
  final SimulationApi Function(String url, String token)? apiFactory;
  const WorkspaceScreen({super.key, required this.store, required this.settings, required this.project, this.apiFactory});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> with SingleTickerProviderStateMixin {
  late final EditorController editor = EditorController(widget.store, widget.project);
  late final SimulationController sim = SimulationController(editor, widget.settings, apiFactory: widget.apiFactory);
  final MapViewport vp = MapViewport();
  late final TabController tabs = TabController(length: 4, vsync: this);
  WorkspaceMode mode = WorkspaceMode.design;
  bool panelOpen = true;
  bool _fitted = false;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    sim.ensurePlaybackLoaded();
    editor.addListener(_onEditorChange);
  }

  void _onEditorChange() {
    // Opening the properties tab when something gets selected keeps the workflow fluid.
    if (editor.selection != null && tabs.index != 0 && mode == WorkspaceMode.design && editor.tool == EditorTool.select) {
      tabs.animateTo(0);
    }
  }

  @override
  void dispose() {
    editor.removeListener(_onEditorChange);
    editor.dispose();
    sim.dispose();
    tabs.dispose();
    super.dispose();
  }

  void _fit() {
    final b = editor.network.bounds;
    if (b == null || _canvasSize == Size.zero) {
      vp.set(2, Offset(_canvasSize.width / 2, _canvasSize.height / 2));
      return;
    }
    vp.fit(b.min, b.max, _canvasSize, padding: 80);
  }

  Map<String, String> _gateLabels() =>
      {for (final g in gates(editor.network)) g.node.id: gateName(editor.network, g.node.id)};

  Future<void> _renameDialog(String title, String initial, void Function(String) apply) async {
    final ctrl = TextEditingController(text: initial);
    final l = AppLocalizations.of(context);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) apply(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([editor, sim]),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            _topBar(context, l),
            const Divider(height: 1),
            Expanded(
              child: Row(children: [
                if (mode == WorkspaceMode.design) _toolRail(context, l),
                Expanded(child: _canvasArea(context, l)),
                if (panelOpen) const VerticalDivider(width: 1),
                if (panelOpen) SizedBox(width: _panelWidth(context), child: _sidePanel(context, l)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  double _panelWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 1300 ? 420 : (w >= 1000 ? 370 : 320);
  }

  // ---------------------------------------------------------------- top bar
  Widget _topBar(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final saveIcon = switch (editor.saveState) {
      SaveState.saved => Icon(Icons.cloud_done_outlined, color: theme.colorScheme.primary),
      SaveState.pending || SaveState.saving => const Icon(Icons.sync),
      SaveState.error => Icon(Icons.error_outline, color: theme.colorScheme.error),
    };
    final saveText = switch (editor.saveState) {
      SaveState.saved => l.saved,
      SaveState.pending || SaveState.saving => l.saving,
      SaveState.error => l.saveFailed,
    };
    return SizedBox(
      height: 56,
      child: Row(children: [
        IconButton(
          tooltip: l.projects,
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Flexible(
          child: InkWell(
            onTap: () => _renameDialog(l.renameProject, editor.project.name, editor.renameProject),
            child: Text(editor.project.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 12),
        _variantSelector(context, l),
        const SizedBox(width: 12),
        SegmentedButton<WorkspaceMode>(
          segments: [
            ButtonSegment(value: WorkspaceMode.design, icon: const Icon(Icons.draw_outlined), label: Text(l.modeDesign)),
            ButtonSegment(
                value: WorkspaceMode.simulation, icon: const Icon(Icons.play_circle_outline), label: Text(l.modeSimulation)),
          ],
          selected: {mode},
          onSelectionChanged: (s) {
            setState(() => mode = s.first);
            if (mode == WorkspaceMode.simulation) {
              sim.ensurePlaybackLoaded();
              tabs.animateTo(sim.result != null ? 3 : 2);
            }
          },
        ),
        const Spacer(),
        if (mode == WorkspaceMode.design) ...[
          IconButton(tooltip: l.undo, icon: const Icon(Icons.undo), onPressed: editor.canUndo ? editor.undo : null),
          IconButton(tooltip: l.redo, icon: const Icon(Icons.redo), onPressed: editor.canRedo ? editor.redo : null),
        ],
        IconButton(tooltip: l.fitToView, icon: const Icon(Icons.fit_screen_outlined), onPressed: _fit),
        Tooltip(message: saveText, child: Padding(padding: const EdgeInsets.all(8), child: saveIcon)),
        IconButton(
          tooltip: l.otherLanguage,
          icon: const Icon(Icons.translate),
          onPressed: widget.settings.toggleLocale,
        ),
        IconButton(
          tooltip: l.serverSettings,
          icon: const Icon(Icons.dns_outlined),
          onPressed: () => showServerSettings(context, widget.settings),
        ),
        IconButton(
          tooltip: panelOpen ? l.hidePanel : l.showPanel,
          icon: Icon(panelOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined),
          onPressed: () => setState(() => panelOpen = !panelOpen),
        ),
      ]),
    );
  }

  Widget _variantSelector(BuildContext context, AppLocalizations l) {
    final p = editor.project;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.layers_outlined, size: 20),
      const SizedBox(width: 4),
      DropdownButton<String>(
        value: p.activeVariantId,
        underline: const SizedBox.shrink(),
        items: [for (final v in p.variants) DropdownMenuItem(value: v.id, child: Text(v.name))],
        onChanged: (id) {
          if (id == null) return;
          editor.switchVariant(id);
          sim.ensurePlaybackLoaded();
        },
      ),
      PopupMenuButton<String>(
        tooltip: l.variantActions,
        icon: const Icon(Icons.more_vert),
        onSelected: (a) async {
          switch (a) {
            case 'dup':
              await _renameDialog(l.duplicateVariant, l.variantCopyName(editor.variant.name), (name) {
                editor.duplicateVariant(name);
                sim.ensurePlaybackLoaded();
              });
            case 'rename':
              await _renameDialog(l.renameVariant, editor.variant.name, editor.renameVariant);
            case 'delete':
              if (!editor.deleteActiveVariant() && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cannotDeleteLastVariant)));
              }
              sim.ensurePlaybackLoaded();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'dup', child: Text(l.duplicateVariant)),
          PopupMenuItem(value: 'rename', child: Text(l.renameVariant)),
          PopupMenuItem(value: 'delete', child: Text(l.deleteVariant)),
        ],
      ),
    ]);
  }

  // ---------------------------------------------------------------- tool rail
  Widget _toolRail(BuildContext context, AppLocalizations l) {
    Widget tool(EditorTool t, IconData icon, String label) {
      final selected = editor.tool == t;
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: label,
          child: Material(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: Key('tool_${t.name}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => editor.setTool(t),
              child: SizedBox(
                width: 64,
                height: 58,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: selected ? scheme.onPrimaryContainer : null),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 8),
          tool(EditorTool.select, Icons.near_me_outlined, l.toolSelect),
          tool(EditorTool.road, Icons.timeline, l.toolRoad),
          tool(EditorTool.curve, Icons.gesture, l.toolCurve),
          tool(EditorTool.junction, Icons.add_road, l.toolJunction),
          tool(EditorTool.measure, Icons.straighten, l.toolMeasure),
          const Divider(indent: 12, endIndent: 12),
          IconButton(
            key: const Key('deleteSelection'),
            tooltip: l.deleteSelection,
            icon: const Icon(Icons.delete_outline),
            onPressed: editor.selection == null ? null : editor.deleteSelection,
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- canvas
  Widget _canvasArea(BuildContext context, AppLocalizations l) {
    return LayoutBuilder(builder: (context, constraints) {
      _canvasSize = constraints.biggest;
      if (!_fitted && _canvasSize.width > 0) {
        _fitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      }
      if (mode == WorkspaceMode.simulation) {
        return PlaybackView(sim: sim, vp: vp, onRun: () => tabs.animateTo(2));
      }
      return Stack(children: [
        Positioned.fill(child: EditorCanvas(ctrl: editor, vp: vp, gateLabels: _gateLabels())),
        Positioned(top: 8, left: 8, right: 8, child: Center(child: _toolOptions(context, l))),
        Positioned(bottom: 8, left: 8, child: _ScaleBar(vp: vp)),
      ]);
    });
  }

  Widget _toolOptions(BuildContext context, AppLocalizations l) {
    final d = editor.roadDefaults;
    final children = <Widget>[];
    Widget chip(String label, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FilterChip(label: Text(label), selected: value, onSelected: onChanged),
        );
    Widget stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 18),
                onPressed: value > min ? () => onChanged(value - 1) : null),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18),
                onPressed: value < max ? () => onChanged(value + 1) : null),
          ],
        );
    switch (editor.tool) {
      case EditorTool.road:
      case EditorTool.curve:
        children.addAll([
          stepper(l.lanesForwardShort, d.lanesForward, 0, 6,
              (v) => editor.setOptions(defaults: d.copyWith(lanesForward: v == 0 && d.lanesBackward == 0 ? 1 : v))),
          stepper(l.lanesBackwardShort, d.lanesBackward, 0, 6,
              (v) => editor.setOptions(defaults: d.copyWith(lanesBackward: v == 0 && d.lanesForward == 0 ? 1 : v))),
          PopupMenuButton<double>(
            tooltip: l.speedLimit,
            initialValue: d.speedLimitKmh,
            onSelected: (v) => editor.setOptions(defaults: d.copyWith(speedLimitKmh: v)),
            itemBuilder: (_) => [for (final s in [30.0, 40.0, 50.0, 60.0, 80.0, 100.0, 120.0]) PopupMenuItem(value: s, child: Text('${s.toStringAsFixed(0)} km/h', textDirection: TextDirection.ltr))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.speed, size: 18),
                const SizedBox(width: 4),
                Text('${d.speedLimitKmh.toStringAsFixed(0)} km/h', textDirection: TextDirection.ltr),
              ]),
            ),
          ),
          chip(l.optAutoJunctions, editor.autoJunctions, (v) => editor.setOptions(junctions: v)),
          chip(l.optGridSnap, editor.gridSnap, (v) => editor.setOptions(grid: v)),
          if (editor.tool == EditorTool.road) chip(l.optAngleSnap, editor.angleSnap, (v) => editor.setOptions(angle: v)),
          chip(l.optPenOnly, editor.penOnlyDrawing, (v) => editor.setOptions(penOnly: v)),
        ]);
      case EditorTool.junction:
        children.addAll([
          for (final (t, label) in [
            (JunctionTemplate.fourWay, l.templateFourWaySignal),
            (JunctionTemplate.tJunction, l.templateTStop),
            (JunctionTemplate.roundabout, l.templateRoundabout),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(label),
                selected: editor.template == t,
                onSelected: (_) => editor.setOptions(junctionTemplate: t),
              ),
            ),
          PopupMenuButton<double>(
            tooltip: l.armLength,
            onSelected: (v) => editor.setOptions(armM: v),
            itemBuilder: (_) => [for (final s in [100.0, 150.0, 200.0, 300.0, 400.0]) PopupMenuItem(value: s, child: Text('${s.toStringAsFixed(0)} m', textDirection: TextDirection.ltr))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${l.armLength}: \u2066${editor.templateArmM.toStringAsFixed(0)} m\u2069'),
            ),
          ),
          Text(l.hintTapToPlace),
        ]);
      case EditorTool.measure:
        final pts = editor.measurePoints;
        final len = polylineLength(pts);
        final bearing = pts.length >= 2 ? bearingDeg(pts[pts.length - 2], pts.last) : null;
        double? angle;
        if (pts.length >= 3) {
          final a = pts[pts.length - 3] - pts[pts.length - 2], b = pts.last - pts[pts.length - 2];
          angle = radToDeg(wrapAngle(b.angle - a.angle)).abs();
        }
        children.addAll([
          Text(l.measureLength(len.toStringAsFixed(1))),
          if (bearing != null) Padding(padding: const EdgeInsets.only(left: 12), child: Text(l.measureBearing(bearing.toStringAsFixed(1)))),
          if (angle != null) Padding(padding: const EdgeInsets.only(left: 12), child: Text(l.measureAngle(angle.toStringAsFixed(1)))),
          if (pts.length >= 3)
            Padding(padding: const EdgeInsets.only(left: 12), child: Text(l.measureArea(polygonArea(pts).toStringAsFixed(0)))),
          const SizedBox(width: 8),
          if (pts.isEmpty) Text(l.hintMeasure),
          if (pts.isNotEmpty) TextButton.icon(onPressed: editor.clearMeasure, icon: const Icon(Icons.clear), label: Text(l.clear)),
        ]);
      case EditorTool.select:
        children.add(Text(l.hintSelect));
    }
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: children)),
      ),
    );
  }

  // ---------------------------------------------------------------- side panel
  Widget _sidePanel(BuildContext context, AppLocalizations l) {
    return Column(children: [
      TabBar(
        controller: tabs,
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(icon: const Icon(Icons.tune, size: 20), text: l.tabProperties),
          Tab(icon: const Icon(Icons.directions_car_outlined, size: 20), text: l.tabDemand),
          Tab(key: const Key('tabSimulation'), icon: const Icon(Icons.play_arrow_outlined, size: 20), text: l.tabSimulation),
          Tab(key: const Key('tabResults'), icon: const Icon(Icons.analytics_outlined, size: 20), text: l.tabResults),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            PropertiesPanel(editor: editor),
            DemandPanel(editor: editor),
            SimulationPanel(editor: editor, sim: sim, settings: widget.settings, onShowResults: () {
              tabs.animateTo(3);
              setState(() => mode = WorkspaceMode.simulation);
            }),
            ResultsPanel(editor: editor, sim: sim),
          ],
        ),
      ),
    ]);
  }
}

class _ScaleBar extends StatelessWidget {
  final MapViewport vp;
  const _ScaleBar({required this.vp});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vp,
      builder: (context, _) {
        final s = vp.gridSpacing();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(width: vp.px(s), height: 4, color: const Color(0xFF263238)),
            const SizedBox(height: 2),
            Text('${s.toStringAsFixed(0)} m', style: const TextStyle(fontSize: 11), textDirection: TextDirection.ltr),
          ]),
        );
      },
    );
  }
}
