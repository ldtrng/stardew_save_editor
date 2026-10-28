# Tools

## `tracker_extract/` – regenerate tracker game data

Rebuilds `assets/tracker/data/*.json` and `assets/tracker/img/` from a *Stardew Valley Tracker* `.xapk`
(e.g. after a game/tracker update).

```bash
tools/tracker_extract/run.sh Stardew+Valley+Tracker_5.3.5_APKPure.xapk
```

Steps: unzip xapk → `hbc-decompiler` (P1sec/hermes-dec, installed into a venv in the work dir) →
`split_modules.py` (Metro module table) → `assets_map.py` (asset module → drawable) →
`build_data.py` (evaluates the data modules **as text**, nothing from the APK is executed; uses `hermeval.py`) →
`validate.py` (reports unresolved names/images) → copy into `assets/`.

Env: `DEST=/some/dir` writes there instead of the project; 2nd argument = reusable work dir.
Helpers for investigating new versions: `dump_module.py`, `scan_exports.py`, `scan_data.py`, `modsummary.py`,
`peek.py`, `shape.py`, `gen_index.py` / `gen_assets.py` (rewrite the notes in `research/`).

## `make_icon.py` – launcher icon

```bash
python3 -m pip install pillow
```

```bash
python3 tools/make_icon.py android/app/src/main/res
```

## `docs/` – privacy policy & terms (GitHub Pages)

Pages is served from the `gh-pages` branch, which mirrors `docs/`. After editing `docs/` and committing on main:

```bash
git subtree split --prefix docs -b gh-pages && git push origin gh-pages
```

(If an existing local `gh-pages` branch is behind, delete it first with `git branch -D gh-pages`.)

## `firebase/remote_config_template.json` – Remote Config parameters

Firebase project `sv-tracker-8a3f1`. The template mirrors `RemoteSettings.defaults` in `lib/services/firebase.dart`
(ad pacing and review prompt). Keep both in sync when adding a parameter. The console's "Publish from a file" can import it.

## Publishing to Google Play (`android/fastlane`)

```bash
cd android
fastlane prepare      # lay out build/play_metadata from store/ (no upload)
fastlane validate     # check the service-account key can reach the app
fastlane internal     # build the bundle, upload to the internal track (binary + release notes)
fastlane production   # build, upload to production and send for review (status:draft to keep a draft); binary + release notes only
fastlane listing      # listing text only (title, descriptions), no binary
fastlane screenshots  # screenshots, feature graphic and icon only, no binary
fastlane metadata     # listing text + screenshots + images, no binary
```

The upload lanes (`internal`, `production`) never touch the listing or screenshots; use `listing`, `screenshots`
or `metadata` for those. Release notes come from `store/release_notes/<versionName>.txt` and ride with the release.
Run fastlane with a UTF-8 locale (`LC_ALL=en_US.UTF-8`), or reading the Japanese/Korean notes fails.

The service-account key `play-publisher@sv-tracker-8a3f1.iam.gserviceaccount.com` lives **outside the repo** at
`~/Documents/ldtr_key_storage/play-service-account.json` (override with `SUPPLY_JSON_KEY`). It is a Google Cloud key
(project `sv-tracker-8a3f1`, Google Play Android Developer API enabled); what it may do is set in Play Console →
Users and permissions for the LD2T developer account, per app or account-wide.

Reuse for other apps of the same developer account: point their `Appfile` at the same key
(`json_key_file(File.expand_path('~/Documents/ldtr_key_storage/play-service-account.json'))`) and set their own
`package_name`; the service account only needs the app (or account) permissions in Play Console.
Never commit the JSON; `.gitignore` already blocks `*-service-account*.json`.
