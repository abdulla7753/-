import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/app_settings.dart';

Future<void> showServerSettings(BuildContext context, AppSettings settings) async {
  final l = AppLocalizations.of(context);
  final url = TextEditingController(text: settings.serverUrl);
  final token = TextEditingController(text: settings.token);
  String? status;
  var testing = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Future<void> test() async {
          setLocal(() {
            testing = true;
            status = null;
          });
          try {
            final h = await SimulationApi(url.text.trim(), token: token.text.trim()).health();
            final engine = h['engine'] as Map<String, dynamic>? ?? const {};
            status = l.serverOk('${engine['name']} ${engine['version']}', '${h['server']}');
          } on ApiException catch (e) {
            status = l.serverUnreachable(e.toString());
          }
          setLocal(() => testing = false);
        }

        return AlertDialog(
          title: Text(l.serverSettings),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.serverExplanation, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('serverUrl'),
                  controller: url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.serverUrl, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: token,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.apiToken, border: const OutlineInputBorder()),
                ),
                ValueListenableBuilder(
                  valueListenable: url,
                  builder: (_, v, _) {
                    final u = Uri.tryParse(v.text.trim());
                    final local = u != null && (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '10.0.2.2');
                    if (u == null || u.scheme != 'http' || local) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l.insecureServer, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (testing) const LinearProgressIndicator(),
                if (status != null) Text(status!),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: testing ? null : test, child: Text(l.testConnection)),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(
              onPressed: () async {
                await settings.setServer(url.text, token.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        );
      },
    ),
  );
}
