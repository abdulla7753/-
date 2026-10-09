import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roadflow_ai/model/project_factory.dart';
import 'package:roadflow_ai/services/project_store_file.dart';

void main() {
  late Directory dir;
  late FileProjectStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('roadflow_test');
    store = FileProjectStore(root: dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('save, list, load and delete', () async {
    final p = createProject('Doha study', ProjectTemplate.roundabout);
    await store.save(p);
    final list = await store.list();
    expect(list.single.name, 'Doha study');
    final loaded = await store.load(p.id);
    expect(loaded!.toJson(), p.toJson());
    await store.saveSimCache(p.id, p.active.id, {'network': {}, 'trajectory': null});
    expect(await store.loadSimCache(p.id, p.active.id), isNotNull);
    await store.delete(p.id);
    expect(await store.list(), isEmpty);
    expect(await store.loadSimCache(p.id, p.active.id), isNull);
  });

  test('recovers the previous version when the project file is corrupted', () async {
    final p = createProject('A', ProjectTemplate.signalised);
    await store.save(p);
    await store.save(p.copyWith(name: 'A v2'));
    // Simulate a crash that left a truncated file behind.
    File('${dir.path}/projects/${p.id}.json').writeAsStringSync('{"id": "trunc');
    final recovered = await store.load(p.id);
    expect(recovered, isNotNull);
    expect(recovered!.name, 'A');
  });

  test('settings persist', () async {
    await store.saveSettings({'serverUrl': 'https://sim.example', 'locale': 'en'});
    expect((await store.loadSettings())['serverUrl'], 'https://sim.example');
  });
}
