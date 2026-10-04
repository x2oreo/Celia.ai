// Pure checks for /doctor-summary (unit-tested in logic.test.ts; the app repeats them in doctor/DoctorSummary.ets).

export const MAX_SUMMARY = 420;
export const MAX_LINES = 30;
export const MAX_LINE = 160;
export const MAX_TEXT = 300;   // reason / worries, same limit as the app (doctor/Visit.ets VISIT_TEXT_MAX)

export interface SummaryInput {
  specialty: string;
  genotype: string;
  medicines: string[];      // "Name dose - risk word" lines from the deterministic brief
  interactions: string[];
  flagged: string[];
  heartAlerts: number;
  symptoms: number;
  visitFor: string[];       // fixed purpose titles of the visit plan ("Infection"), never the patient's own words
  avoid: string[];          // known-risk medicine names the plan flags for this visit
  reason: string;           // the patient's own words for a saved visit, names already removed by the app
  worries: string;
}

// The summary must never reassure about a medicine, give doses or tell anyone to start/stop something: the
// risk words in the brief are final.
export const BANNED =
  /\b(safe|safer|harmless|no risk|not risky|fine to take|ok to take|stop taking|start taking|discontinue|\d+([.,]\d+)?\s?(mg|mcg|µg|ml)\b)/i;

// A list arrives as a JSON array or as one newline-joined string (the app's Net layer sends string fields only).
function lines(v: unknown): string[] {
  const raw: unknown[] = Array.isArray(v) ? v : typeof v === 'string' ? v.split('\n') : [];
  return raw.filter((x) => typeof x === 'string' && x.trim() !== '').slice(0, MAX_LINES)
    .map((x) => (x as string).trim().slice(0, MAX_LINE));
}

// Second line of defence after the app's doctor/Redact.ets: e-mails, links and phone numbers (7+ digits, not a
// date) never reach the model even if the app missed them.
export const REDACTED = '[removed]';
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const URL = /\b(https?:\/\/|www\.)\S+/gi;
const PHONE_LIKE = /\+?\d[\d\s().\/-]{4,}\d/g;
const DATE_LIKE = /^(\d{4}[-.\/]\d{1,2}[-.\/]\d{1,2}|\d{1,2}[-.\/]\d{1,2}[-.\/]\d{2,4})$/;

export function scrub(t: string): string {
  return t.replace(EMAIL, REDACTED).replace(URL, REDACTED).replace(PHONE_LIKE, (m) =>
    (m.match(/\d/g) ?? []).length >= 7 && !DATE_LIKE.test(m.trim()) ? REDACTED : m);
}

// Free text: missing → '', a string → scrubbed and clipped, anything else → invalid request. Angle brackets go so
// the words cannot close the <patient_words> tag they are quoted in.
function text(v: unknown): string | undefined {
  if (v === undefined || v === null) return '';
  if (typeof v !== 'string') return undefined;
  return scrub(v.replace(/[<>]/g, ' ').trim().replace(/\s+/g, ' ')).slice(0, MAX_TEXT);
}

function count(v: unknown): number {
  const n = typeof v === 'string' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) && n >= 0 ? Math.min(Math.floor(n), 999) : 0;
}

export function parseInput(b: Record<string, unknown>): SummaryInput | undefined {
  if (typeof b.specialty !== 'string' || b.specialty.length === 0 || b.specialty.length > 40) return undefined;
  const genotype = typeof b.genotype === 'string' && /^(LQT[123]|UNKNOWN)$/.test(b.genotype) ? b.genotype : 'UNKNOWN';
  const reason = text(b.reason);
  const worries = text(b.worries);
  if (reason === undefined || worries === undefined) return undefined;
  return {
    specialty: b.specialty,
    genotype,
    medicines: lines(b.medicines),
    interactions: lines(b.interactions),
    flagged: lines(b.flagged),
    heartAlerts: count(b.heartAlerts),
    symptoms: count(b.symptoms),
    visitFor: lines(b.visitFor),
    avoid: lines(b.avoid),
    reason,
    worries,
  };
}

// Model text → summary, or undefined when it is empty, too long or breaks a rule.
export function checkSummary(text: unknown): string | undefined {
  if (typeof text !== 'string') return undefined;
  const t = text.trim().replace(/\s+/g, ' ').replace(/\u2014/g, '-'); // no em dashes in our copy
  if (t.length < 20 || t.length > MAX_SUMMARY || BANNED.test(t)) return undefined;
  return t;
}
