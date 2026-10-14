import json, os, sys, collections
SCR = sys.argv[1]
F = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'asset_folders.json')))
A = json.load(open(SCR + '/tools/assets.json'))
IMG = json.load(open(SCR + '/analysis/data/images_map.json'))
res = SCR + '/base/res'
draw = sorted(os.listdir(res + '/drawable-mdpi-v4'))
src = [d for d in draw if d.startswith('src_assets_')]
used = set(IMG.values())
L = ['# Image & asset inventory\n\n',
 'Source: `base/res/` of the APK (Metro/Expo bundles `require()`d images as Android drawables) plus the asset-registration modules in `dec/out.js` (`{httpServerLocation, width, height, scales, name, type}`), mapped by `tools/assets_map.py` -> `tools/assets.json` (module id -> path/drawable).\n\n',
 '## Resolution variants\n\n',
 '| folder | app images (`src_assets_*`) | other |\n|---|---|---|\n']
for d in sorted(os.listdir(res)):
    if not (d.startswith('drawable') or d.startswith('mipmap')): continue
    fs = os.listdir(res + '/' + d)
    n = sum(1 for f in fs if f.startswith('src_assets_'))
    L.append('| `%s` | %d | %d (%s) |\n' % (d, n, len(fs) - n, ', '.join(sorted(set(os.path.splitext(f)[1] for f in fs if not f.startswith('src_assets_')))) or '-'))
L.append('\n* **Every app image exists in exactly one density: `drawable-mdpi-v4` (1x).** All 1,743 `src/assets` registrations declare `scales: [1]`; only the 4 react-navigation icons have `[1,2,3,4]` variants (in `drawable-*` they are absent/hdpi only). There are no hdpi/xhdpi/xxhdpi copies of game sprites — the sprites are small pixel-art PNGs (mostly 48x48) and should be rendered with nearest-neighbour filtering (`FilterQuality.none`) when scaled in Flutter.\n')
L.append('* `drawable-mdpi-v4` holds %d files: %d `src_assets_*` images (%s) + %d library drawables.\n' % (len(draw), len(src), ', '.join('%d %s' % (v, k) for k, v in collections.Counter(os.path.splitext(f)[1] for f in src).items()), len(draw) - len(src)))
L.append('* `src/assets/laurel_wreath.svg` is shipped as `res/raw/src_assets_laurel_wreath.svg` (SVG used via react-native-svg).\n')
L.append('* Launcher icon: `mipmap-{m,h,xh,xxh,xxxh}dpi-v4/ic_launcher.webp` + `ic_launcher_foreground.webp` (from `src/assets/android_icon_fall_old.png`). Splash: same image, bg `#f1f5f9` light / `#1e293b` dark (app.config).\n')
L.append('* Fonts (`res/raw`): Poppins (all 18 weights/italics; app uses `Poppins_400Regular`, `Poppins_600SemiBold`, `Poppins_400Regular_Italic`) and `MaterialCommunityIcons.ttf` (icon font used throughout the UI, e.g. `checkbox-marked-circle`, `image-off-outline`, `arrow-left`).\n')
L.append('\n## Naming rule\n\nMetro path `src/assets/<dir>/<File-Name>.png` -> drawable `src_assets_<dir>_<filename>` = path lower-cased, `/` -> `_`, then every char outside `[a-z0-9_]` removed (so `24px-Gold_Quality_Icon` -> `24pxgold_quality_icon`, `walnut-location-1` -> `walnutlocation1`, `Fish Farmer\'s` -> `fish_farmers`).\n')
L.append('\n## Folder structure (`src/assets/...`)\n\n| folder (drawable prefix) | files | types | common sizes (px) | examples | used as image keys |\n|---|---|---|---|---|---|\n')
KEYS = {'src/assets': 'quality stars, skill/buff icons (`silver_quality`, `farming_skill`, `luck_icon`, `gold_coin`, `event_flag`, `quest`, `time`, `Shipping Box`, ...)',
        'src/assets/ads': 'cross-promo banners (`constants.selfPromoBanners[].icon`)',
        'src/assets/big_craftables': '`BO<id>`', 'src/assets/buildings': 'building name (`Barn`, `Big Coop`, `House (tier 2)`...)',
        'src/assets/bundles': 'bundle key `<Room>/<id>` (normal + remixed)', 'src/assets/items': '`O<id>` (file name = zero-padded id, or string id e.g. `moss`)',
        'src/assets/objects': '`Calendar`', 'src/assets/onboarding': '`onboarding_1..3` (1242x1344 screenshots)', 'src/assets/sprites': '`items` (springobjects sprite sheet 384x624, 24x? grid — used by `Sprite` component)',
        'src/assets/villagers': '`<Name>` (128px portrait) and `<Name>_Icon` (32px)', 'src/assets/walnuts': '`walnut-location-<n>` (60 keys -> 55 files, some shared)',
        'src/assets/wearables/boots': '`B<id>`', 'src/assets/wearables/hats': '`H<id>` / `H<Name>`', 'src/assets/wearables/pants': '`P<id>`',
        'src/assets/wearables/shirts': '`S<id>` / `S<Name>`', 'src/assets/wearables/trinkets': '`TR<Name>`'}
tot = 0
for k, v in F.items():
    tot += v['n']
    pref = 'src_assets_' + k[len('src/assets/'):].replace('/', '_') + '_' if k != 'src/assets' else 'src_assets_'
    L.append('| `%s` (`%s*`) | %d | %s | %s | %s | %s |\n' % (k, pref, v['n'], ', '.join('%s:%d' % x for x in v['types'].items()), ', '.join('%s(%d)' % x for x in v['dims'].items()), ', '.join('`%s`' % e for e in v['ex'] if e), KEYS.get(k, '')))
L.append('| **total** | | **%d** | | | | |\n' % tot)
L.append('\nRings have no separate folder: ring wearables use the item sprite `O<id>` (e.g. `O517` -> `src_assets_items_517`). Furniture has no images at all; only 63 of 183 big craftables and 25 buildings (no Farmhouse/Greenhouse) have images. 35 objects (e.g. Slime Crate, Camping Stove, Sea/River/Cave Jelly, Golden Tag) have no `O<id>` image.\n')
L.append('\n## Image key -> drawable map\n\n`analysis/data/images_map.json` (1,768 keys, 1,737 distinct drawables). Every JSON record\'s `image` field is already resolved through this map. Drawables never referenced by `IMAGES`: %s.\n' % ', '.join('`%s`' % d for d in sorted(set(os.path.splitext(x)[0] for x in src) - used)))
L.append('\nCopy command for the Flutter project (example):\n\n```sh\nmkdir -p assets/img && cp base/res/drawable-mdpi-v4/src_assets_* assets/img/\n```\n')
s = "".join(L)
open(SCR + '/analysis/assets.md', 'w').write(''.join(L))
print('ok')
