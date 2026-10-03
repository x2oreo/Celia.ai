// Medicine-box barcodes (F-36): EAN-13 / GTIN-14 and GS1 DataMatrix (EU Falsified Medicines Directive codes
// carry the GTIN in AI (01)). Pure parsing + check-digit validation — unit tested.
//
// GTIN → product: real Polish boxes come from the bundled register (GtinCatalog.ets); boxes from other
// countries are taught once by the user (BarcodeService). A small DEMO table in the GS1 restricted-circulation
// range 20x (never assigned to real products) keeps the flow testable with printed sample codes.

import { BoxInfo } from '../model/BoxInfo';

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

// GS1 company prefix → country of the GS1 member organisation that issued the code (usually where the box was
// made for). Only used for a label like "Bulgarian box"; ranges from the public GS1 prefix list.
interface PrefixRange {
  from: number;
  to: number;
  country: string;
}

function r(from: number, to: number, country: string): PrefixRange {
  const x: PrefixRange = { from: from, to: to, country: country };
  return x;
}

const GS1_PREFIXES: PrefixRange[] = [
  r(300, 379, 'FR'), r(380, 380, 'BG'), r(383, 383, 'SI'), r(385, 385, 'HR'), r(387, 387, 'BA'), r(400, 440, 'DE'),
  r(470, 470, 'KG'), r(474, 474, 'EE'), r(475, 475, 'LV'), r(477, 477, 'LT'), r(481, 481, 'BY'), r(482, 482, 'UA'),
  r(484, 484, 'MD'), r(500, 509, 'GB'), r(520, 521, 'GR'), r(528, 528, 'LB'), r(529, 529, 'CY'), r(531, 531, 'MK'),
  r(535, 535, 'MT'), r(539, 539, 'IE'), r(540, 549, 'BE'), r(560, 560, 'PT'), r(569, 569, 'IS'), r(570, 579, 'DK'),
  r(590, 590, 'PL'), r(594, 594, 'RO'), r(599, 599, 'HU'), r(640, 649, 'FI'), r(730, 739, 'SE'), r(760, 769, 'CH'),
  r(800, 839, 'IT'), r(840, 849, 'ES'), r(858, 858, 'SK'), r(859, 859, 'CZ'), r(860, 860, 'RS'), r(868, 869, 'TR'),
  r(870, 879, 'NL'), r(900, 919, 'AT'), r(700, 709, 'NO'), r(0, 19, 'US')
];

export function gtinCountry(gtin: string): string {
  if (!/^[0-9]{13}$/.test(gtin)) {
    return '';
  }
  const prefix: number = Number(gtin.substring(0, 3));
  for (const range of GS1_PREFIXES) {
    if (prefix >= range.from && prefix <= range.to) {
      return range.country;
    }
  }
  return '';
}

function g(gtin: string, product: string, ingredient: string, strength: string): BoxInfo {
  const e: BoxInfo = {
    gtin: gtin, brand: product, substance: ingredient, ingredients: ingredient, strength: strength,
    form: 'Tablets', pack: '', atc: '', holder: '', rxCategory: '', leafletUrl: '', country: '', source: 'DEMO',
    sourceDate: ''
  };
  return e;
}

// DEMO codes (GS1 prefix 200 = restricted circulation, not real products).
export const DEMO_GTINS: BoxInfo[] = [
  g('2000000000015', 'Demo box: clarithromycin', 'clarithromycin', '500 mg'),
  g('2000000000022', 'Demo box: azithromycin', 'azithromycin', '500 mg'),
  g('2000000000039', 'Demo box: ciprofloxacin', 'ciprofloxacin', '500 mg'),
  g('2000000000046', 'Demo box: ondansetron', 'ondansetron', '8 mg'),
  g('2000000000053', 'Demo box: domperidone', 'domperidone', '10 mg'),
  g('2000000000060', 'Demo box: escitalopram', 'escitalopram', '10 mg'),
  g('2000000000077', 'Demo box: hydroxyzine', 'hydroxyzine', '25 mg'),
  g('2000000000084', 'Demo box: cold & flu', 'pseudoephedrine', '60 mg'),
  g('2000000000091', 'Demo box: paracetamol', 'paracetamol', '500 mg'),
  g('2000000000107', 'Demo box: ibuprofen', 'ibuprofen', '400 mg'),
  g('2000000000114', 'Demo box: amoxicillin', 'amoxicillin', '500 mg'),
  g('2000000000121', 'Demo box: bisoprolol', 'bisoprolol', '5 mg')
];

export function lookupDemoGtin(gtin: string): BoxInfo | undefined {
  return DEMO_GTINS.find((e: BoxInfo) => e.gtin === gtin);
}
