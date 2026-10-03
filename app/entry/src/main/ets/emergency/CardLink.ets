// Emergency-card QR (F-30): a link to the static card viewer (site/card/, Vercel) with the card itself in
// the URL #fragment. Browsers never send the fragment to the server, so the host only serves an empty page; the
// card is rendered on the scanner's phone, in its own language. The same link opens offline inside Celia.
//
// Payload: compact JSON → UTF-8 → base64url. Kept short so the QR stays easy to scan from a screen.
// Versions: v1 (name, genotype, ICD, medicines, contacts, notes, country) and v2, which adds the emergency details
// of Workstream B4 as optional short fields. Readers accept both, so old links and QR codes keep opening. Fields the
// user switched off for the card (Profile.hiddenOnCard) never enter the payload.

import { CardField, Contact, ExtraField, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medLine } from './CardContent';
import { CardRow, shownOnCard } from './EmergencyDetails';
import { CardLabels } from '../common/CardStrings';
import { ageYears } from './Responder';
import { base64UrlDecode, base64UrlEncode, utf8Decode, utf8Encode } from '../common/Base64Url';
import { LocalConfig } from '../common/LocalConfig';

export const PUBLIC_CARD_VIEWER_URL: string = 'https://celia-share.vercel.app/card/';
// A local viewer (app/scripts/serve-card.sh, laptop on the same Wi-Fi) wins over the public one when set.
export const CARD_VIEWER_URL: string =
  LocalConfig.CARD_VIEWER_URL.length > 0 ? LocalConfig.CARD_VIEWER_URL : PUBLIC_CARD_VIEWER_URL;
export const CARD_PAYLOAD_VERSION: number = 2;
const READABLE_VERSIONS: number[] = [1, 2];
// Upper bound of the in-link (unencrypted) fallback, unchanged from v1: the card is trimmed until it fits.
export const MAX_PAYLOAD_CHARS: number = 900;
const MAX_NOTES_CHARS: number = 200;
const MAX_CONTACTS: number = 3;
const MAX_ALLERGIES: number = 6;
const MAX_EXTRA: number = 4;
const MAX_SHORT: number = 40;    // one allergy, blood type, sex, a label
const MAX_LONG: number = 80;     // hospital, ICD model, cardiologist, an extra value

// Field names are short on purpose (QR size). Mirrors site/card/index.html.
export interface CardPayload {
  v: number;            // payload version
  n: string;            // name ('' if not set)
  g: string;            // genotype: LQT1 | LQT2 | LQT3 | UNKNOWN
  i: number;            // ICD: 1 yes, 0 no
  m: string[];          // medicines, as shown on the card
  c: string[][];        // contacts: [name, phone, relation]
  o: string;            // notes
  cc: string;           // country (ISO 3166-1 alpha-2) → local emergency number in the viewer
  x: number;            // medicines left out to fit the QR (0 normally)
  // v2 (all optional; absent when empty or switched off for the card)
  d?: string;           // date of birth 'YYYY-MM-DD'
  s?: string;           // sex: F | M | O
  b?: string;           // blood type
  a?: string[];         // allergies
  k?: string;           // ICD model (only with i = 1)
  r?: string[];         // cardiologist: [name, phone]
  h?: string;           // hospital
  e?: string[][];       // extra: [label, value]
}

function clip(v: string | undefined, max: number): string {
  const t: string = (v ?? '').trim();
  return t.length > max ? t.substring(0, max - 1) + '…' : t;
}

function sexCode(p: Profile): string {
  return p.sex === 'FEMALE' ? 'F' : p.sex === 'MALE' ? 'M' : p.sex === 'OTHER' ? 'O' : '';
}

// Adds the v2 detail fields that have a value and are shown on the card.
function addDetails(payload: CardPayload, p: Profile): void {
  const show = (f: string): boolean => shownOnCard(p, f);
  const dob: string = clip(p.dateOfBirth, 10);
  if (dob.length > 0 && show(CardField.DATE_OF_BIRTH)) {
    payload.d = dob;
  }
  if (sexCode(p).length > 0 && show(CardField.SEX)) {
    payload.s = sexCode(p);
  }
  const blood: string = clip(p.bloodType, MAX_SHORT);
  if (blood.length > 0 && show(CardField.BLOOD_TYPE)) {
    payload.b = blood;
  }
  const allergies: string[] = (p.allergies ?? []).map((a: string) => clip(a, MAX_SHORT))
    .filter((a: string) => a.length > 0).slice(0, MAX_ALLERGIES);
  if (allergies.length > 0 && show(CardField.ALLERGIES)) {
    payload.a = allergies;
  }
  const icd: string = clip(p.icdModel, MAX_LONG);
  if (p.hasIcd && icd.length > 0 && show(CardField.ICD_MODEL)) {
    payload.k = icd;
  }
  const cName: string = clip(p.cardiologistName, MAX_LONG);
  const cPhone: string = clip(p.cardiologistPhone, MAX_SHORT);
  if ((cName.length > 0 || cPhone.length > 0) && show(CardField.CARDIOLOGIST)) {
    payload.r = [cName, cPhone];
  }
  const hospital: string = clip(p.hospital, MAX_LONG);
  if (hospital.length > 0 && show(CardField.HOSPITAL)) {
    payload.h = hospital;
  }
  const extra: string[][] = (p.extra ?? []).filter((x: ExtraField) => x.label.trim().length > 0 &&
    x.value.trim().length > 0).slice(0, MAX_EXTRA)
    .map((x: ExtraField): string[] => [clip(x.label, MAX_SHORT), clip(x.value, MAX_LONG)]);
  if (extra.length > 0 && show(CardField.EXTRA)) {
    payload.e = extra;
  }
}

export function buildPayload(p: Profile, meds: Medication[], country: string): CardPayload {
  const payload: CardPayload = {
    v: CARD_PAYLOAD_VERSION,
    n: shownOnCard(p, CardField.NAME) ? clip(p.name, MAX_LONG) : '',
    g: p.genotype,
    i: p.hasIcd ? 1 : 0,
    m: meds.map((m: Medication) => medLine(m)),
    c: shownOnCard(p, CardField.CONTACTS) ?
      p.contacts.slice(0, MAX_CONTACTS)
        .map((c: Contact): string[] => [clip(c.name, MAX_LONG), clip(c.phone, MAX_SHORT), clip(c.relation, MAX_SHORT)]) :
      [],
    o: !shownOnCard(p, CardField.NOTES) ? '' :
      p.notes.length > MAX_NOTES_CHARS ? p.notes.substring(0, MAX_NOTES_CHARS - 1) + '…' : p.notes,
    cc: country.toUpperCase(),
    x: 0
  };
  addDetails(payload, p);
  return payload;
}

export function encodePayload(payload: CardPayload): string {
  return base64UrlEncode(utf8Encode(JSON.stringify(payload)));
}

export function decodePayload(encoded: string): CardPayload | undefined {
  try {
    return parsePayloadJson(utf8Decode(base64UrlDecode(encoded)));
  } catch (e) {
    return undefined;
  }
}

// The card JSON itself (also what an encrypted share link decrypts to). Validated before use.
export function parsePayloadJson(json: string): CardPayload | undefined {
  try {
    const p: CardPayload = JSON.parse(json) as CardPayload;
    if (p === null || typeof p !== 'object' || !READABLE_VERSIONS.includes(p.v) || typeof p.g !== 'string' ||
      !Array.isArray(p.m) || !Array.isArray(p.c)) {
      return undefined;
    }
    return cleanDetails(p);
  } catch (e) {
    return undefined;
  }
}

// A v1 payload has none of the details; a v2 one may carry any of them. Drop anything of the wrong shape so the
// renderers can trust the types.
function cleanDetails(p: CardPayload): CardPayload {
  const str = (v: string | undefined): string | undefined => typeof v === 'string' && v.length > 0 ? v : undefined;
  const list = (v: string[] | undefined): string[] | undefined =>
    Array.isArray(v) ? v.filter((x: string) => typeof x === 'string') : undefined;
  p.d = str(p.d);
  p.s = p.s === 'F' || p.s === 'M' || p.s === 'O' ? p.s : undefined;
  p.b = str(p.b);
  p.a = list(p.a);
  p.k = str(p.k);
  p.r = list(p.r);
  p.h = str(p.h);
  p.e = Array.isArray(p.e) ? p.e.filter((x: string[]) => Array.isArray(x) && x.length === 2 &&
    typeof x[0] === 'string' && typeof x[1] === 'string') : undefined;
  return p;
}

// Shortens the payload until it fits, least urgent first: notes, extra fields, hospital, cardiologist, then
// medicines from the end ("+N more" in the viewer), then the rest of the notes, contacts beyond the first, and
// allergies beyond three. Genotype, ICD, blood type and the first allergies are never dropped.
export function fitPayload(payload: CardPayload): string {
  let encoded: string = encodePayload(payload);
  const tooLong = (): boolean => encoded.length > MAX_PAYLOAD_CHARS;
  if (tooLong() && payload.o.length > 60) {
    payload.o = payload.o.substring(0, 60) + '…';
    encoded = encodePayload(payload);
  }
  while (tooLong() && payload.e !== undefined) {
    payload.e.pop();
    if (payload.e.length === 0) {
      payload.e = undefined;
    }
    encoded = encodePayload(payload);
  }
  if (tooLong() && payload.h !== undefined) {
    payload.h = undefined;
    encoded = encodePayload(payload);
  }
  if (tooLong() && payload.r !== undefined) {
    payload.r = undefined;
    encoded = encodePayload(payload);
  }
  while (tooLong() && payload.m.length > 0) {
    payload.m.pop();
    payload.x += 1;
    encoded = encodePayload(payload);
  }
  if (tooLong() && payload.o.length > 0) {
    payload.o = '';
    encoded = encodePayload(payload);
  }
  while (tooLong() && payload.c.length > 1) {
    payload.c.pop();
    encoded = encodePayload(payload);
  }
  while (tooLong() && payload.a !== undefined && payload.a.length > 3) {
    payload.a.pop();
    encoded = encodePayload(payload);
  }
  return encoded;
}

export function cardLink(p: Profile, meds: Medication[], country: string): string {
  return CARD_VIEWER_URL + '#' + fitPayload(buildPayload(p, meds, country));
}

// A scanned QR that is one of our card links → its payload (opened natively inside Celia).
export function parseCardLink(raw: string): CardPayload | undefined {
  const text: string = raw.trim();
  const hash: number = text.indexOf('#');
  const ours: boolean = text.startsWith(CARD_VIEWER_URL) || text.startsWith(PUBLIC_CARD_VIEWER_URL);
  if (!ours || hash < 0) {
    return undefined;
  }
  return decodePayload(text.substring(hash + 1));
}

// The v2 detail rows of a received card, in the same fixed order as our own card (EmergencyDetails.DETAIL_ORDER).
// A v1 card has none and returns [].
export function payloadDetailRows(c: CardPayload, l: CardLabels, now: number): CardRow[] {
  const rows: CardRow[] = [];
  const add = (id: string, label: string, value: string | undefined): void => {
    if (value !== undefined && value.trim().length > 0) {
      const r: CardRow = { id: id, label: label, value: value.trim() };
      rows.push(r);
    }
  };
  const age: number | undefined = ageYears(c.d, now);
  add(CardField.DATE_OF_BIRTH, l.dateOfBirth, c.d === undefined ? undefined :
    age === undefined ? c.d : `${c.d} (${l.age} ${age})`);
  add(CardField.SEX, l.sex, c.s === 'F' ? l.female : c.s === 'M' ? l.male : c.s === 'O' ? l.other : undefined);
  add(CardField.BLOOD_TYPE, l.bloodType, c.b);
  add(CardField.ALLERGIES, l.allergies, c.a === undefined ? undefined : c.a.join(', '));
  add(CardField.ICD_MODEL, l.icdModel, c.i === 1 ? c.k : undefined);
  add(CardField.CARDIOLOGIST, l.cardiologist, c.r === undefined ? undefined :
    c.r.filter((x: string) => x.length > 0).join(' · '));
  add(CardField.HOSPITAL, l.hospital, c.h);
  (c.e ?? []).forEach((x: string[]) => add(CardField.EXTRA, x[0], x[1]));
  return rows;
}
