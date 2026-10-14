import re, json, sys
src, out = sys.argv[1], sys.argv[2]
regs = {}
mods = []
cur = None
fn_re = re.compile(r'^    (r\d+) = function\(a0, a1, a2, a3, a4, a5, a6\) \{')
assign_int = re.compile(r'^    (r\d+) = (\d+);$')
assign_arr = re.compile(r'^    (r\d+) = \[([\d, ]*)\];$')
reg_re = re.compile(r'^    r\d+ = r\d+\.bind\(r\d+\)\((r\d+), (r\d+), (r\d+)\);$')
pending = None
with open(src, encoding='utf-8', errors='replace') as f:
    for i, line in enumerate(f, 1):
        if cur is not None:
            if line.startswith('    };'):
                pending = (cur, i); cur = None
            continue
        m = fn_re.match(line)
        if m:
            cur = i; continue
        m = assign_int.match(line)
        if m: regs[m.group(1)] = int(m.group(2)); continue
        m = assign_arr.match(line)
        if m:
            regs[m.group(1)] = [int(x) for x in m.group(2).split(',') if x.strip()]; continue
        m = reg_re.match(line)
        if m and pending:
            mid = regs.get(m.group(2))
            deps = regs.get(m.group(3))
            mods.append({'start': pending[0], 'end': pending[1], 'id': mid, 'deps': deps})
            pending = None
# fill unknown ids
for k, m in enumerate(mods):
    if not isinstance(m['id'], int):
        m['id_guess'] = True
        m['id'] = (mods[k-1]['id'] + 1) if k else 0
json.dump(mods, open(out, 'w'))
print(len(mods), sum(1 for m in mods if m.get('id_guess')))
ids=[m['id'] for m in mods]; print(len(set(ids)), min(ids), max(ids))
