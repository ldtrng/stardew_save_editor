import re, json, sys, os
src, modsf, resdir, out = sys.argv[1:5]
mods = json.load(open(modsf))
lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
drawables = set(os.path.splitext(f)[0] for f in os.listdir(resdir))
amap = {}
miss = []
Q = r"""(?:'([^']*)'|"([^"]*)")"""
lit = re.compile(r"'httpServerLocation': " + Q + r".*?'name': " + Q + r", 'type': " + Q)
print('deps None:', sum(1 for m in mods if m['deps'] is None))
for m in mods:
    if m['end'] - m['start'] > 20: continue
    body = '\n'.join(lines[m['start']-1:m['end']])
    mm = lit.search(body)
    if not mm: continue
    g = mm.groups(); loc, name, typ = g[0] or g[1], g[2] or g[3], g[4] or g[5]
    path = loc[len('/assets/'):] + '/' + name
    res = re.sub(r'[^a-z0-9_]', '', path.lower().replace('/', '_'))
    entry = {'path': path + '.' + typ, 'type': typ}
    if res in drawables: entry['drawable'] = res
    elif typ in ('png','jpg','jpeg','webp','gif'): miss.append((m['id'], path, res))
    amap[m['id']] = entry
json.dump(amap, open(out, 'w'), indent=0)
print(len(amap), 'assets;', sum(1 for v in amap.values() if 'drawable' in v), 'resolved; missing', len(miss))
for x in miss[:20]: print(x)
