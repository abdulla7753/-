import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/app_settings.dart';
import 'services/project_store.dart';
import 'ui/home/projects_screen.dart';

class RoadFlowApp extends StatelessWidget {
  final ProjectStore store;
  final AppSettings settings;
  const RoadFlowApp({super.key, required this.store, required this.settings});

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF8A1538), brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: settings.locale.languageCode == 'ar' ? 'NotoSansArabic' : 'NotoSans',
      fontFamilyFallback: const ['NotoSans', 'NotoSansArabic'],
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'RoadFlow AI',
        debugShowCheckedModeBanner: false,
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.light,
        home: ProjectsScreen(store: store, settings: settings),
      ),
    );
  }
}
