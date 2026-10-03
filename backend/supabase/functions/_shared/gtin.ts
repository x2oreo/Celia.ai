// GTIN helpers for /box-identify. Pure, no I/O (tested in gtin.test.ts). Mirrors the app's drugs/Gs1.ets.

export function gtinCheckDigitOk(gtin: string): boolean {
  if (!/^[0-9]{8,14}$/.test(gtin)) {
    return false;
  }
  const d = gtin.padStart(14, '0');
  let sum = 0;
  for (let i = 0; i < 13; i++) {
    sum += (d.charCodeAt(i) - 48) * (i % 2 === 0 ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10 === d.charCodeAt(13) - 48;
}

// 8/12/13/14-digit code with a valid check digit → 13 digits (UPC-A gets its leading 0), else null.
export function normaliseGtin(raw: string): string | null {
  const s = raw.trim();
  if (!gtinCheckDigitOk(s)) {
    return null;
  }
  if (s.length === 14) {
    return s.startsWith('0') ? s.slice(1) : null;   // a real GTIN-14 (packaging level) is not a box code
  }
  return s.length === 8 ? s : s.padStart(13, '0');
}

// Spanish medicine boxes carry the 6-digit Código Nacional: 847000 + CN + check digit.
export function spanishCn(gtin13: string): string | null {
  return /^847000[0-9]{7}$/.test(gtin13) ? gtin13.slice(6, 12) : null;
}

// GS1 prefix → ISO country (only prefixes we name in the UI; '' otherwise). Not where the box was sold, but close.
const PREFIXES: Array<[number, number, string]> = [
  [0, 139, 'US'], [300, 379, 'FR'], [380, 380, 'BG'], [400, 440, 'DE'], [500, 509, 'GB'], [539, 539, 'IE'],
  [540, 549, 'BE'], [560, 560, 'PT'], [590, 590, 'PL'], [594, 594, 'RO'], [599, 599, 'HU'], [640, 649, 'FI'],
  [690, 699, 'CN'], [700, 709, 'NO'], [730, 739, 'SE'], [760, 769, 'CH'], [800, 839, 'IT'], [840, 849, 'ES'],
  [858, 858, 'SK'], [859, 859, 'CZ'], [860, 860, 'RS'], [868, 869, 'TR'], [870, 879, 'NL'], [880, 880, 'KR'],
  [900, 919, 'AT'], [930, 939, 'AU'], [940, 949, 'NZ'],
];

export function gtinCountry(gtin13: string): string {
  const p = Number(gtin13.slice(0, 3));
  return PREFIXES.find(([lo, hi]) => p >= lo && p <= hi)?.[2] ?? '';
}
