// Run: npx -y deno test backend/supabase/functions/_shared/labelRisk.test.ts
// Fixtures are trimmed from real openFDA drug labels (api.fda.gov/drug/label.json).
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { classifyLabel, type FdaLabel, worstLabel } from './labelRisk.ts';

const METHADONE: FdaLabel = {
  set_id: '092d78eb-6423-495c-bf0d-e6532bea7138',
  boxed_warning: ['Life-Threatening QT Prolongation QT interval prolongation and serious arrhythmia (torsades de ' +
    'pointes) have occurred during treatment with methadone.'],
  adverse_reactions: ['QT Prolongation (see WARNINGS)'],
};

const CITALOPRAM: FdaLabel = {
  set_id: '0109f365-bebd-4810-a56f-4451e10245db',
  warnings_and_cautions: ['5 WARNINGS AND PRECAUTIONS 5.1 Suicidal thoughts. 5.2 QT-Prolongation and Torsade de ' +
    'Pointes: Dose-dependent QTc prolongation, Torsade de pointes, ventricular tachycardia, and sudden death have ' +
    'been reported with citalopram.'],
  adverse_reactions: ['QT-prolongation and torsade de pointes [see Warnings and Precautions (5.2)]'],
};

const INTERACTION_ONLY: FdaLabel = {
  set_id: 'x-1',
  warnings: ['May cause dizziness. Do not drive until you know how it affects you.'],
  drug_interactions: ['Coadministration with drugs that prolong the QT interval may increase the risk of ' +
    'ventricular arrhythmias.'],
};

const AMOXICILLIN: FdaLabel = {
  set_id: '00b86913-50c8-443f-8467-f4f499d358af',
  warnings_and_cautions: ['Anaphylactic reactions have been reported. Clostridioides difficile-associated diarrhea.'],
  adverse_reactions: ['Diarrhea, rash, nausea.'],
};

const PHARMACOLOGY_ONLY: FdaLabel = {
  set_id: 'x-2',
  clinical_pharmacology: ['In a thorough QT study, the drug had no clinically relevant effect on the QTc interval.'],
};

Deno.test('boxed warning about QT → KNOWN_RISK', () => {
  const r = classifyLabel(METHADONE);
  assertEquals(r.risk, 'KNOWN_RISK');
  assertEquals(r.section, 'boxed_warning');
  assertStringIncludes(r.snippet.toLowerCase(), 'qt interval prolongation');
});

Deno.test('warnings section about QT → POSSIBLE_RISK, snippet is the matching sentence', () => {
  const r = classifyLabel(CITALOPRAM);
  assertEquals(r.risk, 'POSSIBLE_RISK');
  assertEquals(r.section, 'warnings_and_cautions');
  assertStringIncludes(r.snippet, 'QTc prolongation');
  assert(!r.snippet.includes('Suicidal'), 'snippet should start at the QT sentence');
});

Deno.test('QT only in interactions / adverse reactions → CONDITIONAL_RISK', () => {
  const r = classifyLabel(INTERACTION_ONLY);
  assertEquals(r.risk, 'CONDITIONAL_RISK');
  assertEquals(r.section, 'drug_interactions');
});

Deno.test('label without QT wording → NOT_LISTED', () => {
  const r = classifyLabel(AMOXICILLIN);
  assertEquals(r.risk, 'NOT_LISTED');
  assertEquals(r.section, '');
  assertEquals(r.snippet, '');
});

Deno.test('clinical pharmacology QT studies are ignored (often "no effect")', () => {
  assertEquals(classifyLabel(PHARMACOLOGY_ONLY).risk, 'NOT_LISTED');
});

Deno.test('congenital long QT warning counts', () => {
  const r = classifyLabel({ set_id: 'x-3', warnings: ['Avoid in patients with congenital long QT syndrome.'] });
  assertEquals(r.risk, 'POSSIBLE_RISK');
});

Deno.test('snippet is capped', () => {
  const long = 'QT prolongation was seen ' + 'and more '.repeat(100) + '.';
  assert(classifyLabel({ set_id: 'x-4', warnings: [long] }).snippet.length <= 241);
});

Deno.test('worstLabel: worst of several labels wins and keeps its set_id', () => {
  const r = worstLabel([AMOXICILLIN, INTERACTION_ONLY, METHADONE, CITALOPRAM]);
  assertEquals(r.risk, 'KNOWN_RISK');
  assertEquals(r.setId, METHADONE.set_id);
  assertEquals(worstLabel([AMOXICILLIN]).setId, AMOXICILLIN.set_id);
  assertEquals(worstLabel([]).risk, 'NOT_LISTED');
});

Deno.test('snippet of a long run-on heading starts at the QT wording', () => {
  const text = 'Monitor and treat promptly per standard of care until signs and symptoms resolve ( 5.1 ) QT ' +
    'Interval Prolongation and Torsade de Pointes : Avoid in patients with congenital long QT syndrome.';
  assert(classifyLabel({ warnings: [text] }).snippet.startsWith('QT Interval Prolongation'));
});
