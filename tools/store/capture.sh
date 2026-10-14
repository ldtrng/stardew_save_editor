#!/usr/bin/env bash
# Captures store screenshots from a device/emulator.
# Usage: tools/store/capture.sh [LANGS]   e.g. tools/store/capture.sh en,vi
set -euo pipefail
cd "$(dirname "$0")/../.."
LANGS="${1:-}"
OUT=store/screenshots/raw
mkdir -p "$OUT"
adb push test/fixtures/TestSave /data/local/tmp/TestSave >/dev/null
adb shell chmod 644 /data/local/tmp/TestSave
flutter build apk --profile --dart-define=SHOTS=true --dart-define=LANGS="$LANGS"
adb install -r build/app/outputs/flutter-apk/app-profile.apk >/dev/null
adb shell pm clear io.ld2t.stardew_save_editor >/dev/null
# Clean status bar (demo mode).
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
adb logcat -c
adb shell am start -n io.ld2t.stardew_save_editor/.MainActivity >/dev/null
adb logcat -s flutter:I | while read -r line; do
  case "$line" in
    *SHOT_READY*)
      name="${line##*SHOT_READY }"; name="${name//[$'\r ']}"
      adb exec-out screencap -p > "$OUT/$name.png"
      echo "captured $name";;
    *SHOT_DONE*) echo done; pkill -f "adb logcat -s flutter" || true; break;;
  esac
done
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
