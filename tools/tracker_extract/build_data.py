"""Builds clean JSON game-data files from the decoded hermes modules. Input files are data only."""
import json, os, sys, re, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hermeval
SCR = os.environ.get('SDV_WORK') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = SCR + '/analysis/data'
os.makedirs(OUT, exist_ok=True); os.makedirs(OUT + '/i18n', exist_ok=True)
B = hermeval.Bundle(SCR + '/dec/out.js', SCR + '/tools/modules.json', SCR + '/tools/assets.json')
def mod(mid):
    exp, clos, unk = B.eval(mid)
    return hermeval.tojson(exp, lambda r: r.val if r.kind == 'asset' else None)
G = mod(3190)
C = mod(3206)          # app constants (lists of ids)
K = mod(3189)          # misc constants
IMG = mod(1376)['IMAGES']
WAL = mod(3316)['walnutLocations']
STAR = mod(3317)['stardrops']
VD = mod(3204)
CRAFT = mod(3236)
PROMO = mod(3375).get('SELF_PROMO_BANNERS')
LOCALES = K['locales']
I18N = {}
for i, loc in enumerate(LOCALES):
    d = mod(3192 + i)
    I18N[loc] = d
    json.dump(d, open('%s/i18n/%s.json' % (OUT, loc), 'w'), ensure_ascii=False, indent=1)
EN = I18N['en-US']
ORDER = ['text', 'app', 'cs', 'ui', 'locations', 'objects', 'buildings', 'festivalDates']
def T(key, default=None):
    if key is None: return default
    for d in ORDER:
        if key in EN.get(d, {}): return EN[d][key]
    return default
def img(key):
    return IMG.get(key)

CAT = {-2:'Gem',-4:'Fish',-5:'Egg',-6:'Milk',-7:'Cooking',-8:'Crafting',-9:'Big Craftable',-12:'Mineral',-14:'Meat',
       -15:'Metal Resource',-16:'Building Resource',-17:"Sell at Pierre's",-18:"Sell at Pierre's and Marnie's",-19:'Fertilizer',
       -20:'Junk',-21:'Bait',-22:'Fishing Tackle',-23:"Sell at Fish Shop",-24:'Decor',-25:'Cooking Ingredient',
       -26:'Artisan Goods',-27:'Syrup',-28:'Monster Loot',-29:'Equipment',-74:'Seed',-75:'Vegetable',-79:'Fruit',
       -80:'Flower',-81:'Forage',-95:'Hat',-96:'Ring',-97:'Boots',-98:'Weapon',-99:'Tool',-100:'Clothing',-101:'Trinket',
       -102:'Book',-103:'Skill Book',-999:'Litter',0:'None'}
# The app's own "any X" ingredient labels (from i18n cs dict when present)
OBJ, BIG, FURN, WEAR = G['objects'], G['bigCraftables'], G['furniture'], G['wearables']

def item_ref(iid, typ='O', extra=None):
    """Resolve an item id/type to {id,type,name,image}."""
    r = {}
    if typ == 'BC': typ = 'BO'
    if typ == 'R': typ = 'O_RING'
    if typ in ('O', None) and str(iid) not in OBJ:
        if '(O)%s' % iid in WEAR: typ = 'O_RING'
        elif str(iid) in BIG and not str(iid).startswith('-'): typ = 'BO'
    try: n = int(iid)
    except (TypeError, ValueError): n = None
    if n is not None and n < 0 and typ in ('O', None):
        r = {'category': n, 'name': CAT.get(n, 'Category %d' % n)}
        rep = {-5: ('176', 'Egg (Any)'), -6: ('184', 'Milk (Any)'), -4: ('145', T('recipe_ingredient_any_fish')), -777: (None, 'Wild Seeds (Any)')}.get(n)
        if rep:
            r['anyName'] = rep[1]; r['displayItemId'] = rep[0]; r['image'] = img('O' + rep[0]) if rep[0] else None
    elif typ in ('O', None):
        o = OBJ.get(str(iid))
        r = {'id': str(iid), 'type': 'O', 'name': T(o['nameKey']) if o else None, 'image': img('O%s' % iid)}
    elif typ == 'BO':
        o = BIG.get(str(iid))
        r = {'id': str(iid), 'type': 'BO', 'name': T(o['nameKey']) if o else None, 'image': img('BO%s' % iid)}
    elif typ == 'F':
        o = FURN.get(str(iid))
        r = {'id': str(iid), 'type': 'F', 'name': T(o['nameKey']) if o else None, 'image': None}
    elif typ == 'O_RING':
        w = WEAR.get('(O)%s' % iid)
        r = {'id': str(iid), 'type': 'O', 'name': T(w['nameKey']) if w else None, 'image': img(w['imageKey']) if w else None}
    else:
        w = WEAR.get('(%s)%s' % (typ, iid))
        r = {'id': str(iid), 'type': typ, 'name': T(w['nameKey']) if w else None, 'image': img(w['imageKey']) if w else None}
    if extra: r.update(extra)
    return r

def dump(name, data, meta=None):
    json.dump(data, open('%s/%s.json' % (OUT, name), 'w'), ensure_ascii=False, indent=1)

def strip_prefix_keys(d): return d

LOCMAP = {'NightMarket': ('ui', 'Billboard_NightMarket'), 'Farm': ('cs', 'MapPage.cs.11064'), 'UndergroundMine': ('locations', 'MineCart_Destination_Mines'),
          'Desert': ('cs', 'MapPage.cs.11062'), 'Beach': ('cs', 'MapPage.cs.11174'), 'Mountain': ('cs', 'MapPage.cs.11176'),
          'Forest': ('cs', 'MapPage.cs.11186'), 'Town': ('locations', 'MineCart_Destination_Town'), 'BusStop': ('locations', 'MineCart_Destination_BusStop'),
          'Railroad': ('cs', 'MapPage.cs.11119'), 'Woods': ('cs', 'MapPage.cs.11114'), 'Sewer': ('cs', 'MapPage.cs.11089'),
          'MutantBugLair': ('app', 'mutant_bug_lair'), 'BugLand': ('app', 'mutant_bug_lair'), 'GingerIslands': ('cs', 'IslandName'),
          'Backwoods': ('cs', 'MapPage.cs.11065'), 'WitchSwamp': ('app', 'witch_swamp'), 'fishing': ('ui', 'Character_fishing'),
          'forage': ('ui', 'Character_foraging'), 'Temp': ('app', 'location_festival')}
def locname(x):
    if x == 'artifact': return T('objects.590.name')
    if x in LOCMAP:
        d, k = LOCMAP[x]; v = EN.get(d, {}).get(k)
        if v and x == 'Farm': v = v.replace('{0} ', '')
        return v
    return x
# ---------- item locations (forage / fishing / artifact spots) ----------
def loc_entries(iid):
    out = []
    for e in G['locations'].get(str(iid), []):
        out.append({k: e[k] for k in ('method', 'location', 'displayLocation', 'chance', 'seasons', 'weather', 'time',
                                      'minFishingLevel', 'isBossFish', 'requireMagicBait', 'conditions', 'festivalGate',
                                      'fishAreaId', 'minDistanceFromShore', 'maxDistanceFromShore', 'provenance') if k in e})
        out[-1]['displayLocationName'] = locname(e.get('displayLocation'))
        out[-1]['methodName'] = locname(e.get('method'))
    return out

# ---------- items ----------
items = []
for k, o in OBJ.items():
    rec = {
        'id': k, 'internalName': o['internalName'], 'name': T(o['nameKey']), 'description': T(o['descriptionKey']),
        'type': o['type'], 'category': o['category'], 'categoryName': CAT.get(o['category']),
        'price': o['price'], 'edibility': o['edibility'], 'isFood': o.get('isFood'), 'isDrink': o.get('isDrink'),
        'contextTags': o.get('contextTags') or [], 'buffs': o.get('buffs') or [],
        'acquisitionBuffs': G['acquisition']['buffs'].get(o['internalName']),
        'geodeDrops': o.get('geodeDrops') or [], 'geodeDropsDefaultItems': o.get('geodeDropsDefaultItems'),
        'artifactSpotChances': o.get('artifactSpotChances') or {},
        'excludeFromFishingCollection': o.get('excludeFromFishingCollection'),
        'excludeFromShippingCollection': o.get('excludeFromShippingCollection'),
        'excludeFromRandomSale': o.get('excludeFromRandomSale'),
        'locations': loc_entries(k),
        'image': img('O' + k), 'nameKey': o['nameKey'],
    }
    items.append(rec)
dump('items', items)

big = [{'id': k, 'internalName': o['internalName'], 'name': T(o['nameKey']), 'description': T(o['descriptionKey']),
        'price': o['price'], 'fragility': o['fragility'], 'indoors': o['indoors'], 'outdoors': o['outdoors'], 'isLamp': o['isLamp'],
        'image': img('BO' + k), 'nameKey': o['nameKey']} for k, o in BIG.items()]
dump('big_craftables', big)

furn = [{'id': k, 'internalName': o['internalName'], 'name': T(o['nameKey']), 'type': o['type'], 'price': o['price'],
         'rotations': o['rotations'], 'placement': o['placement'], 'sourceSize': o['sourceSize'], 'boundingSize': o['boundingSize'],
         'image': None, 'nameKey': o['nameKey']} for k, o in FURN.items()]
dump('furniture', furn)

# ---------- crops ----------
crops = []
for k, c in G['crops'].items():
    seed = OBJ.get(str(c['seedId'])); harv = OBJ.get(str(c['harvestId']))
    rec = dict(c)
    rec.update({'seed': item_ref(c['seedId']), 'harvest': item_ref(c['harvestId']),
                'name': T(harv['nameKey']) if harv else None,
                'seedPrice': seed['price'] if seed else None, 'harvestSellPrice': harv['price'] if harv else None,
                'totalGrowDays': sum(d for d in c['daysInPhase'] if isinstance(d, int) and d > 0),
                'goldPerDay': C['cropsPriceDay'].get(str(c['harvestId'])),
                'inAllCropsList': c['harvestId'] in C['allCrops'],
                'image': img('O%s' % c['harvestId']), 'seedImage': img('O%s' % c['seedId'])})
    crops.append(rec)
dump('crops', crops)

# ---------- fish ----------
fish = []
for k, f in G['fish'].items():
    o = OBJ.get(k, {})
    rec = {'id': k, 'internalName': f['internalName'], 'name': T(f['nameKey']), 'description': T(o.get('descriptionKey')),
           'type': f['type'], 'behavior': f.get('behavior'), 'difficulty': f.get('difficulty'),
           'minSize': f.get('minSize'), 'maxSize': f.get('maxSize'), 'fishingLevel': f.get('fishingLevel'),
           'seasons': f.get('season'), 'weather': f.get('weather'), 'time': f.get('time'),
           'trapLocation': f.get('location'), 'experience': f.get('experience'),
           'price': o.get('price'), 'edibility': o.get('edibility'), 'category': o.get('category'),
           'aquarium': G['aquariumFish'].get(k), 'inAllFishList': int(k) in C['allFish'], 'isCrabPot': int(k) in C['crabPotFish'],
           'locations': [e for e in loc_entries(k)], 'locationText': EN['app'].get('location.' + k),
           'image': img('O' + k)}
    fish.append(rec)
# order like the app's allFish list
order = {str(x): i for i, x in enumerate(C['allFish'])}
fish.sort(key=lambda r: order.get(r['id'], 9999))
dump('fish', fish)

# ---------- villagers ----------
def taste_list(t):
    if not t: return None
    return {'items': [item_ref(i) for i in t.get('items', [])], 'tags': t.get('tags', []), 'reaction': T(t.get('textKey'))}
villagers = []
sched_names = set(G['schedules'].keys())
for k, v in G['villagers'].items():
    gt = G['giftTastes'].get(k, {})
    rec = {'id': k, 'name': T(v['nameKey']),
           'birthday': {'season': v['birthday']['season'], 'day': int(v['birthday']['day']) if str(v['birthday']['day']).isdigit() else v['birthday']['day']},
           'datable': v['datable'], 'gender': v['gender'], 'age': v['age'], 'manners': v['manners'], 'anxiety': v['anxiety'],
           'optimism': v['optimism'], 'homeRegion': v['home_region'], 'homes': v['homes'], 'love': v['love'],
           'canSocialize': v['canSocialize'], 'socialTab': v['socialTab'], 'calendar': v['calendar'],
           'relationships': [{'npc': r['npc'], 'text': T(r['relationKey'])} for r in v.get('relationships', [])],
           'gifts': {t: taste_list(gt.get(t)) for t in ('love', 'like', 'neutral', 'dislike', 'hate')} if gt else None,
           'homeRegionText': (lambda x: EN.get(x['source'], {}).get(x['key']) if x else None)(VD['VILLAGER_REGION_DISPLAY_KEYS'].get(v['home_region'])),
           'homeLocationText': (lambda x: EN.get(x['source'], {}).get(x['key']) if x else None)(VD['VILLAGER_HOME_DISPLAY_KEYS'].get((v['homes'] or [{}])[0].get('Location'))),
           'hasSchedule': k in sched_names, 'inAllVillagers': k in C['allVillagers'],
           'image': img(k + '_Icon'), 'portrait': img(k)}
    villagers.append(rec)
dump('villagers', villagers)
uni = {k: taste_list(G['giftTastes'][k]) for k in G['giftTastes'] if k.startswith('Universal_')}
for k in uni:  # universal entries have a flat structure
    gt = G['giftTastes'][k]
    if 'items' not in gt:
        uni[k] = {t: taste_list(x) for t, x in gt.items()}
dump('universal_gift_tastes', uni)

# ---------- schedules ----------
sched_txt = EN.get('schedules', {})
schedules = {}
for k, lst in G['schedules'].items():
    if k == 'template': continue
    out = []
    for e in lst:
        r = dict(e)
        r['schedule'] = [dict(s, description=sched_txt.get(k, {}).get(s['location'], {}).get(s['cords']) if s.get('cords') else None) for s in e['schedule']]
        out.append(r)
    schedules[k] = out
dump('villager_schedules', {'variants': C.get('SCHEDULE_VARIANTS'), 'marriageSchedule': C.get('MARRIAGE_SCHEDULE'),
                            'villagerHomeDisplayKeys': {k: dict(v, text=EN.get(v['source'], {}).get(v['key'])) for k, v in VD.get('VILLAGER_HOME_DISPLAY_KEYS').items()},
                            'villagerRegionDisplayKeys': {k: dict(v, text=EN.get(v['source'], {}).get(v['key'])) for k, v in VD.get('VILLAGER_REGION_DISPLAY_KEYS').items()},
                            'schedules': schedules, 'locationText': sched_txt})

# ---------- bundles ----------
def bundle_rec(key, b):
    vault = b.get('isVault')
    def it(x):
        if vault: return {'gold': x['id'], 'amount': x['amount']}
        r = item_ref(x['id'], x.get('type', 'O'))
        r.update({'amount': x['amount'], 'quality': x['quality']})
        return r
    rec = {'key': key, 'room': key.split('/')[0], 'name': T(b['nameKey']), 'internalName': b['internalName'],
           'color': b['color'], 'isVault': vault, 'numOfItems': b['numOfItems'],
           'items': [it(x) for x in b['items']],
           'reward': (item_ref(b['reward']['id'], b['reward']['type'], {'amount': b['reward']['amount']}) if b.get('reward') else None),
           'image': img(key)}
    if 'groups' in b: rec['groups'] = [[it(x) for x in g] for g in b['groups']]
    if 'pick' in b: rec['pick'] = b['pick']
    return rec
def rooms(lst, src):
    out = []
    for r in lst:
        out.append({'id': r['id'], 'name': T(r['name']), 'reward': T(r['reward']), 'nameKey': r['name'], 'rewardKey': r['reward'],
                    'bundles': [bundle_rec(k, src[k]) if k in src else {'key': k, 'missing': True} for k in r['bundles']]})
    return out
dump('bundles', {'normal': rooms(C['bundlesRooms'], G['bundles']['normal']),
                 'remixed': rooms(C['remixedBundlesRooms'], G['bundles']['remixed']),
                 'bundleItemSaveIds': G['bundleItemSaveIds']})

# ---------- cooking ----------
cook = []
for k, r in G['recipes'].items():
    o = OBJ.get(str(r['itemId']), {})
    cook.append({'id': str(r['itemId']), 'internalName': r['internalName'], 'name': T(r['nameKey']),
                 'description': T(o.get('descriptionKey')), 'quantity': r['quantity'],
                 'ingredients': [item_ref(i['item'], 'O', {'amount': i['amount']}) for i in (r['ingredients'] or [])],
                 'unlock': r['unlock'], 'queenOfSauce': G['acquisition']['queenOfSauce'].get(r['internalName']),
                 'price': o.get('price'), 'edibility': o.get('edibility'),
                 'buffs': G['acquisition']['buffs'].get(r['internalName']),
                 'image': img('O%s' % r['itemId'])})
SPECIAL = {'Omelet': ' (100g)', 'Pizza': ' (150g)', 'Pancakes': ' (100g)', 'Bread': ' (100g)', 'Maki Roll': ' (300g)', 'Triple Shot Espresso': ' (5000g)'}
SPECIAL_KEY = {'Ginger Ale': 'recipe_source_ginger_ale', 'Banana Pudding': 'recipe_source_banana_pudding', 'Tropical Curry': 'recipe_source_tropical_curry'}
SKILL = {'Farming': 'farming_skill', 'Foraging': 'foraging_skill', 'Fishing': 'fishing_skill', 'Mining': 'mining_skill', 'Combat': 'combat_skill'}
SEASONS = ['spring', 'summer', 'fall', 'winter']
for r in cook:
    u = r['unlock'] or {}; cond = u.get('condition') or []; srcs = []
    if cond[:1] == ['default']: srcs.append({'kind': 'starter', 'text': T('recipe_source_starter')})
    elif cond[:1] == ['f']: srcs.append({'kind': 'friendship', 'villager': cond[1], 'hearts': u.get('level'), 'text': '%s (%s❤️)' % (T('villagers.%s.name' % cond[1], cond[1]), u.get('level')), 'image': img(cond[1] + '_Icon')})
    elif cond[:1] == ['s']: srcs.append({'kind': 'skill', 'skill': cond[1], 'level': u.get('level'), 'text': '%s level %s' % (cond[1], u.get('level')), 'image': img(SKILL.get(cond[1], ''))})
    elif cond[:1] == ['l'] and r['queenOfSauce']:
        q = r['queenOfSauce']
        srcs.append({'kind': 'queenOfSauce', 'text': T('queen_of_sauce'), 'date': q, 'dateText': ('%s %s, Year %s' % (SEASONS[q['season']].capitalize(), q['day'], q['year'])) if q else None})
    if r['internalName'] in SPECIAL: srcs.append({'kind': 'purchase', 'text': "Stardrop Saloon" + SPECIAL[r['internalName']], 'note': 'app shows gold_coin icon + price; saloon assumed'})
    if r['internalName'] in SPECIAL_KEY: srcs.append({'kind': 'purchase', 'text': T(SPECIAL_KEY[r['internalName']])})
    r['sources'] = srcs
order = {str(x): i for i, x in enumerate(C['allRecipes'])}
cook.sort(key=lambda r: order.get(r['id'], 9999))
dump('cooking_recipes', cook)

# ---------- crafting ----------
craft = []
for k, r in G['crafting'].items():
    out = r['output']
    craft.append({'key': k, 'internalName': r['internalName'], 'name': T(r['nameKey']), 'group': r['group'], 'order': r['order'],
                  'output': item_ref(out['id'], out['type'], {'quantity': r['quantity']}),
                  'ingredients': [item_ref(i['item'], i.get('type', 'O'), {'amount': i['amount']}) for i in r['ingredients']],
                  'source': dict(r['source'], text=T(r['source'].get('textKey')) if r['source'].get('textKey') else None),
                  'image': img(('BO' if out['type'] == 'BO' else 'O') + str(out['id']))})
craft.sort(key=lambda r: (CRAFT['CRAFTING_GROUP_IDS'].index(r['group']) if r['group'] in CRAFT['CRAFTING_GROUP_IDS'] else 99, r['order']))
dump('crafting_recipes', {'groups': [{'id': g, 'name': T('crafting_group_' + g), 'image': img(CRAFT['CRAFTING_GROUP_IMAGES'][g]),
                                      'imageKey': CRAFT['CRAFTING_GROUP_IMAGES'][g]} for g in CRAFT['CRAFTING_GROUP_IDS']],
                          'recipes': craft})

# ---------- buildings ----------
bl = []
for name in G['displayOrder']['buildings']:
    b = G['buildings'][name]
    bl.append({'id': name, 'name': T(b['nameKey']), 'description': T(b['descriptionKey']), 'builder': b['builder'],
               'buildCost': b['buildCost'], 'buildDays': b['buildDays'],
               'buildMaterials': [item_ref(m['id'], m['type'], {'amount': m['amount']}) for m in (b['buildMaterials'] or [])],
               'buildingToUpgrade': b['buildingToUpgrade'], 'buildCondition': b['buildCondition'], 'size': b['size'],
               'maxOccupants': b['maxOccupants'], 'validOccupantTypes': b['validOccupantTypes'], 'hayCapacity': b['hayCapacity'],
               'image': img(name)})
dump('buildings', bl)

# ---------- monsters ----------
ml = []
for name in G['displayOrder']['monsters']:
    m = G['monsters'][name]
    r = {'id': name, 'name': T(m['nameKey'])}
    r.update({k: v for k, v in m.items() if k not in ('nameKey', 'drops')})
    r['drops'] = [item_ref(d['id'], 'O', {'chance': d['chance']}) for d in (m['drops'] or [])]
    ml.append(r)
dump('monsters', ml)

# ---------- wearables ----------
wl = []
for k, w in WEAR.items():
    r = {'qualifiedId': k, 'id': w['gameId'], 'kind': w['kind'], 'name': T(w['nameKey']), 'description': T(w['descriptionKey']),
         'effect': T(w.get('effectKey')) if w.get('effectKey') else None}
    for f, v in w.items():
        if f in ('nameKey', 'descriptionKey', 'gameId', 'qualifiedId', 'kind', 'effectKey'): continue
        r[f] = v
    srcs = []
    for s in w.get('sources', []):
        s2 = dict(s)
        for tk in ('textKey', 'shopNameKey', 'conditionKey'):
            if s.get(tk): s2[tk.replace('Key', 'Text')] = T(s[tk])
        srcs.append(s2)
    r['sources'] = srcs
    for sub in ('trinket', 'ring'):
        if isinstance(r.get(sub), dict):
            r[sub] = {kk: (dict(vv=vv) and vv) for kk, vv in r[sub].items()}
            for tk in list(r[sub]):
                if tk.endswith('Key') and isinstance(r[sub][tk], str): r[sub][tk[:-3] + 'Text'] = T(r[sub][tk])
    r['image'] = img(w['imageKey'])
    wl.append(r)
dump('wearables', wl)

# ---------- museum ----------
def mlist(ids): return [dict(item_ref(i), locations=loc_entries(i), description=T(OBJ.get(str(i), {}).get('descriptionKey'))) for i in ids]
dump('museum', {'artifacts': mlist(C['allArtifacts']), 'foragedMinerals': mlist(C['foragedMinerals']), 'gems': mlist(C['gems']),
                'geodeMinerals': mlist(C['geodeMinerals']), 'geodes': mlist(C['geodes']),
                'geodeContents': {k: [item_ref(i) for i in v] for k, v in G['geodeContents'].items()},
                'artifactTroveIds': [item_ref(i) for i in C['artifactTroveIds']]})

# ---------- shipping ----------
dump('shipping', [dict(item_ref(i), price=OBJ.get(str(i), {}).get('price'), category=OBJ.get(str(i), {}).get('category')) for i in C['shippingItems']])

# ---------- walnuts / stardrops ----------
wal = []
for w in WAL:
    n = w['id'].split('-')[-1]
    wal.append(dict(w, number=int(n), description=T('walnut_desc_' + n), image=img(w['id'])))
dump('golden_walnuts', wal)
dump('stardrops', [dict(s, text=T(s['textKey'])) for s in STAR])

# ---------- calendar ----------
fest = []
CALKEY = {'blackberrySeason': 'blackberry_season', 'desertFestival': 'desert_festival', 'extraBeach': 'extra_beach', 'nightMarket': 'night_market', 'salmonberrySeason': 'salmonberry_season', 'squidFest': 'squid_fest', 'troutDerby': 'trout_derby'}
PFKEY = {'DesertFestival': 'desert_festival', 'NightMarket': 'night_market', 'SquidFest': 'squid_fest', 'TroutDerby': 'trout_derby'}
for k, v in EN['festivalDates'].items():
    m = re.match(r'([a-z]+)(\d+)', k)
    fest.append({'key': k, 'season': m.group(1), 'day': int(m.group(2)), 'name': v})
births = [{'villager': v['id'], 'name': v['name'], 'season': v['birthday']['season'], 'day': v['birthday']['day'], 'image': v['image']}
          for v in villagers if v['birthday']['season']]
pf = {}
for k, v in G['acquisition']['passiveFestivals'].items():
    dn = v.get('DisplayName') or ''
    mm = re.match(r'\[LocalizedText Strings\\\\?(\w+):(\w+)\]', dn)
    pf[k] = dict(v, name=T(mm.group(2)) if mm else None, appText=T(PFKEY.get(k)))
dump('calendar', {'queenOfSauceNote': 'season is 0-based (0=spring)','festivals': fest, 'birthdays': births, 'passiveFestivals': pf,
                  'calendarDates': G['acquisition']['calendarDates'],
                  'calendarDatesNote': 'raw format "dayIndex/seasonIndex", both 0-based (14/0 = Spring 15)',
                  'calendarRanges': [{'key': k, 'textKey': CALKEY.get(k), 'text': T(CALKEY.get(k)),
                                      'dates': [{'season': SEASONS[int(x.split('/')[1])], 'day': int(x.split('/')[0]) + 1} for x in v]}
                                     for k, v in G['acquisition']['calendarDates'].items()],
                  'queenOfSauce': [dict(v, recipe=k, item=next((item_ref(r['itemId']) for r in G['recipes'].values() if r['internalName'] == k), None))
                                   for k, v in G['acquisition']['queenOfSauce'].items()]})

# ---------- shops ----------
shops = {}
for k, lst in G['acquisition']['shops'].items():
    shops[k] = [dict(e, items=[item_ref(i['id'], i.get('type', 'O')) for i in e.get('items', [])]) for e in lst]
a = G['acquisition']
dump('shops', {'shops': shops,
               'generalStoreItems': [item_ref(i) for i in a['generalStoreItems']],
               'jojaMartItems': [item_ref(i) for i in a['jojaMartItems']],
               'nightMarketItems': [item_ref(i) for i in a['nightMarketItems']],
               'oasisItems': [item_ref(i) for i in a['oasisItems']],
               'eggFestivalItems': [item_ref(i) for i in C.get('eggFestivalItems', [])],
               'travelingCartItems': [dict(item_ref(x['id'], x.get('type', 'O')), **{kk: vv for kk, vv in x.items() if kk not in ('id', 'type')}) for x in a['travelingCartItems']]})

# ---------- mining ----------
man = a['manual']
dump('mining', {'miningNodes': [dict(n, items=[item_ref(i) for i in n['items']], name=(T(n['nameKey']) if n.get('nameKey') else item_ref(n['nameItem'])['name']),
                                     image=(img('O%s' % n['nameItem']) if n.get('nameItem') else None)) for n in man['miningNodes']],
                'minesTilling': [dict(item_ref(x['id']), **{kk: vv for kk, vv in x.items() if kk != 'id'}) for x in man['minesTilling']],
                'panningItems': [dict(item_ref(x['id']), **{kk: vv for kk, vv in x.items() if kk != 'id'}) for x in man['panningItems']],
                'treasureChestItems': [dict(item_ref(x['id']), **{kk: vv for kk, vv in x.items() if kk not in ('id', 'name')}) for x in man['treasureChestItems']],
                'trashIds': [item_ref(i) for i in man['trashIds']]})

# ---------- constants ----------
const = {k: K[k] for k in ('DAYS', 'locales', 'flags', 'seasons', 'weather', 'fishingLevels', 'qualityLevels', 'weekdays', 'seasonsText', 'weeksText')}
const['seasonNames'] = {s: T(k) for s, k in K['seasonsText'].items()}
const['weekdayNames'] = [T(k) for k in K['weeksText']]
const['qualityMultipliers'] = {'normal': 1, 'silver': 1.25, 'gold': 1.5, 'iridium': 2}
const['categoryNames'] = {str(k): v for k, v in CAT.items()}
for k in ('newItems', 'allVillagers', 'allVillagersSchedule', 'allFemaleVillagers', 'categoriesWithQuality', 'allFish', 'crabPotFish',
          'allArtifacts', 'foragedMinerals', 'gems', 'geodeMinerals', 'geodes', 'allCrops', 'cropsPriceDay', 'allRecipes', 'shippingItems',
          'ANDROID_STORE_URL', 'IOS_STORE_URL', 'MAILTO_URL', 'TWITTER_URL', 'PRIVACY_POLICY_URL', 'TERMS_OF_SERVICE_URL'):
    const[k] = C.get(k)
const['displayOrder'] = G['displayOrder']
const['gameDataVersion'] = G['version']
const['craftingGroups'] = CRAFT['CRAFTING_GROUP_IDS']
const['selfPromoBanners'] = PROMO
const['locationDisplayNames'] = {k: locname(k) for k in list(LOCMAP) + ['artifact']}
const['locationDisplayNamesSource'] = {k: '%s.%s' % v for k, v in LOCMAP.items()}
const['fishLocationOverrides'] = {k[len('location.'):]: v for k, v in EN['app'].items() if k.startswith('location.')}
dump('constants', const)
dump('images_map', IMG)
print('done')
