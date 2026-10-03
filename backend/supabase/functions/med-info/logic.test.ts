// npx -y deno test backend/supabase/functions/med-info/
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { BANNED, cleanReply } from './logic.ts';

Deno.test('banned words catch whole word families', () => {
  for (const t of ['arrhythmia', 'Arrhythmias', 'torsades de pointes', 'QTc', 'QT prolongation', '500 mg',
    '500mg', '2.5 mg', 'stop taking it', 'heart rhythm problems']) {
    assert(BANNED.test(t), t);
  }
});

Deno.test('ordinary leaflet text passes', () => {
  for (const t of ['Take with food.', 'May cause drowsiness.', 'An antibiotic for chest infections.', 'Keep below 25°C']) {
    assert(!BANNED.test(t), t);
  }
});

Deno.test('cleanReply drops unrecognised, empty and unsafe replies', () => {
  assertEquals(cleanReply({ recognised: false, summary: 'x' }), undefined);
  assertEquals(cleanReply({ recognised: true, summary: '' }), undefined);
  assertEquals(cleanReply({ recognised: true, summary: 'Can cause arrhythmias.', tips: [] }), undefined);
  const ok = cleanReply({ recognised: true, summary: 'An antibiotic.', contains: 'Amoxicillin', usedFor: 'Infections',
    tips: ['Finish the course.', '', 'a', 'b'] });
  assertEquals(ok?.tips, ['Finish the course.', 'a']);   // capped at 3, then blanks dropped
});
