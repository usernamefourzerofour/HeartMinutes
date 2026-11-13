"""Build Shared/Localizable.xcstrings from the keys Xcode extracted (keys.json) and translations.json.

keys.json: list of catalog keys exactly as Xcode extracted them (Danish source, format specifiers).
translations.json: {danish_with_{n}_placeholders: {lang: text_with_{n}}}
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
    is_format = bool(sp) or '%%' in key
    if is_format:
        text = text.replace('%', '%%')
    def rep(m):
        i = int(m.group(1))
        return ('%%%d$%s' % (i + 1, sp[i])) if len(sp) > 1 else ('%' + sp[i])
    return re.sub(r'\{(\d)\}', rep, text)

PLURAL = {  # "{0} målinger": one/other per language
    'da': ('{0} måling', '{0} målinger'),
    'en': ('{0} measurement', '{0} measurements'), 'de': ('{0} Messung', '{0} Messungen'),
    'sv': ('{0} mätning', '{0} mätningar'), 'nb': ('{0} måling', '{0} målinger'),
    'fi': ('{0} mittaus', '{0} mittausta'), 'nl': ('{0} meting', '{0} metingen'),
    'fr': ('{0} mesure', '{0} mesures'), 'es': ('{0} medición', '{0} mediciones'),
    'it': ('{0} misurazione', '{0} misurazioni'), 'pt-BR': ('{0} medição', '{0} medições'),
}

def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}

def main(keys_path, tr_path, out_path):
    keys = json.load(open(keys_path))
    tr = json.load(open(tr_path))
    strings, unmatched = {}, []
    for key in sorted(set(keys)):
        norm = normalize(key)
        entry = {}
        t = tr.get(norm)
        if t is None:
            unmatched.append(key)
        else:
            locs = {}
            for lang, text in t.items():
                if norm == '{0} målinger' and lang in PLURAL:
                    one, other = PLURAL[lang]
                    locs[lang] = {"variations": {"plural": {
                        "one": unit(render(one, key)), "other": unit(render(other, key))}}}
                else:
                    locs[lang] = unit(render(text, key))
            if norm == '{0} målinger':
                one, other = PLURAL['da']
                locs['da'] = {"variations": {"plural": {
                    "one": unit(render(one, key)), "other": unit(render(other, key))}}}
            entry["localizations"] = locs
        strings[key] = entry
    cat = {"sourceLanguage": "da", "strings": strings, "version": "1.0"}
    with open(out_path, 'w') as f:
        json.dump(cat, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')
    print("keys", len(keys), "translated", len(keys) - len(unmatched))
    for u in unmatched:
        print("UNMATCHED", repr(u))

if __name__ == '__main__':
    main(*sys.argv[1:4])
