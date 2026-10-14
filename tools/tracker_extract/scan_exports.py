import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hermeval
SCR = os.environ.get('SDV_WORK') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = hermeval.Bundle(SCR + '/dec/out.js', SCR + '/tools/modules.json', SCR + '/tools/assets.json')
lo, hi = int(sys.argv[1]), int(sys.argv[2])
def size(v):
    if isinstance(v, hermeval.Obj): return len(v.keys) + len(v.getters)
    if isinstance(v, list): return len(v)
    return 0
for mid in sorted(B.mods):
    if not (lo <= mid <= hi) or str(mid) in B.assets or mid in (3190,) or 3192 <= mid <= 3203: continue
    try:
        exp, clos, unk = B.eval(mid)
        if not isinstance(exp, hermeval.Obj): exp = hermeval.Obj([("<exports>", exp)])
    except Exception as e:
        print(mid, 'ERR', e); continue
    items = []
    for k in list(exp.keys) + list(exp.getters):
        try: v = exp.get(k)
        except Exception: v = None
        if size(v) >= 3: items.append('%s:%s(%d)' % (k, type(v).__name__, size(v)))
    for cn, v in clos.items():
        if size(v) >= 5 and not any(v is exp.get(k) for k in exp.getters): items.append('%s:%s(%d)' % (cn, type(v).__name__, size(v)))
    if items: print(mid, items[:10])
