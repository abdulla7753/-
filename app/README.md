# RoadFlow AI – tablet app

Flutter app for Android tablets and iPad. See the [main README](../README.md) for an
overview and [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for the code structure.

```bash
flutter pub get
flutter test && flutter analyze
flutter run                                     # on a connected tablet / emulator
flutter build apk                               # Android
flutter build ios                               # iPad (macOS + Xcode + signing team)
# Default simulation server address can be baked in:
flutter build apk --dart-define=ROADFLOW_SERVER=https://sim.example.org
```

UI strings live in `tool/gen_arb.py` (Arabic and English side by side) and are written
to `lib/l10n/*.arb`. Regenerate with `python3 tool/gen_arb.py lib/l10n && flutter gen-l10n`.
