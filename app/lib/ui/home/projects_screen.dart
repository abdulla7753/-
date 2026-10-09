import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/app_localizations.dart';
import '../../model/project_factory.dart';
import '../../services/app_settings.dart';
import '../../services/project_store.dart';
import '../settings_dialog.dart';
import '../workspace/workspace_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final ProjectStore store;
  final AppSettings settings;
  const ProjectsScreen({super.key, required this.store, required this.settings});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectSummary>? _projects;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.list();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _open(String id) async {
    final project = await widget.store.load(id);
    if (!mounted) return;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).projectLoadFailed)));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkspaceScreen(store: widget.store, settings: widget.settings, project: project),
    ));
    _reload();
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: l.newProjectDefaultName);
    var template = ProjectTemplate.signalised;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.newProject),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('newProjectName'),
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.projectName, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text(l.startFrom, style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ProjectTemplate.values)
                      ChoiceChip(
                        key: Key('template_${t.name}'),
                        label: Text(switch (t) {
                          ProjectTemplate.blank => l.templateBlank,
                          ProjectTemplate.signalised => l.templateSignalised,
                          ProjectTemplate.tJunction => l.templateTJunction,
                          ProjectTemplate.roundabout => l.templateRoundabout,
                        }),
                        selected: template == t,
                        onSelected: (_) => setLocal(() => template = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l.templateDemandNote, style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(key: const Key('createProject'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.create)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim().isEmpty ? l.newProjectDefaultName : nameCtrl.text.trim();
    final project = createProject(name, template, variantName: l.variantExisting);
    await widget.store.save(project);
    await _open(project.id);
  }

  Future<void> _delete(ProjectSummary p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteProject),
        content: Text(l.deleteProjectConfirm(p.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.delete(p.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd(l.localeName).add_Hm();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.alt_route, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('RoadFlow AI'),
          const SizedBox(width: 12),
          Flexible(child: Text(l.appTagline, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          TextButton.icon(
            key: const Key('toggleLanguage'),
            onPressed: widget.settings.toggleLocale,
            icon: const Icon(Icons.translate),
            label: Text(l.otherLanguage),
          ),
          IconButton(
            tooltip: l.serverSettings,
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => showServerSettings(context, widget.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newProject'),
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(l.newProject),
      ),
      body: _projects == null
          ? const Center(child: CircularProgressIndicator())
          : _projects!.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_road, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(l.noProjects, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l.noProjectsHint, style: theme.textTheme.bodyMedium),
                  ]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _projects!.length,
                  itemBuilder: (context, i) {
                    final p = _projects![i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(p.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.map_outlined, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(p.name,
                                      style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                IconButton(
                                  tooltip: l.delete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(p),
                                ),
                              ]),
                              const Spacer(),
                              Text(l.variantsCount(p.variantCount), style: theme.textTheme.bodySmall),
                              Text(l.lastModified(fmt.format(p.updatedAt)), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
