// Emergency-card QR (F-30): a link to the static card viewer (site/card/, Vercel) with the card itself in
// the URL #fragment. Browsers never send the fragment to the server, so the host only serves an empty page; the
// card is rendered on the scanner's phone, in its own language. The same link opens offline inside Celia.
//
// Payload: compact JSON → UTF-8 → base64url. Kept short so the QR stays easy to scan from a screen.

import { Contact, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medLine } from './CardContent';
import { base64UrlDecode, base64UrlEncode, utf8Decode, utf8Encode } from '../common/Base64Url';
import { LocalConfig } from '../common/LocalConfig';

export const PUBLIC_CARD_VIEWER_URL: string = 'https://celia-share.vercel.app/card/';
// A local viewer (app/scripts/serve-card.sh, laptop on the same Wi-Fi) wins over the public one when set.
export const CARD_VIEWER_URL: string =
  LocalConfig.CARD_VIEWER_URL.length > 0 ? LocalConfig.CARD_VIEWER_URL : PUBLIC_CARD_VIEWER_URL;
export const CARD_PAYLOAD_VERSION: number = 1;
const MAX_PAYLOAD_CHARS: number = 900;
const MAX_NOTES_CHARS: number = 200;
const MAX_CONTACTS: number = 3;

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
}

export function buildPayload(p: Profile, meds: Medication[], country: string): CardPayload {
  const payload: CardPayload = {
    v: CARD_PAYLOAD_VERSION,
    n: p.name ?? '',
    g: p.genotype,
    i: p.hasIcd ? 1 : 0,
    m: meds.map((m: Medication) => medLine(m)),
    c: p.contacts.slice(0, MAX_CONTACTS).map((c: Contact): string[] => [c.name, c.phone, c.relation]),
    o: p.notes.length > MAX_NOTES_CHARS ? p.notes.substring(0, MAX_NOTES_CHARS - 1) + '…' : p.notes,
    cc: country.toUpperCase(),
    x: 0
  };
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
    if (p.v !== CARD_PAYLOAD_VERSION || typeof p.g !== 'string' || !Array.isArray(p.m) || !Array.isArray(p.c)) {
      return undefined;
    }
    return p;
  } catch (e) {
    return undefined;
  }
}

// Shortens the payload until it fits: notes first, then medicines from the end ("+N more" in the viewer).
export function fitPayload(payload: CardPayload): string {
  let encoded: string = encodePayload(payload);
  if (encoded.length > MAX_PAYLOAD_CHARS && payload.o.length > 0) {
    payload.o = payload.o.substring(0, 60) + '…';
    encoded = encodePayload(payload);
  }
  while (encoded.length > MAX_PAYLOAD_CHARS && payload.m.length > 0) {
    payload.m.pop();
    payload.x += 1;
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
