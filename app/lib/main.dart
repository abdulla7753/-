import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/app_settings.dart';
import 'services/project_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape is the primary orientation for engineering design on tablets.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  final store = ProjectStore.create();
  final settings = AppSettings(store);
  await settings.load();
  runApp(RoadFlowApp(store: store, settings: settings));
}
