import json, os, sys, collections
D = sys.argv[1]
res = os.path.join(sys.argv[2])
draw = set(os.path.splitext(f)[0] for f in os.listdir(res))
for f in sorted(os.listdir(D)):
    if not f.endswith('.json') or f == 'images_map.json': continue
    d = json.load(open(os.path.join(D, f)))
    c = collections.Counter(); ex = collections.defaultdict(list)
    def walk(v, path):
        if isinstance(v, dict):
            if 'name' in v and ('id' in v or 'category' in v or 'key' in v):
                c['refs'] += 1
                if v['name'] is None: c['name_null'] += 1; ex['name_null'].append((path, v.get('id'), v.get('type')))
            if 'image' in v:
                c['img_fields'] += 1
                if v['image'] is None: c['img_null'] += 1; ex['img_null'].append((path, v.get('id') or v.get('key'), v.get('type'), v.get('name')))
                elif v['image'] not in draw: c['img_missing_file'] += 1; ex['img_missing_file'].append(v['image'])
            for k, x in v.items(): walk(x, path + '.' + str(k) if len(path) < 30 else path)
        elif isinstance(v, list):
            for x in v: walk(x, path + '[]' if len(path) < 30 else path)
    walk(d, '')
    print(f, dict(c))
    for k, l in ex.items():
        if f in ('furniture.json',) and k == 'img_null': continue
        print('   ', k, collections.Counter(map(str, l)).most_common(6))
