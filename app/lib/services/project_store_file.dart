import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/project.dart';
import 'project_store.dart';

ProjectStore createStore() => FileProjectStore();

/// Stores each project as JSON in the app documents folder.
///
/// Writes are atomic (temp file + rename) and the previous version is kept as
/// `.bak`, so a crash or power loss during autosave never corrupts a project.
class FileProjectStore implements ProjectStore {
  FileProjectStore({this._root});
  Directory? _root;

  Future<Directory> _dir(String sub) async {
    _root ??= Directory('${(await getApplicationDocumentsDirectory()).path}/RoadFlowAI');
    final d = Directory('${_root!.path}/$sub');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _projectFile(String id) async => File('${(await _dir('projects')).path}/$id.json');

  Future<void> _atomicWrite(File f, String content, {bool backup = false}) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (backup && await f.exists()) await f.copy('${f.path}.bak');
    await tmp.rename(f.path);
  }

  @override
  Future<List<ProjectSummary>> list() async {
    final dir = await _dir('projects');
    final out = <ProjectSummary>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await e.readAsString()) as Map<String, dynamic>;
        out.add(ProjectSummary(
          j['id'] as String,
          j['name'] as String,
          DateTime.parse(j['updatedAt'] as String),
          (j['variants'] as List).length,
        ));
      } catch (_) {
        // Unreadable file: skipped here, recovered from .bak on open if possible.
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  @override
  Future<Project?> load(String id) async {
    final f = await _projectFile(id);
    for (final candidate in [f, File('${f.path}.bak')]) {
      if (!await candidate.exists()) continue;
      try {
        return Project.fromJson(jsonDecode(await candidate.readAsString()) as Map<String, dynamic>);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<void> save(Project project) async =>
      _atomicWrite(await _projectFile(project.id), jsonEncode(project.toJson()), backup: true);

  @override
  Future<void> delete(String id) async {
    final f = await _projectFile(id);
    for (final p in [f.path, '${f.path}.bak']) {
      final x = File(p);
      if (await x.exists()) await x.delete();
    }
    final cache = await _dir('cache');
    await for (final e in cache.list()) {
      if (e.path.split(Platform.pathSeparator).last.startsWith('$id.')) await e.delete();
    }
  }

  @override
  Future<void> saveSimCache(String projectId, String variantId, Map<String, dynamic> data) async {
    final f = File('${(await _dir('cache')).path}/$projectId.$variantId.json');
    await _atomicWrite(f, jsonEncode(data));
  }

  @override
  Future<Map<String, dynamic>?> loadSimCache(String projectId, String variantId) async {
    final f = File('${(await _dir('cache')).path}/$projectId.$variantId.json');
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> export(String fileName, String content) async {
    final f = File('${(await _dir('exports')).path}/$fileName');
    await _atomicWrite(f, content);
    return f.path;
  }

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    final f = File('${(await _dir('.')).path}/settings.json');
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async =>
      _atomicWrite(File('${(await _dir('.')).path}/settings.json'), jsonEncode(settings));
}
