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
