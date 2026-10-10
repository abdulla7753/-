#!/usr/bin/env bash
# Install and launch RoadFlow AI on a USB-connected Android tablet, with the
# simulation server running on this computer.
#
#   scripts/android_tablet_test.sh [path/to/app-release.apk]
#
# Without an APK path the app is built with `flutter build apk`. `adb reverse`
# forwards the tablet's localhost:8000 to this computer, so the app's default
# server address (http://localhost:8000) works without any network setup.
# Screenshots: scripts/android_tablet_test.sh shot <name>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG=qa.roadflow.roadflow_ai
OUT="$ROOT/tablet-screenshots"

need() { command -v "$1" >/dev/null || { echo "missing: $1 ($2)"; exit 1; }; }
need adb "Android platform-tools"

if [[ "${1:-}" == "shot" ]]; then
  mkdir -p "$OUT"
  adb exec-out screencap -p > "$OUT/${2:-shot}.png"
  echo "saved $OUT/${2:-shot}.png"
  exit 0
fi

devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ -z "$devices" ]]; then
  echo "No authorised device. Enable USB debugging on the tablet and accept the prompt."; adb devices; exit 1
fi
echo "device: $devices ($(adb shell getprop ro.product.model | tr -d '\r'), Android $(adb shell getprop ro.build.version.release | tr -d '\r'))"

APK="${1:-}"
if [[ -z "$APK" ]]; then
  need flutter "Flutter SDK"
  (cd "$ROOT/app" && flutter build apk --release)
  APK="$ROOT/app/build/app/outputs/flutter-apk/app-release.apk"
fi
adb install -r "$APK"

# Start the simulation server here unless one is already listening.
if ! curl -fsS http://localhost:8000/health >/dev/null 2>&1; then
  need python3 "Python 3.11+"
  (cd "$ROOT/server" && python3 -m pip install -q -r requirements.txt \
    && nohup python3 -m uvicorn roadflow_server.main:app --host 127.0.0.1 --port 8000 > "$ROOT/server/server.log" 2>&1 &)
  for _ in $(seq 1 30); do curl -fsS http://localhost:8000/health >/dev/null 2>&1 && break; sleep 1; done
fi
curl -fsS http://localhost:8000/health && echo

adb reverse tcp:8000 tcp:8000
adb shell am start -n "$PKG/.MainActivity" >/dev/null
echo "RoadFlow AI started; server reachable on the tablet at http://localhost:8000"
