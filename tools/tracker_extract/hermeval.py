"""Tiny symbolic evaluator for straight-line hermes-dec module bodies (data modules).
Treats input as untrusted text; never executes it."""
import ast, re, json, sys, os

class Obj:
    __slots__ = ('keys', 'd', 'getters')
    def __init__(self, items=()):
        self.keys = []; self.d = {}; self.getters = {}
        for k, v in items: self.set(k, v)
    def set(self, k, v):
        if k not in self.d: self.keys.append(k)
        self.d[k] = v
    def get(self, k):
        if k in self.getters: return self.getters[k]()
        return self.d.get(k)
    def has(self, k): return k in self.d or k in self.getters
    def slot_set(self, n, v):
        nums = [k for k in self.keys if isinstance(k, int)]
        if nums and n in self.d:
            self.d[n] = v; return
        strs = [k for k in self.keys if not isinstance(k, int)]
        if nums and not strs:
            self.set(n, v); return
        if n < len(strs): self.d[strs[n]] = v
        else: self.set(n, v)

class Ref:
    def __init__(self, kind, val=None): self.kind, self.val = kind, val
    def __repr__(self): return '<%s %r>' % (self.kind, self.val)

class Func:
    def __init__(self, body): self.body = body
        
TOK = re.compile(r"""('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")|\b(true|false|null|undefined)\b""")
def lit(s):
    def rep(m):
        if m.group(1): return m.group(1)
        return {'true':'True','false':'False','null':'None','undefined':'None'}[m.group(2)]
    return conv(ast.literal_eval(TOK.sub(rep, s)))

def fixnum(x):
    if isinstance(x, int) and not isinstance(x, bool) and 2**31 <= x < 2**32:
        return x - 2**32
    return x

def conv(v):
    if isinstance(v, dict): return Obj((k, conv(x)) for k, x in v.items())
    if isinstance(v, list): return [conv(x) for x in v]
    return fixnum(v)

def tojson(v, res=None, _seen=None):
    if isinstance(v, Obj):
        out = {}
        for k in v.keys: out[str(k)] = tojson(v.d[k], res)
        for k in v.getters:
            if k not in out: out[str(k)] = tojson(v.get(k), res)
        return out
    if isinstance(v, list): return [tojson(x, res) for x in v]
    if isinstance(v, Ref):
        return res(v) if res else {'$ref': v.kind, 'val': v.val}
    if isinstance(v, Func): return {'$func': True}
    return v

STR = r"""'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*\""""
R_ASSIGN = re.compile(r'^\s*(r\d+) = (.*);$')
R_SETIDX = re.compile(r'^\s*(r\d+)\[(\d+)\] = (r\d+);$')
R_SETKEY = re.compile(r'^\s*(r\d+)\[(' + STR + r')\] = (r\d+);$')
R_SETPROP = re.compile(r'^\s*(r\d+)\.(\w+) = (r\d+);$')
R_FUNC = re.compile(r'^(\s*)(r\d+) = function\(')
R_CLOS = re.compile(r'^\s*var (_closure\d+_slot\d+) = (r\d+);$')
R_CALL = re.compile(r'^(r\d+)\.bind\((r\d+)\)\(([^()]*)\)$')

def run(lines, deps, require=None):
    regs = {}
    closures = {}
    exports = Obj(); module = Obj([('exports', exports)])
    args = {'a0': Ref('global'), 'a1': Ref('require'), 'a2': Ref('importDefault'), 'a3': Ref('importAll'),
            'a4': module, 'a5': exports, 'a6': Ref('depmap')}
    unknown = []
    def regint(r):
        v = regs.get(r, None)
        # hermes-dec prints GetByIndex immediates as registers; only trust big ints (LoadConstInt)
        if isinstance(v, int) and not isinstance(v, bool) and v >= 256: return v
        return int(r[1:])
    i = 0; N = len(lines)
    while i < N:
        ln = lines[i]; i += 1
        s = ln.strip()
        if not s or s.startswith('return'): continue
        m = R_FUNC.match(ln)
        if m:
            ind = m.group(1); body = []
            if not ln.rstrip().endswith('};'):
                while i < N and lines[i] != ind + '};':
                    body.append(lines[i]); i += 1
                i += 1
            regs[m.group(2)] = Func(body); continue
        m = R_CLOS.match(ln)
        if m: closures[m.group(1)] = regs.get(m.group(2)); continue
        m = R_SETIDX.match(ln)
        if m:
            t, n, v = regs.get(m.group(1)), int(m.group(2)), regs.get(m.group(3))
            if isinstance(t, list):
                while len(t) <= n: t.append(None)
                t[n] = v
            elif isinstance(t, Obj): t.slot_set(n, v)
            else: unknown.append(ln)
            continue
        m = R_SETKEY.match(ln) or R_SETPROP.match(ln)
        if m:
            t = regs.get(m.group(1)); k = m.group(2)
            if k[0] in '\'"': k = ast.literal_eval(k)
            if isinstance(t, Obj):
                t.set(k, regs.get(m.group(3)))
            elif isinstance(t, list) and isinstance(k, str) and k.isdigit():
                n = int(k)
                while len(t) <= n: t.append(None)
                t[n] = regs.get(m.group(3))
            else: unknown.append(ln)
            continue
        m = R_ASSIGN.match(ln)
        if m:
            dst, e = m.group(1), m.group(2)
            if e.startswith('new Array('):
                try: regs[dst] = [None] * int(e[10:-1]); continue
                except ValueError: pass
            if e[0] in "{['\"-0123456789" or e in ('true','false','null','undefined'):
                try: regs[dst] = lit(e); continue
                except Exception: pass
            if e in args: regs[dst] = args[e]; continue
            if e == 'global': regs[dst] = Ref('global'); continue
            if e.startswith('_closure'): regs[dst] = closures.get(e); continue
            if re.fullmatch(r'r\d+', e): regs[dst] = regs.get(e); continue
            mm = re.fullmatch(r'(r\d+)\[(r\d+)\]', e)
            if mm:
                b = regs.get(mm.group(1))
                if isinstance(b, Ref) and b.kind == 'depmap':
                    idx = regint(mm.group(2))
                    regs[dst] = Ref('dep', deps[idx] if deps and idx is not None and idx < len(deps) else None); continue
            mm = R_CALL.match(e)
            if mm:
                fn = regs.get(mm.group(1))
                a = [regs.get(x.strip()) for x in mm.group(3).split(',') if x.strip()]
                if isinstance(fn, Ref) and fn.kind in ('require', 'importDefault', 'importAll') and a:
                    mid = a[0].val if isinstance(a[0], Ref) else None
                    regs[dst] = require(mid, fn.kind) if require else Ref('module', mid); continue
                if isinstance(fn, Ref) and fn.kind == 'global.Object.defineProperty' and len(a) == 3:
                    tgt, key, desc = a
                    if isinstance(tgt, Obj) and isinstance(desc, Obj):
                        g = desc.get('get')
                        if isinstance(g, Func):
                            body = '\n'.join(g.body)
                            cm = re.search(r'(_closure\d+_slot\d+)', body)
                            pm = re.search(r'r0 = (r\d+|_closure\d+_slot\d+)\.(\w+);', body)
                            if cm:
                                cn = cm.group(1)
                                if pm and pm.group(1).startswith('r'):
                                    # e.g. r1 = _closure0_slot0; r0 = r1.foo
                                    prop = pm.group(2)
                                    tgt.getters[key] = (lambda cn=cn, prop=prop: _prop(closures.get(cn), prop))
                                else:
                                    tgt.getters[key] = (lambda cn=cn: closures.get(cn))
                            else:
                                tgt.getters[key] = (lambda: None)
                        elif desc.has('value'):
                            tgt.set(key, desc.get('value'))
                    regs[dst] = None; continue
            mm = re.fullmatch(r'(r\d+)\.(\w+)', e)
            if mm:
                b = regs.get(mm.group(1)); p = mm.group(2)
                if isinstance(b, Obj): regs[dst] = b.get(p); continue
                if isinstance(b, Ref): regs[dst] = Ref(b.kind + '.' + p, b.val); continue
            regs[dst] = Ref('expr', e); unknown.append(ln); continue
        unknown.append(ln)
    return module.d['exports'], closures, unknown

def _prop(o, p):
    if isinstance(o, Obj): return o.get(p)
    return None

class Bundle:
    def __init__(self, src, modsf, assetsf):
        self.mods = {m['id']: m for m in json.load(open(modsf))}
        self.assets = json.load(open(assetsf))
        self.lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
        self.cache = {}; self.unknown = {}
    def require(self, mid, kind='require'):
        if mid is None: return Ref('module', None)
        if str(mid) in self.assets:
            a = self.assets[str(mid)]
            return Ref('asset', a.get('drawable') or a['path'])
        if mid in self.cache: return self.cache[mid]
        m = self.mods.get(mid)
        if not m: return Ref('module', mid)
        self.cache[mid] = Ref('module', mid)  # recursion guard
        exp, clos, unk = run(self.lines[m['start']:m['end']-1], m['deps'], self.require)
        self.unknown[mid] = unk
        if kind == 'importDefault' and isinstance(exp, Obj) and not exp.has('default'):
            pass
        self.cache[mid] = exp
        return exp
    def eval(self, mid):
        m = self.mods[mid]
        return run(self.lines[m['start']:m['end']-1], m['deps'], self.require)

def resolver(ref):
    if ref.kind == 'asset': return {'$asset': ref.val}
    return {'$ref': ref.kind, 'val': ref.val}
