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

/** Last dose confirmed on the watch ("Took nadolol"). */
export interface LastDose {
  name: string;
  /** Epoch ms. */
  at: number;
}

/** A "How do you feel?" answer other than "fine", shortly before the SOS. */
export interface RecentSymptom {
  kind: string;
  bpm: number;
  /** Epoch ms. */
  at: number;
}

/** Patient context from watch_context and the watch views. Everything is optional: the alert must still go out. */
export interface PatientContext {
  name: string | null;
  genotype: Genotype;
  riskyDrug: string | null;
  lastDose?: LastDose | null;
  recentSymptom?: RecentSymptom | null;
}

/** Window for "recent" symptoms and dose ages mentioned in the alert. */
export const SYMPTOM_WINDOW_MS = 60 * 60_000;
export const DOSE_MISSED_AFTER_MS = 26 * 3600_000;

/** HH:MM in Polish local time (the demo and team are in Kraków). */
export function localTime(ms: number): string {
  return new Date(ms).toLocaleTimeString('en-GB', { timeZone: 'Europe/Warsaw', hour: '2-digit', minute: '2-digit' });
}

function localDay(ms: number): string {
  return new Date(ms).toLocaleDateString('en-CA', { timeZone: 'Europe/Warsaw' });
}

/** "today 08:02" / "yesterday 08:02" in Polish local time. */
export function relativeTime(ms: number, now: number): string {
  const day = localDay(ms) === localDay(now) ? 'today' : 'yesterday';
  return `${day} ${localTime(ms)}`;
}

function symptomLabel(kind: string): string {
  switch (kind) {
    case 'palpitations':
      return 'a racing heart';
    case 'other':
      return 'feeling unwell';
    default:
      return kind;
  }
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

export function buildSosMessage(p: SosPayload, ctx: PatientContext, now: number = Date.now()): SosMessage {
  const who = ctx.name !== null && ctx.name.trim().length > 0 ? ctx.name.trim() : 'Your contact';
  const what = p.reason === 'fall'
    ? `${who} may have fainted and is not answering their watch`
    : `${who} pressed SOS on their watch`;
  const condition = ctx.genotype === 'UNKNOWN' ? 'Long QT syndrome' : `Long QT syndrome (${ctx.genotype})`;
  const hr = p.bpm > 0 ? ` Heart rate ${p.bpm} bpm.` : '';
  const drug = ctx.riskyDrug !== null ? ` Recently took ${ctx.riskyDrug} (QT risk).` : '';
  const s = ctx.recentSymptom;
  const symptom = s && now - s.at >= 0 && now - s.at <= SYMPTOM_WINDOW_MS
    ? ` Reported ${symptomLabel(s.kind)} at ${localTime(s.at)}${s.bpm > 0 ? ` (HR ${s.bpm})` : ''}.`
    : '';
  const symptomVoice = symptom === '' ? '' : ` Shortly before, they reported ${symptomLabel(s!.kind)}.`;
  const d = ctx.lastDose;
  let dose = '';
  let doseVoice = '';
  if (d) {
    const hours = Math.max(0, Math.round((now - d.at) / 3600_000));
    if (now - d.at > DOSE_MISSED_AFTER_MS) {
      dose = ` No ${d.name} dose logged for ${hours} h.`;
      doseVoice = ` No ${d.name} dose has been logged for ${hours} hours.`;
    } else {
      dose = ` Last ${d.name} dose ${relativeTime(d.at, now)}.`;
      doseVoice = ` Their last ${d.name} dose was ${hours} hours ago.`;
    }
  }
  const where = p.lat !== undefined && p.lon !== undefined
    ? ` Location: https://maps.google.com/?q=${p.lat.toFixed(5)},${p.lon.toFixed(5)}` +
      (p.accuracyM !== undefined ? ` (±${p.accuracyM} m).` : '.')
    : ' Location unknown.';

  const sms = `CELIA SOS: ${what}. Has ${condition}.${hr}${symptom}${dose}${drug}${where} ` +
    'Call 112 now. Tell paramedics: Long QT, avoid QT-prolonging drugs.';
  const voice = `This is an automated emergency alert from Celia. ${what}. ` +
    `They have ${condition}.${hr}${symptomVoice}${doseVoice}${drug} Please call 112 now. ` +
    'Details and location were sent to you by text message.';
  return { sms, voice };
}
