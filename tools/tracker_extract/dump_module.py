import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hermeval
SCR = os.environ.get('SDV_WORK') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = hermeval.Bundle(SCR + '/dec/out.js', SCR + '/tools/modules.json', SCR + '/tools/assets.json')
mid, out = int(sys.argv[1]), sys.argv[2]
exp, clos, unk = B.eval(mid)
print('unknown statements:', len(unk)); [print('  ', u.strip()[:160]) for u in unk[:int(sys.argv[3]) if len(sys.argv)>3 else 10]]
res = {'exports': hermeval.tojson(exp, hermeval.resolver)}
if len(sys.argv) > 4: res['closures'] = {k: hermeval.tojson(v, hermeval.resolver) for k, v in clos.items()}
json.dump(res, open(out, 'w'), ensure_ascii=False, indent=1)
