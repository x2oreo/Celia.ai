// Run: npx -y deno test backend/supabase/functions/box-identify/
// Fixtures are trimmed real responses (openFDA, AEMPS CIMA, UPCitemdb, Open Food Facts).
import { assertEquals } from 'jsr:@std/assert@1';
import { parseCima, parseFdaUpc, parseOff, parseUpcItem, splitIngredients, strengthOf } from './sources.ts';

Deno.test('openFDA label by UPC → brand + English substances', () => {
  const h = parseFdaUpc({ results: [{ set_id: 's1', openfda: { brand_name: ['Tylenol Extra Strength'],
    substance_name: ['ACETAMINOPHEN'], route: ['ORAL'] } }] })!;
  assertEquals([h.brand, h.ingredients, h.english, h.method], ['Tylenol Extra Strength', ['ACETAMINOPHEN'], true, 'REGISTRY']);
  assertEquals(parseFdaUpc({ results: [] }), null);
  assertEquals(parseFdaUpc(null), null);
});

Deno.test('CIMA → brand, Spanish ingredients, strength', () => {
  const h = parseCima({ resultados: [{ nregistro: '48827',
    nombre: 'DEPAKINE 200 mg COMPRIMIDOS GASTRORRESISTENTES , 40 comprimidos', pactivos: 'VALPROATO SODIO' }] })!;
  assertEquals([h.brand, h.ingredients, h.english, h.strength], ['DEPAKINE', ['VALPROATO SODIO'], false, '200 mg']);
});

Deno.test('UPCitemdb → active ingredients from description; non-medicines are ignored', () => {
  const h = parseUpcItem({ items: [{ title: 'Tylenol Extra Strength Caplet / ACETAMINOPHEN / TABLET',
    brand: 'Tylenol Extra Strength', description: 'Active Ingredients: ACETAMINOPHEN 500mg',
    category: 'Health & Beauty > Health Care > Medicine & Drugs' }] }, '0300450449108')!;
  assertEquals([h.brand, h.ingredients, h.strength, h.form], ['Tylenol Extra Strength', ['ACETAMINOPHEN'], '500mg', 'tablet']);
  assertEquals(parseUpcItem({ items: [{ title: 'Chocolate bar', category: 'Food' }] }, 'x'), null);
});

Deno.test('Open Food Facts → product name only', () => {
  const h = parseOff({ status: 1, product: { product_name: 'Tylenol extra strength' } }, 'world.openfoodfacts.org', 'g')!;
  assertEquals([h.brand, h.ingredients.length, h.method], ['Tylenol extra strength', 0, 'PRODUCT_DB']);
  assertEquals(parseOff({ status: 0 }, 'h', 'g'), null);
  assertEquals(parseOff({ status: 1, product: { product_name: '' } }, 'h', 'g'), null);
});

Deno.test('ingredient splitting and strengths', () => {
  assertEquals(splitIngredients('ACETAMINOPHEN 500mg, Caffeine 65 mg'), ['ACETAMINOPHEN', 'Caffeine']);
  assertEquals(splitIngredients('paracetamol + pseudoephedrine (hydrochloride)'), ['paracetamol', 'pseudoephedrine']);
  assertEquals(strengthOf('Klacid 500 mg tabl.'), '500 mg');
  assertEquals(strengthOf('no numbers'), '');
});
