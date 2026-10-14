import json, sys
d = json.load(open(sys.argv[1]))
path = sys.argv[2].split('/') if len(sys.argv) > 2 and sys.argv[2] else []
for p in path:
    d = d[int(p)] if isinstance(d, list) else d[p]
def show(v, depth, ind=''):
    if isinstance(v, dict):
        ks = list(v.keys())
        print(ind + 'dict(%d) keys: %s' % (len(ks), ks[:12]))
        if depth > 0 and ks:
            for k in ks[:int(sys.argv[4]) if len(sys.argv)>4 else 3]:
                print(ind + ' [%s]' % k); show(v[k], depth-1, ind + '   ')
    elif isinstance(v, list):
        print(ind + 'list(%d)' % len(v))
        if depth > 0 and v: show(v[0], depth-1, ind + '   ')
    else: print(ind + repr(v)[:200])
show(d, int(sys.argv[3]) if len(sys.argv) > 3 else 1)
