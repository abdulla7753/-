import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roadflow_ai/l10n/app_localizations.dart';
import 'package:roadflow_ai/model/project_factory.dart';
import 'package:roadflow_ai/services/api_client.dart';
import 'package:roadflow_ai/services/app_settings.dart';
import 'package:roadflow_ai/services/project_store_memory.dart';
import 'package:roadflow_ai/ui/workspace/results_panel.dart';
import 'package:roadflow_ai/ui/workspace/workspace_screen.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

/// JSON response exactly as FastAPI sends it: UTF-8 bytes, no charset parameter.
http.Response jsonResponse(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status, headers: {'content-type': 'application/json'});

/// Fake simulation server replaying responses recorded from the real server.
SimulationApi fakeServer(List<String> calls) {
  final done = jsonDecode(fx('job_done.json')) as Map<String, dynamic>;
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    final path = req.url.path;
    if (req.method == 'POST' && path == '/v1/simulations') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      // The request the app sends must be complete enough for the server schema.
      expect(body['schemaVersion'], 1);
      expect((body['network'] as Map)['roads'], isNotEmpty);
      return jsonResponse(jsonEncode({...done, 'status': 'queued', 'progress': 0, 'result': null}), 202);
    }
    if (path.endsWith('/network')) return jsonResponse(fx('network.json'), 200);
    if (path.endsWith('/trajectory')) return jsonResponse(fx('trajectory.json'), 200);
    if (path.startsWith('/v1/simulations/')) return jsonResponse(jsonEncode(done), 200);
    return http.Response('not found', 404);
  });
  return SimulationApi('http://fake', client: client);
}

Future<void> pumpWorkspace(WidgetTester tester, {Locale locale = const Locale('en'), List<String>? calls}) async {
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = MemoryProjectStore();
  final settings = AppSettings(store);
  final project = createProject('Test', ProjectTemplate.tJunction);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WorkspaceScreen(
      store: store,
      settings: settings,
      project: project,
      apiFactory: (_, _) => fakeServer(calls ?? []),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draw a road with the road tool, then undo it', (tester) async {
    await pumpWorkspace(tester);
    expect(find.text('Select'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tool_road')));
    await tester.pumpAndSettle();
    final canvas = find.byType(CustomPaint).first;
    final centre = tester.getCenter(canvas);
    await tester.dragFrom(centre + const Offset(-300, 250), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Undo'), findsOneWidget);
    final undo = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undo.onPressed, isNotNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pumpAndSettle();
  });

  testWidgets('run a simulation against a recorded server response and show results', (tester) async {
    final calls = <String>[];
    await pumpWorkspace(tester, calls: calls);
    await tester.tap(find.byKey(const Key('tabSimulation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runSimulation')));
    // Polling uses real timers: advance fake time until the run completes.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 900));
    }
    await tester.pumpAndSettle();
    expect(calls, contains('POST /v1/simulations'));
    expect(calls.any((c) => c.endsWith('/trajectory')), isTrue);
    expect(find.textContaining('Simulation finished'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tabResults')));
    await tester.pumpAndSettle();
    expect(find.text('Average delay'), findsOneWidget);
    expect(find.textContaining('Indicative only'), findsOneWidget);
    final list = find.descendant(of: find.byType(ResultsPanel), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Approaches'), 300, scrollable: list);
    expect(find.text('Approaches'), findsOneWidget);
    // Real server output for the minor road of the T-junction is shown with its LOS letter.
    await tester.scrollUntilVisible(find.textContaining('Data quality'), 300, scrollable: list);
    expect(find.textContaining('Data quality'), findsOneWidget);
  });

  testWidgets('Arabic UI renders right-to-left', (tester) async {
    await pumpWorkspace(tester, locale: const Locale('ar'));
    expect(find.text('تحديد'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('تحديد')));
    expect(dir, TextDirection.rtl);
  });
}
