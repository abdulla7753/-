import 'package:flutter/widgets.dart';

import 'project_store.dart';

/// Application-wide preferences persisted locally.
class AppSettings extends ChangeNotifier {
  static const defaultServer = String.fromEnvironment('ROADFLOW_SERVER', defaultValue: 'http://localhost:8000');

  final ProjectStore store;
  String serverUrl = defaultServer;
  String token = '';
  Locale locale = const Locale('ar');

  AppSettings(this.store);

  Future<void> load() async {
    final s = await store.loadSettings();
    serverUrl = (s['serverUrl'] as String?)?.trim().isNotEmpty == true ? s['serverUrl'] as String : defaultServer;
    token = s['token'] as String? ?? '';
    final lang = s['locale'] as String?;
    if (lang == 'en' || lang == 'ar') locale = Locale(lang!);
    notifyListeners();
  }

  Future<void> _persist() =>
      store.saveSettings({'serverUrl': serverUrl, 'token': token, 'locale': locale.languageCode});

  Future<void> setServer(String url, String newToken) async {
    serverUrl = url.trim();
    token = newToken.trim();
    notifyListeners();
    await _persist();
  }

  Future<void> setLocale(Locale l) async {
    locale = l;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleLocale() => setLocale(locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}
