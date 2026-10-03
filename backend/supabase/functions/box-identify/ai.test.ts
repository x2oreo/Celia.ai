import { assertEquals } from 'jsr:@std/assert@1';
import { validateWebResult, type WebResult } from './ai.ts';

const GOOD: WebResult = { found: true, brand: 'Nurofen Forte', ingredients: ['ibuprofen'], strength: '400 mg',
  form: 'Tablets', sourceUrl: 'https://www.apteka.example/nurofen-forte-400', confidence: 'HIGH' };

Deno.test('accepts a sourced, confident answer', () => {
  const h = validateWebResult(GOOD, ['https://apteka.example/nurofen-forte-400?x=1'], '')!;
  assertEquals([h.brand, h.ingredients, h.form, h.source], ['Nurofen Forte', ['ibuprofen'], 'tablets',
    'Web search (apteka.example)']);
});

Deno.test('rejects guesses, misses and unsourced answers', () => {
  assertEquals(validateWebResult({ ...GOOD, found: false }, [], ''), null);
  assertEquals(validateWebResult({ ...GOOD, confidence: 'LOW' }, [], ''), null);
  assertEquals(validateWebResult({ ...GOOD, ingredients: [] }, [], ''), null);
  assertEquals(validateWebResult({ ...GOOD, sourceUrl: 'http://insecure.example' }, [], ''), null);
  assertEquals(validateWebResult({ ...GOOD, sourceUrl: 'not a url' }, [], ''), null);
});

Deno.test('rejects a source URL the model never opened', () => {
  assertEquals(validateWebResult(GOOD, ['https://other.example/page'], ''), null);
});

Deno.test('rejects an answer with no citation at all', () => {
  assertEquals(validateWebResult(GOOD, [], ''), null);
});

Deno.test('caps lengths', () => {
  const h = validateWebResult({ ...GOOD, ingredients: Array(10).fill('x'.repeat(100)) },
    ['https://apteka.example/nurofen-forte-400'], '')!;
  assertEquals([h.ingredients.length, h.ingredients[0].length], [6, 60]);
});
