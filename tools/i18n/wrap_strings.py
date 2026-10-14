"""One-shot helper: wraps user-facing string literals in tr('...') and removes
`const` from expressions so the non-const tr() calls compile.
Usage: wrap_strings.py file.dart [...]"""
import re, sys

LIT = r"""(?:'(?:[^'\\$\n]|\\.)*'|"(?:[^"\\$\n]|\\.)*")"""
NAMED = r'(?:title|subtitle|message|label|labelText|hintText|tooltip|errorText|dialogTitle|feature)'
POS1 = r'(?:Text|PlankHeader|PixelTag|InfoRow|_Note|CollectionFilter|CollectionSort|Tab|SnackBar)'


def is_ui(lit):
    s = lit[1:-1]
    if not re.search(r'[A-Za-z]', s):
        return False
    if s.startswith(('assets/', 'http', 'mailto')) or s.endswith(('.png', '.json', '.ttf')):
        return False
    if re.fullmatch(r'[a-z0-9_]+', s) or re.fullmatch(r'[A-Z]{2,}[A-Z0-9_]*', s):
        return False  # keys / ids
    return True


def wrap(m, lit_group):
    lit = m.group(lit_group)
    if not is_ui(lit):
        return m.group(0)
    return m.group(0).replace(lit, f'tr({lit})', 1)


def process(src):
    out = src
    # Text('…'), PlankHeader('…') etc. as first positional argument
    out = re.sub(rf'\b({POS1})\((\s*)({LIT})', lambda m: wrap(m, 3), out)
    # named arguments
    out = re.sub(rf'\b({NAMED}):(\s*)({LIT})', lambda m: wrap(m, 3), out)
    # showToast(context, '…')
    out = re.sub(rf'showToast\(context,(\s*)({LIT})', lambda m: wrap(m, 2), out)
    # _Section('a', 'b', …) / _Step(n, 'a', 'b')
    out = re.sub(rf"_Section\(({LIT}),\s*({LIT})",
                 lambda m: m.group(0).replace(m.group(1), f'tr({m.group(1)})', 1).replace(m.group(2), f'tr({m.group(2)})', 1), out)
    out = re.sub(rf"_Step\((\d+),\s*({LIT}),\s*({LIT})",
                 lambda m: f"_Step({m.group(1)}, tr({m.group(2)}), " + (f"tr({m.group(3)})" if is_ui(m.group(3)) else m.group(3)), out)
    out = out.replace('tr(tr(', 'tr(')
    # Drop `const` in expressions (keep declarations and constructors).
    lines = out.split('\n')
    res = []
    for ln in lines:
        stripped = ln.lstrip()
        is_ctor_decl = re.match(r'const [A-Z_]\w*\((\{|this\.|super\.|\))', stripped) and (ln.rstrip().endswith((';', '{', '});', '),')) and ('super.key' in ln or 'this.' in ln or ln.rstrip().endswith('();')))
        is_decl = re.match(r'(static )?const [a-z_][\w<>, ?]*\s*[=;]', stripped) or re.match(r'(static )?const [A-Za-z_][\w<>, ?]* [a-z_]\w* =', stripped)
        if not is_ctor_decl and not is_decl:
            ln = re.sub(r'(?<![\w.])const (?=[A-Z_\[{<(])', '', ln)
        res.append(ln)
    return '\n'.join(res)


for path in sys.argv[1:]:
    s = open(path).read()
    t = process(s)
    if 'tr(' in t and "l10n/l10n.dart'" not in t:
        depth = path.split('lib/', 1)[1].count('/')
        rel = '../' * depth + 'l10n/l10n.dart'
        t = re.sub(r"(import 'package:flutter/material.dart';\n)", rf"\1\nimport '{rel}';\n", t, count=1)
    if t != s:
        open(path, 'w').write(t)
        print('updated', path)
