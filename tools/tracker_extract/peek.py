import json, sys
d = json.load(open(sys.argv[1]))
for p in [x for x in sys.argv[2].split('/') if x]:
    d = d[int(p)] if isinstance(d, list) else d[p]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 2
if isinstance(d, dict):
    print('dict', len(d), list(d.keys())[:40])
    for k in list(d.keys())[:n]: print('==', k, json.dumps(d[k], ensure_ascii=False)[:int(sys.argv[4]) if len(sys.argv)>4 else 1500])
elif isinstance(d, list):
    print('list', len(d))
    for x in d[:n]: print('==', json.dumps(x, ensure_ascii=False)[:int(sys.argv[4]) if len(sys.argv)>4 else 1500])
else: print(d)
