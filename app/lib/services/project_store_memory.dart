import 'dart:convert';

import '../model/project.dart';
import 'project_store.dart';

ProjectStore createStore() => MemoryProjectStore();

/// In-memory store used by the web test build and unit tests (no file system).
class MemoryProjectStore implements ProjectStore {
  final Map<String, String> _projects = {};
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, String> exports = {};
  Map<String, dynamic> _settings = {};

  @override
  Future<List<ProjectSummary>> list() async {
    final out = [
      for (final s in _projects.values)
        () {
          final j = jsonDecode(s) as Map<String, dynamic>;
          return ProjectSummary(
              j['id'] as String, j['name'] as String, DateTime.parse(j['updatedAt'] as String), (j['variants'] as List).length);
        }()
    ];
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  @override
  Future<Project?> load(String id) async {
    final s = _projects[id];
    return s == null ? null : Project.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  @override
  Future<void> save(Project project) async => _projects[project.id] = jsonEncode(project.toJson());

  @override
  Future<void> delete(String id) async {
    _projects.remove(id);
    _cache.removeWhere((k, _) => k.startsWith('$id.'));
  }

  @override
  Future<void> saveSimCache(String projectId, String variantId, Map<String, dynamic> data) async =>
      _cache['$projectId.$variantId'] = data;

  @override
  Future<Map<String, dynamic>?> loadSimCache(String projectId, String variantId) async => _cache['$projectId.$variantId'];

  @override
  Future<String> export(String fileName, String content) async {
    exports[fileName] = content;
    return 'memory://$fileName';
  }

  @override
  Future<Map<String, dynamic>> loadSettings() async => Map.of(_settings);

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async => _settings = Map.of(settings);
}
