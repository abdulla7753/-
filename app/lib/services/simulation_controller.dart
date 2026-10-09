import 'dart:async';

import 'package:flutter/foundation.dart';

import '../editor/editor_controller.dart';
import '../model/project.dart';
import '../model/request_builder.dart';
import '../model/results.dart';
import 'api_client.dart';
import 'app_settings.dart';

enum SimPhase { idle, submitting, running, fetching, done, failed }

/// Runs the active variant on the simulation server and keeps playback data.
class SimulationController extends ChangeNotifier {
  final EditorController editor;
  final AppSettings settings;
  final SimulationApi Function(String url, String token) apiFactory;

  SimulationController(this.editor, this.settings, {SimulationApi Function(String, String)? apiFactory})
      : apiFactory = apiFactory ?? ((u, t) => SimulationApi(u, token: t));

  SimPhase phase = SimPhase.idle;
  double progress = 0;
  String message = '';
  List<String> errors = [];
  String? _jobId;
  bool _cancelled = false;

  // Playback data of the active variant's last result.
  SimNetwork? simNetwork;
  Trajectory? trajectory;
  String? _loadedFor; // "<variantId>:<jobId>"

  // Server-side validation (netconvert build) of the current design.
  bool validating = false;
  List<String>? buildWarnings;
  List<String>? buildErrors;

  bool get busy => phase == SimPhase.submitting || phase == SimPhase.running || phase == SimPhase.fetching;

  SimulationResult? get result {
    final r = editor.variant.lastResult;
    return r == null ? null : SimulationResult(r.result);
  }

  /// True when the design changed after the stored result was computed.
  bool get resultStale {
    final r = editor.variant.lastResult;
    if (r == null) return false;
    return requestFingerprint(buildSimulationRequest(editor.variant)) != r.requestFingerprint;
  }

  SimulationApi _api() => apiFactory(settings.serverUrl, settings.token);

  Future<Map<String, dynamic>> checkServer() => _api().health();

  Future<void> validateOnServer() async {
    validating = true;
    buildErrors = null;
    buildWarnings = null;
    notifyListeners();
    try {
      final r = await _api().buildNetwork(buildBuildRequest(editor.variant));
      buildWarnings = [for (final w in (r['warnings'] as List? ?? const [])) '$w'];
      buildErrors = [];
    } on ApiException catch (e) {
      buildErrors = e.messages;
    } finally {
      validating = false;
      notifyListeners();
    }
  }

  Future<void> run() async {
    if (busy) return;
    final issues = validate(editor.variant).where((i) => i.blocking).toList();
    if (issues.isNotEmpty) {
      phase = SimPhase.failed;
      errors = issues.map((i) => i.toString()).toList();
      notifyListeners();
      return;
    }
    final variant = editor.variant;
    final request = buildSimulationRequest(variant, label: '${editor.project.name} / ${variant.name}');
    final fingerprint = requestFingerprint(request);
    final api = _api();
    _cancelled = false;
    phase = SimPhase.submitting;
    progress = 0;
    message = '';
    errors = [];
    notifyListeners();
    try {
      var status = await api.submit(request);
      _jobId = status.jobId;
      phase = SimPhase.running;
      notifyListeners();
      while (!status.finished) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (_cancelled) {
          await api.delete(status.jobId);
          phase = SimPhase.idle;
          notifyListeners();
          return;
        }
        status = await api.status(status.jobId);
        progress = status.progress;
        message = status.message;
        notifyListeners();
      }
      if (status.status == 'failed') {
        phase = SimPhase.failed;
        errors = status.errors.isEmpty ? [status.message] : status.errors;
        notifyListeners();
        return;
      }
      phase = SimPhase.fetching;
      notifyListeners();
      final netJson = await api.network(status.jobId);
      Map<String, dynamic>? trajJson;
      if (status.result?['hasTrajectory'] == true) trajJson = await api.trajectory(status.jobId);
      // The user may have switched variant meanwhile: the result belongs to the variant that was run.
      final stored = StoredResult(
        jobId: status.jobId,
        serverUrl: settings.serverUrl,
        completedAt: DateTime.now(),
        requestFingerprint: fingerprint,
        result: status.result ?? const {},
      );
      await editor.store.saveSimCache(editor.project.id, variant.id, {'network': netJson, 'trajectory': trajJson});
      editor.setResult(variant.id, stored);
      if (editor.variant.id == variant.id) _setPlayback(netJson, trajJson, '${variant.id}:${status.jobId}');
      phase = SimPhase.done;
      progress = 1;
      notifyListeners();
    } on ApiException catch (e) {
      phase = SimPhase.failed;
      errors = e.messages;
      notifyListeners();
    } finally {
      _jobId = null;
    }
  }

  void cancel() {
    if (_jobId != null) _cancelled = true;
  }

  void _setPlayback(Map<String, dynamic>? net, Map<String, dynamic>? traj, String key) {
    simNetwork = net == null ? null : SimNetwork.fromJson(net);
    trajectory = traj == null ? null : Trajectory.fromJson(traj);
    _loadedFor = key;
  }

  /// Load cached playback data for the active variant (after reopening a project).
  Future<void> ensurePlaybackLoaded() async {
    final v = editor.variant;
    final r = v.lastResult;
    if (r == null) {
      if (_loadedFor != null) {
        simNetwork = null;
        trajectory = null;
        _loadedFor = null;
        notifyListeners();
      }
      return;
    }
    final key = '${v.id}:${r.jobId}';
    if (_loadedFor == key) return;
    final cache = await editor.store.loadSimCache(editor.project.id, v.id);
    _setPlayback(cache?['network'] as Map<String, dynamic>?, cache?['trajectory'] as Map<String, dynamic>?, key);
    notifyListeners();
  }
}
