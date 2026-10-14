"""Apply exact-substring replacements: apply.py <file> <pairs.json>"""
import json, sys
p, pairs = sys.argv[1], json.load(open(sys.argv[2]))
s = open(p).read()
for a, b in pairs:
    if a not in s:
        sys.exit(f'NOT FOUND in {p}:\n{a}')
    s = s.replace(a, b)
open(p, 'w').write(s)
print('ok', p, len(pairs))
