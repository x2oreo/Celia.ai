// Pure, deterministic SOS message building. No LLM is involved: an emergency text must never depend on a model.
// Kept free of Deno/Supabase APIs so it is unit-testable (message.test.ts).

export type SosReason = 'need_help' | 'fall';

export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';

/** `payload` of a watch_metrics row with type = 'sos' (watch/entry/src/main/ets/model/WatchMetric.ets SosValues). */
export interface SosPayload {
  reason: SosReason;
  /** Heart rate when the SOS fired, 0 if unknown. */
  bpm: number;
  activity?: string;
  /** Optional WGS84 location; omitted when permission is denied or the fix timed out. */
  lat?: number;
  lon?: number;
  accuracyM?: number;
}

/** Patient context from watch_context. Everything is optional: the alert must still go out without it. */
export interface PatientContext {
  name: string | null;
  genotype: Genotype;
  riskyDrug: string | null;
}

export interface SosMessage {
  /** SMS body, kept short (< ~3 SMS segments). */
  sms: string;
  /** Text read out by the voice call (TwiML <Say>). No URLs: they are useless when spoken. */
  voice: string;
}

/** Parses an untrusted row payload. Returns null when it is not a usable SOS payload. */
export function parseSosPayload(raw: unknown): SosPayload | null {
  if (raw === null || typeof raw !== 'object') {
    return null;
  }
  const o = raw as Record<string, unknown>;
  if (o.reason !== 'need_help' && o.reason !== 'fall') {
    return null;
  }
  const bpm = typeof o.bpm === 'number' && Number.isFinite(o.bpm) && o.bpm > 0 && o.bpm < 300 ? Math.round(o.bpm) : 0;
  const result: SosPayload = { reason: o.reason, bpm };
  if (typeof o.activity === 'string' && o.activity.length <= 32) {
    result.activity = o.activity;
  }
  if (isLat(o.lat) && isLon(o.lon)) {
    result.lat = o.lat;
    result.lon = o.lon;
    if (typeof o.accuracyM === 'number' && Number.isFinite(o.accuracyM) && o.accuracyM >= 0) {
      result.accuracyM = Math.round(o.accuracyM);
    }
  }
  return result;
}

function isLat(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v) && v >= -90 && v <= 90;
}

function isLon(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v) && v >= -180 && v <= 180;
}

/** E.164 phone number, e.g. +48123456789. */
export function isE164(phone: string): boolean {
  return /^\+[1-9][0-9]{6,14}$/.test(phone);
}

/** Strips characters that would break TwiML. */
export function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

export function buildSosMessage(p: SosPayload, ctx: PatientContext): SosMessage {
  const who = ctx.name !== null && ctx.name.trim().length > 0 ? ctx.name.trim() : 'Your contact';
  const what = p.reason === 'fall'
    ? `${who} may have fainted and is not answering their watch`
    : `${who} pressed SOS on their watch`;
  const condition = ctx.genotype === 'UNKNOWN' ? 'Long QT syndrome' : `Long QT syndrome (${ctx.genotype})`;
  const hr = p.bpm > 0 ? ` Heart rate ${p.bpm} bpm.` : '';
  const drug = ctx.riskyDrug !== null ? ` Recently took ${ctx.riskyDrug} (QT risk).` : '';
  const where = p.lat !== undefined && p.lon !== undefined
    ? ` Location: https://maps.google.com/?q=${p.lat.toFixed(5)},${p.lon.toFixed(5)}` +
      (p.accuracyM !== undefined ? ` (±${p.accuracyM} m).` : '.')
    : ' Location unknown.';

  const sms = `CELIA SOS: ${what}. Has ${condition}.${hr}${drug}${where} ` +
    'Call 112 now. Tell paramedics: Long QT, avoid QT-prolonging drugs.';
  const voice = `This is an automated emergency alert from Celia. ${what}. ` +
    `They have ${condition}.${hr}${drug} Please call 112 now. ` +
    'Details and location were sent to you by text message.';
  return { sms, voice };
}
