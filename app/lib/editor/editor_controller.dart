import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/geometry.dart';
import '../model/network.dart';
import '../model/project.dart';
import '../model/scenario.dart';
import '../services/project_store.dart';
import 'network_ops.dart';
import 'network_ops.dart' as ops;

enum EditorTool { select, road, curve, junction, measure }

sealed class Selection {
  const Selection();
}

class NodeSelection extends Selection {
  final String id;
  const NodeSelection(this.id);
}

class RoadSelection extends Selection {
  final String id;
  const RoadSelection(this.id);
}

enum SaveState { saved, pending, saving, error }

/// Holds the open project, the active variant and all editing state.
///
/// Every committed change goes through [_commit], which records undo history and
/// schedules an autosave; previews during drags bypass history until released.
class EditorController extends ChangeNotifier {
  final ProjectStore store;
  Project _project;

  EditorController(this.store, Project project) : _project = project;

  // ------------------------------------------------------------- state
  final List<Variant> _undo = [];
  final List<Variant> _redo = [];
  static const _historyLimit = 200;

  EditorTool tool = EditorTool.select;
  Selection? selection;
  RoadDefaults roadDefaults = const RoadDefaults();
  bool gridSnap = true;
  bool angleSnap = true;
  bool autoJunctions = true;
  bool penOnlyDrawing = false;
  JunctionTemplate template = JunctionTemplate.fourWay;
  double templateArmM = 200;
  final List<Vec2> measurePoints = [];

  SaveState saveState = SaveState.saved;
  Timer? _saveTimer;
  Variant? _dragOrigin;

  Project get project => _project;
  Variant get variant => _project.active;
  Network get network => variant.network;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // ------------------------------------------------------------- history
  void _commit(Variant next, {bool record = true}) {
    if (record) {
      _undo.add(_dragOrigin ?? variant);
      if (_undo.length > _historyLimit) _undo.removeAt(0);
      _redo.clear();
    }
    _dragOrigin = null;
    _project = _project.replaceVariant(next);
    _validateSelection();
    _scheduleSave();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(variant);
    _project = _project.replaceVariant(_undo.removeLast().copyWith(lastResult: variant.lastResult));
    _validateSelection();
    _scheduleSave();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(variant);
    _project = _project.replaceVariant(_redo.removeLast().copyWith(lastResult: variant.lastResult));
    _validateSelection();
    _scheduleSave();
    notifyListeners();
  }

  void _validateSelection() {
    final s = selection;
    if (s is NodeSelection && !network.nodes.containsKey(s.id)) selection = null;
    if (s is RoadSelection && !network.roads.containsKey(s.id)) selection = null;
  }

  // ------------------------------------------------------------- persistence
  void _scheduleSave() {
    saveState = SaveState.pending;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1200), saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    saveState = SaveState.saving;
    _notify();
    try {
      await store.save(_project);
      saveState = SaveState.saved;
    } catch (_) {
      saveState = SaveState.error;
    }
    _notify();
  }

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Flushes any pending autosave, then releases the controller.
  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) saveNow();
    _saveTimer?.cancel();
    _disposed = true;
    super.dispose();
  }

  // ------------------------------------------------------------- tools & selection
  void setTool(EditorTool t) {
    tool = t;
    if (t != EditorTool.measure) measurePoints.clear();
    notifyListeners();
  }

  void select(Selection? s) {
    selection = s;
    notifyListeners();
  }

  void setOptions({
    bool? grid,
    bool? angle,
    bool? junctions,
    bool? penOnly,
    RoadDefaults? defaults,
    JunctionTemplate? junctionTemplate,
    double? armM,
  }) {
    gridSnap = grid ?? gridSnap;
    angleSnap = angle ?? angleSnap;
    autoJunctions = junctions ?? autoJunctions;
    penOnlyDrawing = penOnly ?? penOnlyDrawing;
    roadDefaults = defaults ?? roadDefaults;
    template = junctionTemplate ?? template;
    templateArmM = armM ?? templateArmM;
    notifyListeners();
  }

  void addMeasurePoint(Vec2 p) {
    measurePoints.add(p);
    notifyListeners();
  }

  void clearMeasure() {
    measurePoints.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------- network edits
  /// Returns ids of created roads, or null when nothing was drawn.
  List<String>? addRoad(SnapTarget start, SnapTarget end, List<Vec2> interior) {
    final res = ops.addRoad(network, start, end, interior, roadDefaults, autoJunctions: autoJunctions);
    if (res == null) return null;
    var demand = variant.demand;
    if (res.gateMoves.isNotEmpty) demand = _moveGates(demand, res.gateMoves);
    _commit(variant.copyWith(network: res.net, demand: _pruneDemand(demand, res.net)));
    selection = RoadSelection(res.createdRoads.last);
    notifyListeners();
    return res.createdRoads;
  }

  void insertJunction(Vec2 centre) {
    final next = insertTemplate(network, template, centre, roadDefaults, armM: templateArmM);
    _commit(variant.copyWith(network: next));
  }

  /// Live preview while dragging (no history entry until [endDrag]).
  void previewNodeMove(String nodeId, Vec2 pos) {
    _dragOrigin ??= variant;
    _project = _project.replaceVariant(variant.copyWith(network: moveNode(network, nodeId, pos)));
    notifyListeners();
  }

  void previewShapePointMove(String roadId, int index, Vec2 pos) {
    _dragOrigin ??= variant;
    _project = _project.replaceVariant(variant.copyWith(network: moveShapePoint(network, roadId, index, pos)));
    notifyListeners();
  }

  void endDrag() {
    if (_dragOrigin == null) return;
    _commit(variant);
  }

  void updateNode(RoadNode node) => _commit(variant.copyWith(network: ops.updateNode(network, node)));
  void updateRoad(Road road) => _commit(variant.copyWith(network: ops.updateRoad(network, road)));

  void setNetworkOptions({DrivingSide? side, bool? uTurns}) =>
      _commit(variant.copyWith(network: network.copyWith(drivingSide: side, allowUTurns: uTurns)));

  void splitRoadAtMiddle(String roadId) {
    final r = network.roads[roadId];
    if (r == null) return;
    final res = splitRoad(network, roadId, network.roadLength(r) / 2);
    _commit(variant.copyWith(network: res.net));
    selection = NodeSelection(res.nodeId);
    notifyListeners();
  }

  void deleteSelection() {
    final s = selection;
    Network next = network;
    if (s is NodeSelection) next = deleteNode(network, s.id);
    if (s is RoadSelection) next = deleteRoad(network, s.id);
    if (identical(next, network)) return;
    selection = null;
    _commit(variant.copyWith(network: next, demand: _pruneDemand(variant.demand, next)));
  }

  // ------------------------------------------------------------- scenario edits
  void updateDemand(Demand d) => _commit(variant.copyWith(demand: d));
  void updateSignals(SignalSettings s) => _commit(variant.copyWith(signals: s));
  void updateDrivers(DriverSettings d) => _commit(variant.copyWith(drivers: d));
  void updateRun(RunSettings r) => _commit(variant.copyWith(run: r));

  /// Store a result on the variant that was simulated. Results are not part of undo history.
  void setResult(String variantId, StoredResult? r) {
    final target = _project.variants.where((v) => v.id == variantId).firstOrNull;
    if (target == null) return;
    _project = _project.replaceVariant(r == null ? target.copyWith(clearResult: true) : target.copyWith(lastResult: r));
    _scheduleSave();
    notifyListeners();
  }

  Demand _moveGates(Demand d, Map<String, String> moves) {
    String m(String id) => moves[id] ?? id;
    return d.copyWith(origins: {
      for (final e in d.origins.entries)
        m(e.key): e.value.copyWith(shares: {for (final s in e.value.shares.entries) m(s.key): s.value})
    });
  }

  /// Drop demand that refers to nodes which no longer exist.
  Demand _pruneDemand(Demand d, Network net) => d.copyWith(origins: {
        for (final e in d.origins.entries)
          if (net.nodes.containsKey(e.key))
            e.key: e.value.copyWith(shares: {
              for (final s in e.value.shares.entries)
                if (net.nodes.containsKey(s.key)) s.key: s.value
            })
      });

  // ------------------------------------------------------------- variants & project
  void renameProject(String name) {
    _project = _project.copyWith(name: name, updatedAt: DateTime.now());
    _scheduleSave();
    notifyListeners();
  }

  void switchVariant(String id) {
    if (id == variant.id) return;
    _project = _project.copyWith(activeVariantId: id);
    _undo.clear();
    _redo.clear();
    selection = null;
    _scheduleSave();
    notifyListeners();
  }

  void duplicateVariant(String name) {
    final id = 'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final copy = variant.copyWith(id: id, name: name, clearResult: true);
    _project = _project.copyWith(variants: [..._project.variants, copy], activeVariantId: id, updatedAt: DateTime.now());
    _undo.clear();
    _redo.clear();
    _scheduleSave();
    notifyListeners();
  }

  void renameVariant(String name) {
    _project = _project.replaceVariant(variant.copyWith(name: name));
    _scheduleSave();
    notifyListeners();
  }

  bool deleteActiveVariant() {
    if (_project.variants.length < 2) return false;
    final remaining = _project.variants.where((v) => v.id != variant.id).toList();
    _project = _project.copyWith(variants: remaining, activeVariantId: remaining.first.id, updatedAt: DateTime.now());
    _undo.clear();
    _redo.clear();
    selection = null;
    _scheduleSave();
    notifyListeners();
    return true;
  }
}
