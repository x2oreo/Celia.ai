#!/usr/bin/env python3
"""Generate app/entry/src/main/resources/rawfile/gtin_pl.json from the Polish medicines register.

Source: Rejestr Produktów Leczniczych (URPL / e-Zdrowie), public CSV export, updated daily:
https://rejestrymedyczne.ezdrowie.gov.pl/api/rpl/medicinal-products/public-pl-report/get-csv

Every human medicine pack sold in Poland is listed with its GTIN (the number in the box barcode), brand, Latin
INN, strength, form, ATC code, marketing-authorisation holder and availability category (Rp / OTC / ...).

Output (compact, read by drugs/GtinCatalog.ets):
  {
    "source": "...", "date": "YYYY-MM-DD",
    "forms": ["Film-coated tablets", ...], "holders": ["Viatris Healthcare Sp. z o.o.", ...],
    "products": [[brand, innLatin, ingredients, strength, formIdx, atc, holderIdx, rplId, packs], ...]
  }
`packs` is "gtin13|category|pack description" entries joined by ";" (category: Rp, OTC, Rpz, Lz, Rpw ...).
`ingredients` is English INNs joined by " + ", matched to the app's dataset where possible (so DrugChecker
finds them exactly); otherwise a best-effort Latin -> English stem that DrugChecker can still fuzzy-match.

Usage:  python3 data/export_gtins.py [path/to/register.csv]
"""
import csv
import datetime
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATASET = ROOT / 'app/entry/src/main/ets/drugs/DrugDataset.ets'
OUT = ROOT / 'app/entry/src/main/resources/rawfile/gtin_pl.json'
URL = 'https://rejestrymedyczne.ezdrowie.gov.pl/api/rpl/medicinal-products/public-pl-report/get-csv'
SOURCE = 'Rejestr Produktów Leczniczych (URPL, rejestrymedyczne.ezdrowie.gov.pl)'

# Salt / ester / descriptive words that follow the base substance in Latin INNs.
SALT_WORDS = {
    'hydrochloridum', 'dihydrochloridum', 'fumaras', 'natricum', 'sulfas', 'succinas', 'acetas', 'propionas',
    'maleas', 'chloridum', 'nitras', 'cilexetili', 'furoas', 'dipropionas', 'phosphas', 'tartras', 'dihydricus',
    'monohydricum', 'bromidum', 'kalicum', 'citras', 'hydrobromidum', 'mesilas', 'besilas', 'oxalas', 'lactas',
    'magnesicum', 'calcicum', 'trihydricum', 'monohydricus', 'hemifumaras', 'hydrogenotartras', 'tosilas',
    'valeras', 'axetili', 'pivoxili', 'etexilatum', 'medoxomili', 'butylbromidum', 'hyclatum', 'embonas',
    'stearas', 'docusas', 'iodidum', 'hemihydricum', 'sesquihydricum', 'anhydricum', 'dinatricum', 'benzoas',
    'decanoas', 'palmitas', 'enanthas', 'gluconas', 'carbonas', 'hydrogenocarbonas', 'aspartas', 'lysinum',
}

# Common EDQM dosage forms, Polish -> English. Unlisted forms stay in Polish.
FORMS = {
    'Tabletki powlekane': 'Film-coated tablets',
    'Tabletki': 'Tablets',
    'Kapsułki twarde': 'Hard capsules',
    'Kapsułki miękkie': 'Soft capsules',
    'Kapsułki': 'Capsules',
    'Roztwór do wstrzykiwań': 'Solution for injection',
    'Tabletki o przedłużonym uwalnianiu': 'Prolonged-release tablets',
    'Tabletki o zmodyfikowanym uwalnianiu': 'Modified-release tablets',
    'Tabletki dojelitowe': 'Gastro-resistant tablets',
    'Kapsułki dojelitowe, twarde': 'Gastro-resistant hard capsules',
    'Kapsułki o przedłużonym uwalnianiu, twarde': 'Prolonged-release hard capsules',
    'Kapsułki o zmodyfikowanym uwalnianiu, twarde': 'Modified-release hard capsules',
    'Tabletki ulegające rozpadowi w jamie ustnej': 'Orodispersible tablets',
    'Tabletki drażowane': 'Coated tablets',
    'Tabletki musujące': 'Effervescent tablets',
    'Tabletki do rozgryzania i żucia': 'Chewable tablets',
    'Tabletki do ssania': 'Lozenges',
    'Tabletki podjęzykowe': 'Sublingual tablets',
    'Tabletki dopochwowe': 'Vaginal tablets',
    'Krem': 'Cream',
    'Maść': 'Ointment',
    'Żel': 'Gel',
    'Syrop': 'Syrup',
    'Czopki': 'Suppositories',
    'Globulki': 'Pessaries',
    'Roztwór doustny': 'Oral solution',
    'Zawiesina doustna': 'Oral suspension',
    'Krople doustne, roztwór': 'Oral drops, solution',
    'Krople doustne': 'Oral drops',
    'Płyn doustny': 'Oral liquid',
    'Krople do oczu, roztwór': 'Eye drops, solution',
    'Krople do oczu, zawiesina': 'Eye drops, suspension',
    'Maść do oczu': 'Eye ointment',
    'Aerozol do nosa, roztwór': 'Nasal spray, solution',
    'Aerozol do nosa, zawiesina': 'Nasal spray, suspension',
    'Aerozol inhalacyjny, zawiesina': 'Inhalation spray, suspension',
    'Aerozol inhalacyjny, roztwór': 'Inhalation spray, solution',
    'Proszek do inhalacji': 'Inhalation powder',
    'Roztwór do infuzji': 'Solution for infusion',
    'Koncentrat do sporządzania roztworu do infuzji': 'Concentrate for solution for infusion',
    'Roztwór do wstrzykiwań w ampułko-strzykawce': 'Solution for injection in pre-filled syringe',
    'Roztwór do wstrzykiwań we wstrzykiwaczu': 'Solution for injection in pre-filled pen',
    'Roztwór do wstrzykiwań / do infuzji': 'Solution for injection/infusion',
    'Zawiesina do wstrzykiwań': 'Suspension for injection',
    'Proszek do sporządzania roztworu do wstrzykiwań': 'Powder for solution for injection',
    'Proszek do sporządzania roztworu do infuzji': 'Powder for solution for infusion',
    'Proszek do sporządzania roztworu doustnego': 'Powder for oral solution',
    'Proszek do sporządzania zawiesiny doustnej': 'Powder for oral suspension',
    'Granulat do sporządzania roztworu doustnego': 'Granules for oral solution',
    'Granulat do sporządzania zawiesiny doustnej': 'Granules for oral suspension',
    'Roztwór na skórę': 'Cutaneous solution',
    'Płyn na skórę': 'Cutaneous liquid',
    'Pastylki twarde': 'Hard lozenges',
    'System transdermalny, plaster': 'Transdermal patch',
    'Plaster leczniczy': 'Medicated plaster',
    'Guma do żucia, lecznicza': 'Medicated chewing gum',
    'Zioła do zaparzania': 'Herbal tea',
    'Zioła do zaparzania w saszetkach': 'Herbal tea in bags',
}

# Latin names whose English INN does not follow the suffix rules.
OVERRIDES = {'coffeinum': 'caffeine', 'acidum acetylsalicylicum': 'acetylsalicylic acid',
             'metamizolum': 'metamizole', 'drotaverini': 'drotaverine', 'oxymetazolini': 'oxymetazoline',
             'xylometazolini': 'xylometazoline', 'domperidonum': 'domperidone'}

PACK_RE = re.compile(r'^(\d{8,14})\s*¦\s*([^¦]*?)\s*¦')


def dataset_ingredients() -> set:
    text = DATASET.read_text(encoding='utf-8')
    return set(re.findall(r"d\('([^']+)',\s*(?:KR|PR|CR|NL),", text))


def stem_candidates(word: str) -> list:
    """Latin INN word -> English candidates, most likely first."""
    w = word.lower()
    for suffix, repl in (('inum', ['in', 'ine']), ('ini', ['ine', 'in']), ('onum', ['one', 'on']),
                         ('oni', ['one', 'on']), ('olum', ['ol']), ('oli', ['ol']), ('amum', ['am']),
                         ('ami', ['am']), ('enum', ['en']), ('eni', ['en']), ('idum', ['ide']), ('idi', ['ide']),
                         ('atum', ['ate']), ('um', ['', 'e']), ('i', ['', 'e'])):
        if w.endswith(suffix) and len(w) > len(suffix) + 2:
            return [w[:-len(suffix)] + r for r in repl]
    return [w]


def to_english(component: str, known: set) -> str:
    words = [w for w in re.split(r'\s+', component.strip()) if w]
    if not words:
        return ''
    if words[0].lower() in OVERRIDES:
        return OVERRIDES[words[0].lower()]
    if words[0].lower() == 'acidum' and len(words) > 1:  # Acidum acetylsalicylicum -> acetylsalicylic acid
        adj = words[1].lower()
        name = (adj[:-2] if adj.endswith('um') else adj) + ' acid'
        return name
    base = [w for w in words if w.lower() not in SALT_WORDS] or words
    cands = stem_candidates(base[0])
    for c in cands:
        if c in known:
            return c
    return cands[0]


def ingredients(inn_latin: str, known: set) -> str:
    parts = [to_english(p, known) for p in re.split(r'\s*\+\s*', inn_latin) if p.strip()]
    return ' + '.join(p for p in parts if p)


def load_rows(path: str):
    if path:
        data = pathlib.Path(path).read_text(encoding='utf-8')
    else:
        print(f'downloading {URL} ...')
        with urllib.request.urlopen(URL, timeout=120) as r:
            data = r.read().decode('utf-8')
    return list(csv.DictReader(data.splitlines(keepends=True), delimiter=';'))


def main() -> None:
    rows = load_rows(sys.argv[1] if len(sys.argv) > 1 else '')
    known = dataset_ingredients()
    products, forms, holders = [], {}, {}
    matched = packs = 0

    def intern(table: dict, value: str) -> int:
        if value not in table:
            table[value] = len(table)
        return table[value]

    for r in rows:
        if r['Rodzaj preparatu'] != 'Ludzki':
            continue
        inn = r['Nazwa powszechnie stosowana'].strip()
        ing = ingredients(inn, known)
        lines = [ln.strip() for ln in r['Opakowanie'].split('\n')]
        pack_list = []
        for i, line in enumerate(lines):
            m = PACK_RE.match(line)
            if m:
                desc = lines[i + 1] if i + 1 < len(lines) and not PACK_RE.match(lines[i + 1]) else ''
                g = m.group(1).zfill(14)
                g13 = g[1:] if g.startswith('0') else g
                pack_list.append('|'.join((g13, m.group(2).strip(), desc.replace(';', ',').replace('|', '/'))))
        if not pack_list:
            continue
        form = r['Postać farmaceutyczna'].strip()
        products.append([r['Nazwa Produktu Leczniczego'].strip(), inn, ing, r['Moc'].strip(),
                         intern(forms, FORMS.get(form, form)), r['Kod ATC'].strip(),
                         intern(holders, r['Podmiot odpowiedzialny'].strip()),
                         r['Identyfikator Produktu Leczniczego'].strip(), ';'.join(pack_list)])
        packs += len(pack_list)
        if any(p in known for p in ing.split(' + ')):
            matched += 1
    out = {'source': SOURCE, 'date': datetime.date.today().isoformat(), 'forms': list(forms),
           'holders': list(holders), 'products': products}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    size = OUT.stat().st_size
    print(f'{len(products)} products ({matched} with a dataset ingredient), {packs} packs, '
          f'{size / 1e6:.1f} MB -> {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
