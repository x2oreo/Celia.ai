#!/usr/bin/env python3
"""Generate site/card/data.js for the emergency-card viewer from the app's own sources (single source of truth):
- card text in 13 languages  <- app/entry/src/main/ets/common/CardStrings.ets
- emergency numbers          <- app/entry/src/main/ets/common/EmergencyNumbers.ets
- long QT facts (English)    <- app/entry/src/main/ets/emergency/LqtsFacts.ets

Run by the Pages workflow before deploying; also run it locally after changing either file.
Usage:  python3 data/export_card_site.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARD = ROOT / 'app/entry/src/main/ets/common/CardStrings.ets'
NUMBERS = ROOT / 'app/entry/src/main/ets/common/EmergencyNumbers.ets'
FACTS = ROOT / 'app/entry/src/main/ets/emergency/LqtsFacts.ets'
OUT = ROOT / 'site/card/data.js'

FIELDS = ['code', 'language', 'title', 'condition', 'avoid', 'treatment', 'icdYes', 'icdNo', 'genotype', 'meds',
          'contacts', 'notes', 'noMeds']
TOKEN = re.compile(r"'((?:[^'\\]|\\.)*)'|(\+)|(\))")


def call_args(src: str, start: int) -> tuple:
    """String-literal arguments of the call starting at `start` (just after '('); 'a' + 'b' is joined."""
    args, pending, i = [], None, start
    while True:
        m = TOKEN.search(src, i)
        if m is None:
            raise ValueError('unterminated call')
        lit, plus, close = m.groups()
        i = m.end()
        if lit is not None:
            value = lit.replace("\\'", "'").replace('\\\\', '\\')
            if pending == '+':
                args[-1] += value
            else:
                args.append(value)
            pending = None
        elif plus:
            pending = '+'
        elif close:
            return args, i


def card_texts() -> list:
    src = CARD.read_text(encoding='utf-8')
    body = src[src.index('export const CARD_TEXTS'):]
    texts = []
    for m in re.finditer(r"\bt\(", body):
        args, _ = call_args(body, m.end())
        if len(args) != len(FIELDS):
            raise ValueError(f'card text {args[:1]} has {len(args)} fields, expected {len(FIELDS)}')
        texts.append(dict(zip(FIELDS, args)))
    return texts


STRING = re.compile(r"'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`|(\+)")


def strings_in(src: str) -> list:
    """String literals in `src` in order; 'a' + 'b' is joined, `${x}` stays as {x}."""
    out, pending = [], False
    for lit, tpl, plus in STRING.findall(src):
        if plus:
            pending = True
            continue
        raw = lit if lit or not tpl else tpl
        value = raw.replace("\\'", "'").replace('\\\\', '\\').replace('${', '{')
        if pending and out:
            out[-1] += value
        else:
            out.append(value)
        pending = False
    return out


def block(src: str, start: str, end: str) -> str:
    i = src.index(start) + len(start)
    return src[i:src.index(end, i)]


def facts() -> dict:
    """The fixed English facts of the full emergency card (layers 3 and 4), for the web card."""
    src = FACTS.read_text(encoding='utf-8')
    genotypes = []
    for name in ['LQT1', 'LQT2', 'LQT3', 'UNKNOWN']:
        body = block(src, f'const {name}: GenotypeFacts = {{', '\n};')
        g = {'genotype': name}
        for key in ['name', 'gene', 'share', 'ecg', 'treatment']:
            m = re.search(rf"\b{key}: ((?:'(?:[^'\\]|\\.)*'\s*\+?\s*)+)", body)
            g[key] = ''.join(strings_in(m.group(1))) if m else ''
        for key in ['triggers', 'emergencyNotes']:
            g[key] = strings_in(block(body, f'{key}: [', ']'))
        genotypes.append(g)
    steps_src = block(src, 'export function protocolSteps(', '\n}\n')
    pairs = re.findall(r"step: '((?:[^'\\]|\\.)*)',\s*detail: ([`'])((?:(?!\2).)*)\2", steps_src, re.S)
    steps = [{'step': st.replace("\\'", "'"), 'detail': de.replace("\\'", "'").replace('${emergencyNumber}', '{number}'),
              'icdOnly': 'ICD' in st} for st, _, de in pairs]
    return {
        'overview': strings_in(block(src, 'export const LQTS_OVERVIEW: string[] = [', '];')),
        'precautions': strings_in(block(src, 'export const GENERAL_PRECAUTIONS: string[] = [', '];')),
        'steps': steps,
        'torsadesIntro': strings_in(block(src, 'export const TORSADES_INTRO: string =', ';'))[0],
        'torsades': strings_in(block(src, 'export const TORSADES_STEPS: string[] = [', '];')),
        'doNotUse': strings_in(block(src, 'export const DO_NOT_USE: string[] = [', '];')),
        'genotypes': genotypes,
    }


def numbers() -> dict:
    src = NUMBERS.read_text(encoding='utf-8')
    body = src[src.index('export const EMERGENCY_NUMBERS'):src.index('export const FALLBACK')]
    out = {}
    for code, name, ambulance, general in re.findall(r"c\('(\w+)', '([^']+)', '(\w+)', '(\w+)'\)", body):
        out[code] = {'name': name, 'ambulance': ambulance, 'general': general}
    return out


def main() -> None:
    texts, nums, lqts = card_texts(), numbers(), facts()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('// Generated by data/export_card_site.py from the app sources - do not edit by hand.\n'
                   f'window.CARD_TEXTS = {json.dumps(texts, ensure_ascii=False, indent=1)};\n'
                   f'window.EMERGENCY_NUMBERS = {json.dumps(nums, ensure_ascii=False)};\n'
                   f'window.LQTS_FACTS = {json.dumps(lqts, ensure_ascii=False, indent=1)};\n', encoding='utf-8')
    print(f'{len(texts)} languages, {len(nums)} countries -> {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
