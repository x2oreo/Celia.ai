import { assertEquals } from 'jsr:@std/assert@1';
import { resolveHit, type ResolveDeps } from './resolve.ts';
import type { RawHit } from './sources.ts';

const RX: Record<string, string[]> = {
  acetaminophen: ['acetaminophen'],
  'tylenol extra strength': ['acetaminophen'],
  'valproate sodium': ['valproic acid'],
  'nurofen cold and flu': ['ibuprofen', 'pseudoephedrine'],
};

function deps(translate = true): ResolveDeps {
  return {
    normalise: (n) => Promise.resolve(RX[n.toLowerCase()] ?? []),
    translate: translate
      ? (names) => Promise.resolve(names.map((n) => n === 'VALPROATO SODIO' ? 'valproate sodium' : ''))
      : null,
  };
}

function hit(over: Partial<RawHit>): RawHit {
  return { brand: 'X', ingredients: [], english: true, strength: '', form: '', method: 'REGISTRY', source: 's',
    sourceUrl: 'u', rank: 1, ...over };
}

Deno.test('English registry ingredient resolves directly', async () => {
  const c = (await resolveHit(hit({ ingredients: ['ACETAMINOPHEN'] }), 'g', 'US', deps()))!;
  assertEquals([c.ingredients, c.unresolved], [['acetaminophen'], []]);
});

Deno.test('foreign INN goes through translation, validated by RxNav', async () => {
  const c = (await resolveHit(hit({ ingredients: ['VALPROATO SODIO'], english: false }), 'g', 'ES', deps()))!;
  assertEquals(c.ingredients, ['valproic acid']);
});

Deno.test('without AI a foreign-only box is not a candidate', async () => {
  assertEquals(await resolveHit(hit({ ingredients: ['VALPROATO SODIO'], english: false }), 'g', 'ES', deps(false)), null);
});

Deno.test('an unresolved ingredient is kept as printed so the check says UNKNOWN for it', async () => {
  const c = (await resolveHit(hit({ ingredients: ['ACETAMINOPHEN', 'MYSTERYINE'] }), 'g', 'US', deps()))!;
  assertEquals([c.ingredients, c.unresolved], [['acetaminophen', 'mysteryine'], ['mysteryine']]);
});

Deno.test('name-only source must resolve through its brand', async () => {
  const c = (await resolveHit(hit({ brand: 'Nurofen Cold and Flu', method: 'PRODUCT_DB' }), 'g', 'GB', deps()))!;
  assertEquals(c.ingredients, ['ibuprofen', 'pseudoephedrine']);
  assertEquals(await resolveHit(hit({ brand: 'Chocolate' }), 'g', '', deps()), null);
});
