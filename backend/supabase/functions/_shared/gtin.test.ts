// Run: npx -y deno test backend/supabase/functions/_shared/gtin.test.ts
import { assertEquals } from 'jsr:@std/assert@1';
import { gtinCheckDigitOk, gtinCountry, normaliseGtin, spanishCn } from './gtin.ts';

Deno.test('check digit: real Tylenol UPC, Klacid PL and a typo', () => {
  assertEquals(gtinCheckDigitOk('0300450449108'), true);
  assertEquals(gtinCheckDigitOk('5909990331710'), true);
  assertEquals(gtinCheckDigitOk('5909990331711'), false);
  assertEquals(gtinCheckDigitOk('abc'), false);
});

Deno.test('normalise: UPC-A gets a leading 0, GTIN-14 with leading 0 shortens, bad codes are null', () => {
  assertEquals(normaliseGtin('300450449108'), '0300450449108');
  assertEquals(normaliseGtin('05909990331710'), '5909990331710');
  assertEquals(normaliseGtin(' 5909990331710 '), '5909990331710');
  assertEquals(normaliseGtin('5909990331711'), null);
  assertEquals(normaliseGtin('15909990331717'), null);
});

Deno.test('spanish CN is extracted only from 847000 codes', () => {
  assertEquals(spanishCn('8470006500064'), '650006');
  assertEquals(spanishCn('5909990331710'), null);
});

Deno.test('country from GS1 prefix', () => {
  assertEquals(gtinCountry('0300450449108'), 'US');
  assertEquals(gtinCountry('5909990331710'), 'PL');
  assertEquals(gtinCountry('3800010650014'), 'BG');
  assertEquals(gtinCountry('8470006500064'), 'ES');
  assertEquals(gtinCountry('9990000000001'), '');
});
