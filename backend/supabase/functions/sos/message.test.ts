// Run: npx -y deno test backend/supabase/functions/sos/
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { buildSosMessage, escapeXml, isE164, parseSosPayload, type PatientContext } from './message.ts';

const CTX: PatientContext = { name: 'Anna', genotype: 'LQT2', riskyDrug: null };

Deno.test('parse: valid fall payload with location', () => {
  const p = parseSosPayload({ reason: 'fall', bpm: 171.6, activity: 'still', lat: 50.0614, lon: 19.9366, accuracyM: 12.4 });
  assertEquals(p, { reason: 'fall', bpm: 172, activity: 'still', lat: 50.0614, lon: 19.9366, accuracyM: 12 });
});

Deno.test('parse: rejects unknown reason and non-objects', () => {
  assertEquals(parseSosPayload({ reason: 'party', bpm: 80 }), null);
  assertEquals(parseSosPayload(null), null);
  assertEquals(parseSosPayload('sos'), null);
});

Deno.test('parse: drops implausible bpm and half or out-of-range locations', () => {
  assertEquals(parseSosPayload({ reason: 'need_help', bpm: 900 })?.bpm, 0);
  assertEquals(parseSosPayload({ reason: 'need_help', bpm: 'fast' })?.bpm, 0);
  assertEquals(parseSosPayload({ reason: 'need_help', bpm: 90, lat: 50 })?.lat, undefined);
  assertEquals(parseSosPayload({ reason: 'need_help', bpm: 90, lat: 95, lon: 10 })?.lat, undefined);
});

Deno.test('message: fall with location, genotype and drug', () => {
  const p = parseSosPayload({ reason: 'fall', bpm: 172, lat: 50.0614, lon: 19.9366, accuracyM: 12 })!;
  const m = buildSosMessage(p, { ...CTX, riskyDrug: 'clarithromycin' });
  assertStringIncludes(m.sms, 'Anna may have fainted');
  assertStringIncludes(m.sms, 'Long QT syndrome (LQT2)');
  assertStringIncludes(m.sms, 'Heart rate 172 bpm');
  assertStringIncludes(m.sms, 'clarithromycin');
  assertStringIncludes(m.sms, 'https://maps.google.com/?q=50.06140,19.93660 (±12 m)');
  assertStringIncludes(m.sms, 'Call 112');
  assert(!m.voice.includes('http'), 'voice text must not contain URLs');
});

Deno.test('message: still useful with no name, genotype, bpm or location', () => {
  const m = buildSosMessage({ reason: 'need_help', bpm: 0 }, { name: null, genotype: 'UNKNOWN', riskyDrug: null });
  assertStringIncludes(m.sms, 'Your contact pressed SOS');
  assertStringIncludes(m.sms, 'Has Long QT syndrome.');
  assertStringIncludes(m.sms, 'Location unknown.');
  assert(!m.sms.includes('bpm'));
  assert(m.sms.length <= 459, `SMS too long: ${m.sms.length}`);
});

Deno.test('isE164', () => {
  assert(isE164('+48123456789'));
  assert(!isE164('48123456789'));
  assert(!isE164('+48 123 456 789'));
  assert(!isE164('+0123456789'));
});

Deno.test('escapeXml neutralises TwiML injection via patient name', () => {
  assertEquals(escapeXml('<Dial>&"\''), '&lt;Dial&gt;&amp;&quot;&apos;');
});
