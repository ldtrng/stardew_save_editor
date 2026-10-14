"""Adds/updates individual translations: add_keys.py <json file of {key: {lang: text}}>"""
import json, sys
new = json.load(open(sys.argv[1]))
langs = {l for v in new.values() for l in v}
for lang in langs:
    p = f'assets/i18n/{lang}.json'
    d = json.load(open(p))
    for k, v in new.items():
        if lang in v:
            d[k] = v[lang]
    json.dump(d, open(p, 'w'), ensure_ascii=False, indent=1)
print('updated', sorted(langs))
