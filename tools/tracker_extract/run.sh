#!/usr/bin/env bash
# Re-extracts tracker game data + images from a Stardew Valley Tracker .xapk.
# Usage: tools/tracker_extract/run.sh path/to/app.xapk [work_dir]
# Writes assets/tracker/{data,img} (or under $DEST if set). Never executes code from the APK: the
# Hermes bundle is decompiled by hermes-dec and then read as text.
set -euo pipefail
XAPK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${DEST:-$(cd "$HERE/../.." && pwd)}"
WORK="${2:-$(mktemp -d)}"
mkdir -p "$WORK"/{xapk,base,dec,analysis/data,tools}
export SDV_WORK="$WORK"

echo "Work dir: $WORK"
unzip -oq "$XAPK" -d "$WORK/xapk"
BASE_APK=$(ls "$WORK"/xapk/*.apk | grep -v '/config\.' | head -1)
unzip -oq "$BASE_APK" -d "$WORK/base"

if [ ! -x "$WORK/venv/bin/hbc-decompiler" ]; then
  python3 -m venv "$WORK/venv"
  "$WORK/venv/bin/pip" install -q git+https://github.com/P1sec/hermes-dec
fi
"$WORK/venv/bin/hbc-decompiler" "$WORK/base/assets/index.android.bundle" "$WORK/dec/out.js" > "$WORK/dec/log.txt" 2>&1

cd "$HERE"
python3 -I split_modules.py "$WORK/dec/out.js" "$WORK/tools/modules.json"
python3 -I assets_map.py "$WORK/dec/out.js" "$WORK/tools/modules.json" "$WORK/base/res/drawable-mdpi-v4" "$WORK/tools/assets.json"
SDV_WORK="$WORK" python3 -I build_data.py
python3 -I validate.py "$WORK/analysis/data" "$WORK/base/res/drawable-mdpi-v4" || true

mkdir -p "$ROOT/assets/tracker/data" "$ROOT/assets/tracker/img"
cp "$WORK"/analysis/data/*.json "$ROOT/assets/tracker/data/"
rm -f "$ROOT/assets/tracker/data/images_map.json"
python3 -I build_i18n.py "$WORK/analysis/data/i18n" "$ROOT/assets/tracker/i18n" && rm -f "$ROOT/assets/tracker/i18n/en.json"
for f in "$WORK"/base/res/drawable-mdpi-v4/src_assets_*; do
  case "$(basename "$f")" in *onboarding*|*_ads_*) continue;; esac
  cp "$f" "$ROOT/assets/tracker/img/"
done
echo "Done. Run: flutter test test/tracker_test.dart"
