"""Builds compact per-language game-text packs for the app from the extracted
tracker i18n files. Usage: build_i18n.py <i18n_dir> <out_dir>"""
import json, os, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
CODES = {'de-DE': 'de', 'es-ES': 'es', 'fr-FR': 'fr', 'hu-HU': 'hu', 'it-IT': 'it', 'ja-JP': 'ja',
         'ko-KR': 'ko', 'pt-BR': 'pt', 'ru-RU': 'ru', 'tr-TR': 'tr', 'zh-CN': 'zh', 'en-US': 'en'}
APP_PREFIXES = ('walnut_desc_', 'walnut_type_', 'walnut_region_', 'stardrop_', 'crafting_group_', 'crafting_source_',
                'crafting_shop_', 'wearable_', 'recipe_source_', 'villager_region', 'villager_location_', 'location.',
                'fish_behavior_', 'tailoring_tag_', 'mines_floor', 'mining_node', 'house_upgrade_')
APP_KEYS = {'blackberry_season', 'salmonberry_season', 'extra_beach', 'extra_beach_foraging', 'night_market',
            'desert_festival', 'trout_derby', 'squid_fest', 'traveling_cart', 'krobus_splinker', 'queen_of_sauce',
            'ancient_seed_string', 'mines_tilling', 'mutant_bug_lair', 'witch_swamp', 'oasis', 'traveling_merchant'}
for f in sorted(os.listdir(src)):
    loc = f[:-5]
    code = CODES.get(loc)
    if not code:
        continue
    d = json.load(open(os.path.join(src, f)))
    app = {k: v for k, v in d['app'].items() if k.startswith(APP_PREFIXES) or k in APP_KEYS}
    pack = {'text': d['text'], 'festivals': d['festivalDates'], 'schedules': d['schedules'], 'app': app}
    p = os.path.join(out, code + '.json')
    json.dump(pack, open(p, 'w'), ensure_ascii=False, separators=(',', ':'))
    print(code, os.path.getsize(p) // 1024, 'KB')
