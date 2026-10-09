import '../model/project.dart';
import 'project_store_memory.dart' if (dart.library.io) 'project_store_file.dart' as impl;

class ProjectSummary {
  final String id;
  final String name;
  final DateTime updatedAt;
  final int variantCount;
  const ProjectSummary(this.id, this.name, this.updatedAt, this.variantCount);
}

/// Local, offline project storage. Design work never needs the server.
abstract class ProjectStore {
  Future<List<ProjectSummary>> list();
  Future<Project?> load(String id);
  Future<void> save(Project project);
  Future<void> delete(String id);

  /// Simulated network geometry + trajectory of a variant's last run (can be large).
  Future<void> saveSimCache(String projectId, String variantId, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> loadSimCache(String projectId, String variantId);

  /// Write an export file; returns a human-readable location.
  Future<String> export(String fileName, String content);

  /// Key/value settings (server URL, language...).
  Future<Map<String, dynamic>> loadSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);

  static ProjectStore create() => impl.createStore();
}
