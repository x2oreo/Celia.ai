// Medicine-box barcodes (F-36): EAN-13 / GTIN-14 and GS1 DataMatrix (EU Falsified Medicines Directive codes
// carry the GTIN in AI (01)). Pure parsing + check-digit validation — unit tested.
//
// GTIN → ingredient needs a product database (national registers). This build ships a DEMO table in the GS1
// restricted-circulation range 20x (never assigned to real products) so the flow can be tested end to end;
// unknown GTINs fall back to "type the name on the box".

export function gtinCheckDigitOk(gtin: string): boolean {
  if (!/^[0-9]{8,14}$/.test(gtin)) {
    return false;
  }
  const digits: string = gtin.padStart(14, '0');
  let sum: number = 0;
  for (let i = 0; i < 13; i++) {
    const n: number = digits.charCodeAt(i) - 48;
    sum += i % 2 === 0 ? n * 3 : n;
  }
  return (10 - (sum % 10)) % 10 === digits.charCodeAt(13) - 48;
}

// Returns a 13-digit GTIN (14-digit GTINs with a leading 0 are shortened) or undefined.
export function parseGs1(payload: string): string | undefined {
  let p: string = payload.trim();
  if (p.startsWith(']d2') || p.startsWith(']C1') || p.startsWith(']Q3')) {
    p = p.substring(3);
  }
  p = p.replace(/\u001d/g, '');
  let gtin: string | undefined = undefined;
  if (/^[0-9]{13}$/.test(p) || /^[0-9]{14}$/.test(p) || /^[0-9]{8}$/.test(p)) {
    gtin = p;
  } else if (p.startsWith('01') && p.length >= 16 && /^[0-9]{14}$/.test(p.substring(2, 16))) {
    gtin = p.substring(2, 16);
  } else {
    const m: RegExpMatchArray | null = p.match(/\(01\)([0-9]{14})/);
    if (m !== null) {
      gtin = m[1];
    }
  }
  if (gtin === undefined || !gtinCheckDigitOk(gtin)) {
    return undefined;
  }
  return gtin.length === 14 && gtin.startsWith('0') ? gtin.substring(1) : gtin;
}

export interface GtinEntry {
  gtin: string;
  product: string;
  ingredient: string;
}

function g(gtin: string, product: string, ingredient: string): GtinEntry {
  const e: GtinEntry = { gtin: gtin, product: product, ingredient: ingredient };
  return e;
}

// DEMO codes (GS1 prefix 200 = restricted circulation, not real products).
export const DEMO_GTINS: GtinEntry[] = [
  g('2000000000015', 'Demo box: clarithromycin 500 mg', 'clarithromycin'),
  g('2000000000022', 'Demo box: azithromycin 500 mg', 'azithromycin'),
  g('2000000000039', 'Demo box: ciprofloxacin 500 mg', 'ciprofloxacin'),
  g('2000000000046', 'Demo box: ondansetron 8 mg', 'ondansetron'),
  g('2000000000053', 'Demo box: domperidone 10 mg', 'domperidone'),
  g('2000000000060', 'Demo box: escitalopram 10 mg', 'escitalopram'),
  g('2000000000077', 'Demo box: hydroxyzine 25 mg', 'hydroxyzine'),
  g('2000000000084', 'Demo box: pseudoephedrine cold & flu', 'pseudoephedrine'),
  g('2000000000091', 'Demo box: paracetamol 500 mg', 'paracetamol'),
  g('2000000000107', 'Demo box: ibuprofen 400 mg', 'ibuprofen'),
  g('2000000000114', 'Demo box: amoxicillin 500 mg', 'amoxicillin'),
  g('2000000000121', 'Demo box: bisoprolol 5 mg', 'bisoprolol')
];

export function lookupGtin(gtin: string): GtinEntry | undefined {
  return DEMO_GTINS.find((e: GtinEntry) => e.gtin === gtin);
}
