import sys, json, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hermeval
src, modsf, assetsf = sys.argv[1:4]
mods = json.load(open(modsf)); assets = json.load(open(assetsf))
lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
res = []
for m in mods:
    if str(m['id']) in assets: continue
    body = lines[m['start']:m['end']-1]
    n = len(body)
    if n < 15: continue
    txt = '\n'.join(body)
    nfun = txt.count('function(')
    nlit = sum(1 for l in body if re.match(r"\s*r\d+ = [\[{]", l))
    nreq = len(re.findall(r'\.bind\(r\d+\)\(r\d+\)', txt))
    strs = re.findall(r"'([A-Za-z][^']{2,30})'", txt)
    res.append((nlit / n, n, m['id'], nfun, nreq, strs[:10]))
res.sort(key=lambda x: -x[0])
for r in res:
    if r[0] > 0.25 and r[1] > 20: print('%.2f n=%d id=%d fun=%d req=%d %s' % (r[0], r[1], r[2], r[3], r[4], r[5]))
