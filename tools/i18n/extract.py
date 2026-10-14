"""Collects every UI string key (English) into assets/i18n/en.json.
Sources: tr('...') calls in lib/, label maps in a few Dart files, and display
strings from the tracker data that the UI passes through tr()."""
import glob, json, re

LIT = r"""(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")"""
keys = set()


def unq(lit):
    body = lit[1:-1]
    return body.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')


for p in glob.glob('lib/**/*.dart', recursive=True):
    src = open(p).read()
    for m in re.finditer(rf"\btr\(\s*((?:{LIT}\s*)+)", src):
        parts = re.findall(LIT, m.group(1))
        s = ''.join(unq(x) for x in parts)
        if '$' not in s:
            keys.add(s)

# Literal label maps / constants displayed through tr(variable).
for p in ['lib/save/game_constants.dart', 'lib/features/editor/item_widgets.dart', 'lib/features/editor/inventory_screen.dart',
          'lib/save/bundles.dart', 'lib/services/save_import.dart', 'lib/l10n/names.dart', 'lib/features/editor/save_guide_screen.dart',
          'lib/features/editor/bundles_screen.dart']:
    for lit in re.findall(LIT, open(p).read()):
        s = unq(lit)
        if re.fullmatch(r"[A-Z][A-Za-z' .()+&/-]*[a-z.)+]", s) or re.fullmatch(r"[A-Z][^$_/\\]{3,}[.!?]", s):
            keys.add(s)

D = 'assets/tracker/data/'
def load(n): return json.load(open(D + n + '.json'))
cap = lambda s: s[:1].upper() + s[1:]

for it in load('items'):
    if it.get('categoryName'): keys.add(it['categoryName'])
    for l in it.get('locations', []):
        keys.add(str(l.get('displayLocationName') or l.get('location')))
        if l.get('methodName'): keys.add(cap(l['methodName']))
for f in load('fish'):
    for l in f.get('locations', []):
        keys.add(str(l.get('displayLocationName') or l.get('location')))
        if l.get('methodName'): keys.add(cap(l['methodName']))
    if f.get('trapLocation'): keys.add(cap(f['trapLocation']))
    if f.get('behavior'): keys.add(cap(f['behavior']))
for v in load('villagers'):
    for k in ('homeRegionText', 'homeLocationText'):
        if v.get(k): keys.add(v[k])
    for r in v.get('relationships', []): keys.add(r['text'])
    for lvl in (v.get('gifts') or {}).values():
        for it in lvl.get('items', []):
            if it.get('anyName'): keys.add(it['anyName'])
            if it.get('category') is not None and it.get('name'): keys.add(it['name'])
for r in load('cooking_recipes') + load('crafting_recipes')['recipes']:
    for i in r.get('ingredients', []):
        if i.get('anyName'): keys.add(i['anyName'])
        if i.get('category') is not None and i.get('name'): keys.add(i['name'])
for g in load('crafting_recipes')['groups']: keys.add(g['name'])
b = load('bundles')
for room in b['normal'] + b['remixed']:
    keys.add(room['name'])
    if room.get('reward'): keys.add(room['reward'])
for k in ['Spring', 'Summer', 'Fall', 'Winter', 'Love', 'Like', 'Neutral', 'Dislike', 'Hate', 'Female', 'Male',
          'Sunny', 'Rainy', 'Ocean', 'Freshwater', 'General', 'North', 'South', 'East', 'West', 'Artifacts', 'Minerals',
          'Normal', 'Silver', 'Gold', 'Iridium', 'remixed', 'Attack', 'Defense', 'Farming', 'Fishing', 'Foraging', 'Luck',
          'Magnetic Radius', 'Max Stamina', 'Mining', 'Speed', 'Combat', 'Farmer']:
    keys.add(k)
for animal in ['White Chicken', 'Brown Chicken', 'Blue Chicken', 'Void Chicken', 'Golden Chicken', 'Duck', 'Rabbit',
               'Dinosaur', 'White Cow', 'Brown Cow', 'Goat', 'Sheep', 'Pig', 'Ostrich']:
    keys.add(animal)
def junk(k):
    return (not k.strip() or k.startswith("{'") or (re.fullmatch(r'[A-Z][a-z]+[A-Z]\w*', k) and k != 'JojaMart')
            or k in ('casino_coins', 'star_tokens', 'fishingGame'))
keys = {k for k in keys if not junk(k)}
out = {k: k for k in sorted(keys)}
json.dump(out, open('assets/i18n/en.json', 'w'), ensure_ascii=False, indent=1)
print(len(out), 'keys')
