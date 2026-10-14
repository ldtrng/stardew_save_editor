import json, sys, re
src, modsf = sys.argv[1:3]
mods = json.load(open(modsf))
lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
out=[]
for m in mods:
    body = lines[m['start']-1:m['end']]
    size = sum(len(l) for l in body)
    strs = re.findall(r"'([A-Za-z][^']{2,40})'", '\n'.join(body[:60]))
    out.append((size, m['id'], m['start'], m['end'], strs[:8]))
out.sort(reverse=True)
for o in out[:int(sys.argv[3])]:
    print(o[0], o[1], o[2], o[3], o[4])
