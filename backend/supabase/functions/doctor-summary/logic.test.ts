// npx -y deno test backend/supabase/functions/doctor-summary/
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { checkSummary, parseInput } from './logic.ts';

Deno.test('summary must never reassure or dose', () => {
  assertEquals(checkSummary('Clarithromycin is safe with her medicines.'), undefined);
  assertEquals(checkSummary('Ondansetron carries no risk for this patient today.'), undefined);
  assertEquals(checkSummary('Give nadolol 40 mg twice daily as usual.'), undefined);
  assertEquals(checkSummary('Stop taking escitalopram before the procedure.'), undefined);
  assertEquals(checkSummary('short'), undefined);
  assertEquals(checkSummary(42), undefined);
});

Deno.test('a factual summary passes', () => {
  const s = checkSummary('LQT2 patient on nadolol. Two current medicines are on the known-risk list and interact ' +
    'via CYP3A4. Three heart-rate alerts in 90 days.');
  assert(s !== undefined);
});

Deno.test('input is clipped and typed', () => {
  assertEquals(parseInput({ specialty: '' }), undefined);
  const i = parseInput({ specialty: 'Dentist', genotype: 'LQT9', medicines: ['a', 3, 'b'], heartAlerts: -2, symptoms: 2.7 });
  assertEquals(i?.genotype, 'UNKNOWN');
  assertEquals(i?.medicines, ['a', 'b']);
  assertEquals(i?.heartAlerts, 0);
  assertEquals(i?.symptoms, 2);
  const s = parseInput({ specialty: 'GP', medicines: 'Nadolol — not listed\n\nKlacid — known risk', heartAlerts: '3' });
  assertEquals(s?.medicines, ['Nadolol — not listed', 'Klacid — known risk']);
  assertEquals(s?.heartAlerts, 3);
});
