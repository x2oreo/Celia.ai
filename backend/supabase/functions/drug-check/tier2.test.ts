// Run: npx -y deno test backend/supabase/functions/drug-check/
import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { type CachedLabel, checkByLabel, checkQuery, type CuratedRow, type Tier2Deps } from './tier2.ts';
import type { FdaLabel } from '../_shared/labelRisk.ts';

const LABELS: Record<string, FdaLabel[] | null> = {
  escitalopram: [{ set_id: 's-esc', adverse_reactions: ['Cardiac: QT prolongation, bradycardia.'] }],
  hydroxyzine: [{ set_id: 's-hyd', precautions: ['Cases of QT prolongation and Torsade de Pointes have been reported.'] }],
  metformin: [{ set_id: 's-met', warnings: ['Lactic acidosis.'] }],
  sucrose: [],
  flaky: null,
};

function deps(over: Partial<Tier2Deps> = {}): Tier2Deps & { puts: string[] } {
  const puts: string[] = [];
  const cache = new Map<string, CachedLabel>();
  const curated: Record<string, CuratedRow> = {
    azithromycin: { ingredient: 'azithromycin', risk: 'KNOWN_RISK', drug_class: 'Macrolide antibiotic' },
  };
  const names: Record<string, string[]> = {
    lexapro: ['escitalopram'], zithromax: ['azithromycin'], atarax: ['hydroxyzine'], glucophage: ['metformin'],
    combo: ['metformin', 'hydroxyzine'], sugarpill: ['sucrose'], flakyname: ['flaky'],
    mixunknown: ['metformin', 'sucrose'],
  };
  return {
    puts,
    normalise: (n) => Promise.resolve(names[n] ?? []),
    curated: (i) => Promise.resolve(curated[i] ?? null),
    cacheGet: (i) => Promise.resolve(cache.get(i) ?? null),
    cachePut: (i, v) => { puts.push(i); cache.set(i, v); return Promise.resolve(); },
    labels: (i) => Promise.resolve(i in LABELS ? LABELS[i] : []),
    ...over,
  };
}

Deno.test('brand RxNav maps onto the curated list → curated verdict wins', async () => {
  const f = await checkByLabel('zithromax', deps());
  assertEquals([f.ingredient, f.risk, f.method], ['azithromycin', 'KNOWN_RISK', 'LIST']);
});

Deno.test('label in adverse reactions → CONDITIONAL_RISK with snippet and set id', async () => {
  const f = await checkByLabel('lexapro', deps());
  assertEquals([f.ingredient, f.risk, f.method, f.setId], ['escitalopram', 'CONDITIONAL_RISK', 'FDA_LABEL', 's-esc']);
  assertStringIncludes(f.snippet, 'QT prolongation');
  assertStringIncludes(f.reason, 'side effects');
});

Deno.test('label without QT wording → NOT_LISTED, never "safe"', async () => {
  const f = await checkByLabel('glucophage', deps());
  assertEquals(f.risk, 'NOT_LISTED');
  assertStringIncludes(f.reason, 'ask your pharmacist');
});

Deno.test('combination product takes the worst ingredient', async () => {
  const f = await checkByLabel('combo', deps());
  assertEquals([f.ingredient, f.risk], ['hydroxyzine', 'POSSIBLE_RISK']);
});

Deno.test('one part without any label keeps the whole product UNKNOWN', async () => {
  assertEquals((await checkByLabel('mixunknown', deps())).risk, 'UNKNOWN_DRUG');
});

Deno.test('RxNav does not know the name → UNKNOWN_DRUG', async () => {
  assertEquals((await checkByLabel('qwerty', deps())).risk, 'UNKNOWN_DRUG');
});

Deno.test('no label is cached as NO_LABEL; openFDA errors are not cached', async () => {
  const d = deps();
  assertEquals((await checkByLabel('sugarpill', d)).risk, 'UNKNOWN_DRUG');
  assertEquals((await checkByLabel('flakyname', d)).risk, 'UNKNOWN_DRUG');
  assertEquals(d.puts, ['sucrose']);
});

Deno.test('second lookup is served from cache', async () => {
  let fetches = 0;
  const d = deps({ labels: (i) => { fetches++; return Promise.resolve(LABELS[i] ?? []); } });
  await checkByLabel('atarax', d);
  const f = await checkByLabel('atarax', d);
  assertEquals([fetches, f.risk], [1, 'POSSIBLE_RISK']);
});

Deno.test('checkQuery: multi-word ingredient is resolved as a phrase, never word by word', async () => {
  const d = deps({ normalise: (n) => Promise.resolve(({ 'ascorbic acid': ['ascorbic acid'], acid: ['sodium bicarbonate'] } as Record<string, string[]>)[n] ?? []),
    labels: () => Promise.resolve([{ set_id: 'vit', warnings: ['None.'] }]) });
  const tier1 = (w: string) => Promise.resolve(w === 'aspirin'
    ? { ingredient: 'aspirin', risk: 'NOT_LISTED' as const, method: 'LIST' as const, reason: 'NSAID', snippet: '', setId: '' } : null);
  const f = await checkQuery('aspirin + ascorbic acid', tier1, d);
  assertEquals(f.map((x) => x.ingredient), ['aspirin', 'ascorbic acid']);
});

Deno.test('checkQuery: brand words next to a listed drug still go through RxNav as one phrase', async () => {
  const d = deps({ normalise: (n) => Promise.resolve(n === 'nurofen cold flu' ? ['ibuprofen', 'hydroxyzine'] : []) });
  const tier1 = (w: string) => Promise.resolve(w === 'nurofen'
    ? { ingredient: 'ibuprofen', risk: 'NOT_LISTED' as const, method: 'LIST' as const, reason: '', snippet: '', setId: '' } : null);
  const f = await checkQuery('Nurofen Cold & Flu', tier1, d);
  assertEquals(f.some((x) => x.risk === 'POSSIBLE_RISK'), true);   // hydroxyzine label in fixtures
});

Deno.test('checkQuery: unknown words without a phrase match stay UNKNOWN', async () => {
  const f = await checkQuery('Klacid mysteryword', (w) => Promise.resolve(w === 'klacid'
    ? { ingredient: 'clarithromycin', risk: 'KNOWN_RISK' as const, method: 'LIST' as const, reason: '', snippet: '', setId: '' } : null), deps());
  assertEquals(f.map((x) => x.risk), ['KNOWN_RISK', 'UNKNOWN_DRUG']);
});

Deno.test('checkQuery: a phrase RxNav knows is never split into words, even without a label', async () => {
  const d = deps({ normalise: (n) => Promise.resolve(({ 'sodium valproate': ['valproate'], sodium: ['sodium'] } as Record<string, string[]>)[n] ?? []),
    labels: (i) => Promise.resolve(i === 'valproate' ? null : [{ set_id: 'na', warnings: ['None.'] }]) });
  const f = await checkQuery('sodium valproate', () => Promise.resolve(null), d);
  assertEquals(f.map((x) => [x.ingredient, x.risk]), [['valproate', 'UNKNOWN_DRUG']]);
});
