# Tracker & Save Editor: Stardew Valley

Flutter Android app (`io.ld2t.stardew_save_editor`) that combines:

- **Tracker** – a clone of *Stardew Valley Tracker* (com.hiugo.stardewvalley 5.3.5): calendar with birthdays/festivals/Queen of Sauce/to-do notes, villagers (gifts, schedules, hearts), Community Center bundles (normal + remixed), fish, crops, cooking, crafting, museum, shipping, golden walnuts, stardrops, wearables, monsters, Carpenter/Wizard buildings. Multiple farms, all offline.
- **Save editor** – a Dart port of [colecrouter/stardew-save-editor](https://github.com/colecrouter/stardew-save-editor) (MIT): character, skills, professions, wallet, appearance (layered preview), inventory & equipment, every chest/fridge, relationships, cooking/crafting recipes, Community Center bundles (with the game's mail-flag side effects), buildings & animals, Mr. Qi's special orders, automatic backups.
- **Bridge** – "Import progress from a save file" fills the tracker from a real save.

Default language: English. UI: pixel style (Pixelify Sans, OFL) with a farm palette (day/night themes).

## Run

```bash
flutter run -d emulator-5554
```

```bash
flutter test
```

## Layout

| Path | What |
|---|---|
| `lib/save/` | Save file core: zlib/XML parse, in-place DOM edits, .NET-style serializer (unedited exports are byte-identical) |
| `lib/features/editor/` | Editor screens, file access guide |
| `lib/features/{calendar,villagers,tracker,settings,onboarding}/` | Tracker screens |
| `lib/data/game_data.dart` | Loads `assets/tracker/data/*.json` |
| `lib/state/` | Editor, tracker (per-farm checklists/notes, SharedPreferences JSON), settings |
| `lib/ads/` | AdMob: banner, interstitial, app open, rewarded (24 h ad-free) + UMP consent |
| `android/.../MainActivity.kt` | SAF bridge: game Saves folder access (Android ≤ 12), save-as without extension |
| `assets/editor/` | Item DB + sprite sheets from stardew-save-editor |
| `assets/tracker/` | Game data + 1,734 images extracted from the tracker APK |
| `docs/` | GitHub Pages: privacy policy and terms |

## Save file access

- Android ≤ 12: Editor › "Allow access to Saves folder" (SAF tree on `Android/data/com.chucklefish.stardewvalley/files/Saves`) → open and write back in place.
- Android 13+: blocked by the OS. In-app guide (Editor › "How do I get my save file?") covers USB/MTP, ADB and Shizuku; edit, "Save as…", copy back.

## Ads (lib/ads/)

| Format | Placement / frequency |
|---|---|
| Banner (anchored adaptive) | Tab screens and editor sections; collapsible banner on detail pages |
| Native (small template) | Inside long lists, after the first few rows then every 12 rows |
| Interstitial | After export / write-back, after import, every 2nd editor-section exit, every 4th detail page, every 5th tab switch — ≥ 2 min apart, not in the first 45 s |
| App open | Cold start (from the 2nd launch) and resume after ≥ 30 s; ≥ 3 h apart; never after pickers/share |
| Rewarded | +4 h ad-free per video (max 24 h); bulk editor tools (max hearts, unlock all recipes, complete room, max skills) unlocked 1 h |

UMP consent runs before any request. Debug builds use Google test units; release uses `lib/ads/ad_ids.dart`.
In-app review is requested after positive moments (`lib/services/review.dart`).

## Localization (lib/l10n/)

- UI: `tr('English text')` → `assets/i18n/<code>.json` (13 languages). Add strings with `tr()`, then
  `python3 -I tools/i18n/extract.py` and `python3 -I tools/i18n/check.py vi ja ko de fr it es pt tr ru zh hu`.
- Game text (items, villagers, schedules, festivals): `assets/tracker/i18n/<code>.json` from the original tracker.
- Fonts: Pixelify Sans; Tiny5 for Vietnamese; DotGothic16 for Japanese; system CJK for Korean/Chinese.

## Store (store/)

- `aso_report.md` – market, keywords, competitors, plan. `listings.json` + `listings/<locale>/` – paste-ready text.
- Screenshots: `tools/store/capture.sh [en,vi,…]` (app built with `--dart-define=SHOTS=true` walks every screen) → `store/screenshots/raw`,
  then `python3 tools/store/compose.py <fusion-pixel-font dir>` → `store/screenshots/<locale>/`.
- Before pasting: `grep -rn -i "free\|best\|#1" store/listings`.

## Release

`android/key.properties` points to the external keystore properties; then:

```bash
flutter build appbundle --release
```

## Before publishing

- Enable GitHub Pages (main branch, /docs) so the privacy policy and terms URLs resolve.
- Play Console: Data safety (AdMob: device IDs, approximate location; no data collected by the app itself), content rating, ads declaration.
