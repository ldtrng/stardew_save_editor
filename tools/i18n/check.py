"""Validates assets/i18n/<code>.json against en.json: python3 -I tools/i18n/check.py <code> [...]"""
import json, re, sys
en = json.load(open('assets/i18n/en.json'))
bad = 0
for code in sys.argv[1:]:
    t = json.load(open(f'assets/i18n/{code}.json'))
    missing = [k for k in en if k not in t or not str(t[k]).strip()]
    extra = [k for k in t if k not in en]
    ph = [k for k in en if k in t and sorted(re.findall(r'\{\w+\}', k)) != sorted(re.findall(r'\{\w+\}', t[k]))]
    print(f'{code}: {len(t)} keys, missing {len(missing)}, extra {len(extra)}, placeholder mismatch {len(ph)}')
    for k in (missing + ph)[:10]:
        print('   ', repr(k)[:100])
    bad += len(missing) + len(ph)
sys.exit(1 if bad else 0)
