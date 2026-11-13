"""Build Shared/Localizable.xcstrings from the keys Xcode extracted and translations.json.

    python3 Localization/build_catalog.py keys.json Localization/translations.json Shared/Localizable.xcstrings

keys.json: list of catalog keys exactly as Xcode extracted them (English, with format specifiers).
translations.json: {english_with_{n}_placeholders: {lang: text | {plural_category: text}}}
Placeholders are written {0}, {1}, … in the order they appear in the English text.
"""
import json, re, sys

SPEC = re.compile(r'%(?:(\d+)\$)?(lld|llu|ld|lu|d|i|u|@|lf|f|g|e)')


def normalize(key):
    """Turn a format key into the {n} form used in translations.json."""
    n = [0]

    def rep(m):
        idx = int(m.group(1)) - 1 if m.group(1) else n[0]
        n[0] += 1
        return '{%d}' % idx

    s = key.replace('%%', '\0')
    s = SPEC.sub(rep, s)
    return s.replace('\0', '%')


def specs(key):
    return [m.group(2) for m in SPEC.finditer(key.replace('%%', ''))]


def render(text, key):
    sp = specs(key)
    if sp or '%%' in key:          # a format string: literal % must be escaped
        text = text.replace('%', '%%')

    def rep(m):
        i = int(m.group(1))
        return ('%%%d$%s' % (i + 1, sp[i])) if len(sp) > 1 else ('%' + sp[i])

    return re.sub(r'\{(\d)\}', rep, text)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value, key):
    if isinstance(value, dict):
        return {"variations": {"plural": {cat: unit(render(v, key)) for cat, v in value.items()}}}
    return unit(render(value, key))


def main(keys_path, tr_path, out_path):
    keys = json.load(open(keys_path))
    tr = json.load(open(tr_path))
    strings, unmatched = {}, []
    for key in sorted(set(keys)):
        t = tr.get(normalize(key))
        if t is None:
            unmatched.append(key)
            strings[key] = {}
            continue
        strings[key] = {"localizations": {lang: localization(v, key) for lang, v in sorted(t.items())}}
    cat = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    with open(out_path, 'w') as f:
        json.dump(cat, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')
    print("keys", len(keys), "translated", len(keys) - len(unmatched))
    for u in unmatched:
        print("UNMATCHED", repr(u))


if __name__ == '__main__':
    main(*sys.argv[1:4])
