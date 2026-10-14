import json, os, sys, collections
D = sys.argv[1]; out = sys.argv[2]; header = open(sys.argv[3]).read()
DESC = {
 'items.json': 'All objects (category "O") from the game data, with English name/description, category, price, edibility, context tags, buffs, geode drops, artifact-spot chances and where-to-find entries (forage/fishing/artifact).',
 'big_craftables.json': 'Big craftables (machines etc.). Only 63 of 183 have an icon in the app.',
 'furniture.json': 'Furniture list (the app ships no furniture icons).',
 'crops.json': 'Crops keyed by seed: growth phases, seasons, regrow, harvest item, seed/harvest prices, gold/day (cropsPriceDay).',
 'fish.json': 'Fish (rod + crab-pot/trap): behavior, difficulty, seasons, weather, time windows, fishing level, sizes, XP per quality, locations, aquarium behavior, special location text.',
 'villagers.json': 'All NPCs incl. non-social: birthday, datable, gender/age/personality, home(s), relationships text, gift tastes (love/like/neutral/dislike/hate items + context tags + reaction line), icon/portrait.',
 'universal_gift_tastes.json': 'Universal love/like/neutral/dislike/hate item lists.',
 'villager_schedules.json': 'Raw villager schedules (per schedule key: season/day/weekday/rain/marriage/friendship conditions, stops with time+location+tile and English stop description) + schedule variants + home display keys + raw English location text map.',
 'bundles.json': 'Community Center rooms -> bundles (normal + remixed), items with quantity/quality, number of items required, rewards, room reward text, bundle icon.',
 'cooking_recipes.json': 'Cooking recipes (81): ingredients, unlock condition (friendship/skill/TV/starter), Queen of Sauce air date, purchase sources, buffs, icon.',
 'crafting_recipes.json': 'Crafting recipes (150) grouped into 17 app groups; ingredients, output, source (skill level, shop, mail, manual text, starter).',
 'buildings.json': 'Farm buildings (Robin/Wizard): cost, materials, build days, upgrade-from, size, occupants, icon.',
 'monsters.json': 'Monsters with stats and loot drops (chance).',
 'wearables.json': 'Hats, shirts, pants, boots, rings, trinkets: sell/purchase price, stats, effects, how-to-obtain sources (shop/tailoring/manual/hat mouse/crafting/character creation), tailoring recipes, icon.',
 'museum.json': 'Museum collection lists: artifacts, foraged minerals, gems, geode minerals, geodes, with where-to-find; plus geode contents and artifact trove contents.',
 'shipping.json': 'Items that count for the shipping collection (app order).',
 'golden_walnuts.json': 'Ginger Island golden walnut locations (60 entries) with quantity, region, kind, English description and location image.',
 'stardrops.json': 'The 7 stardrops with English source text.',
 'calendar.json': 'Festivals, villager birthdays, passive festivals (Night Market, Desert Festival, Trout Derby, Squid Fest), seasonal calendar dates (blackberry/salmonberry season, extra beach...), Queen of Sauce schedule.',
 'shops.json': 'Shop inventories from game data (SeedShop/Pierre, Joja, Sandy/Oasis, Traveler cart, Night Market boats) and the app\'s seed-store / Joja / night market / oasis / traveling cart item lists.',
 'mining.json': 'Mining nodes, mine tilling drops, panning drops, treasure chest items, trash items.',
 'constants.json': 'App constants: locales & flags, seasons, weekdays, quality multipliers, category names, ordered id lists (allFish, allCrops, allRecipes, shippingItems...), display orders, location display names, store/contact URLs.',
 'images_map.json': 'The app\'s IMAGES map: image key (O<id>, BO<id>, H/S/P/B<id>, TR<id>, <Villager>, <Villager>_Icon, <Room>/<bundleId>, building name, walnut-location-N, icon names) -> drawable basename.',
}
def tname(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'bool'
    if isinstance(v, int): return 'int'
    if isinstance(v, float): return 'number'
    if isinstance(v, str): return 'string'
    if isinstance(v, list): return 'list'
    return 'object'
def schema(recs):
    f = collections.OrderedDict()
    for r in recs:
        if not isinstance(r, dict): continue
        for k, v in r.items():
            f.setdefault(k, collections.Counter())[tname(v)] += 1
    return f
def records(d):
    """returns list of (label, records list)"""
    if isinstance(d, list): return [('', d)]
    out = []
    if d and all(str(k).startswith('Universal_') for k in d):
        return [('(top-level dict values, keyed by %s)' % ', '.join(list(d)[:6]), list(d.values()))]
    for k, v in d.items():
        if isinstance(v, list) and v and isinstance(v[0], dict): out.append((k, v))
        elif isinstance(v, dict) and v and all(isinstance(x, list) for x in v.values()) and k in ('schedules', 'shops'):
            out.append((k + ' (flattened entries)', [e for l in v.values() for e in l]))
        elif isinstance(v, dict) and v and all(isinstance(x, dict) for x in v.values()) and k not in ('locationText',):
            out.append((k + ' (dict values)', list(v.values())))
    return out
def sample(r, n=1400):
    s = json.dumps(r, ensure_ascii=False, indent=1)
    if len(s) > n:
        s = s[:n] + '\n ... (truncated)'
    return s
L = [header]
for f in sorted(os.listdir(D)):
    if not f.endswith('.json'): continue
    d = json.load(open(os.path.join(D, f)))
    size = os.path.getsize(os.path.join(D, f))
    L.append('\n## `%s`\n' % f)
    L.append(DESC.get(f, '') + '\n')
    if isinstance(d, list):
        L.append('- Top level: list, **%d records** (%d KB)\n' % (len(d), size // 1024))
    else:
        L.append('- Top level: object with keys: %s (%d KB)\n' % (', '.join('`%s`%s' % (k, '[%d]' % len(v) if isinstance(v, (list, dict)) else '') for k, v in d.items()), size // 1024))
    if f == 'images_map.json': L.append('- %d keys\n' % len(d)); L.append('\n```json\n' + json.dumps(dict(list(d.items())[:6]), indent=1) + '\n```\n'); continue
    for label, recs in records(d):
        if f == 'bundles.json' and label in ('normal', 'remixed'):
            L.append('\n### `%s` rooms (%d rooms, %d bundles)\n' % (label, len(recs), sum(len(r['bundles']) for r in recs)))
            sc = schema(recs); L.append('| field | types |\n|---|---|\n' + ''.join('| `%s` | %s |\n' % (k, ', '.join('%s(%d)' % x for x in v.items())) for k, v in sc.items()))
            bl = [b for r in recs for b in r['bundles']]
            sc = schema(bl); L.append('\nBundle record fields:\n\n| field | types |\n|---|---|\n' + ''.join('| `%s` | %s |\n' % (k, ', '.join('%s(%d)' % x for x in v.items())) for k, v in sc.items()))
            L.append('\nSample bundle:\n```json\n' + sample(bl[0]) + '\n```\n')
            continue
        if f == 'crafting_recipes.json' and label == 'recipes' or True:
            pass
        L.append('\n### %s%d records\n' % (('`%s`: ' % label) if label else '', len(recs)))
        sc = schema(recs)
        L.append('| field | types (count) |\n|---|---|\n' + ''.join('| `%s` | %s |\n' % (k, ', '.join('%s(%d)' % x for x in v.items())) for k, v in sc.items()))
        pick = recs[0]
        pref = {'items.json': ('id', '24'), 'villagers.json': ('id', 'Abigail'), 'big_craftables.json': ('id', '10')}.get(f)
        if pref:
            for r in recs:
                if isinstance(r, dict) and r.get(pref[0]) == pref[1]: pick = r; break
        L.append('\nSample:\n```json\n' + sample(pick, 2500 if f in ('items.json', 'villagers.json', 'fish.json') else 1400) + '\n```\n')
open(out, 'w').write(''.join(L))
print('ok')
