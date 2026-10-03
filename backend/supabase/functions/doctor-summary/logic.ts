// Pure checks for /doctor-summary (unit-tested in logic.test.ts; the app repeats them in doctor/DoctorSummary.ets).

export const MAX_SUMMARY = 420;
export const MAX_LINES = 30;
export const MAX_LINE = 160;

export interface SummaryInput {
  specialty: string;
  genotype: string;
  medicines: string[];      // "Name dose — risk word" lines from the deterministic brief
  interactions: string[];
  flagged: string[];
  heartAlerts: number;
  symptoms: number;
  visitFor: string[];       // fixed purpose titles of the visit plan ("Infection"), never the patient's own words
  avoid: string[];          // known-risk medicine names the plan flags for this visit
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

function count(v: unknown): number {
  const n = typeof v === 'string' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) && n >= 0 ? Math.min(Math.floor(n), 999) : 0;
}

export function parseInput(b: Record<string, unknown>): SummaryInput | undefined {
  if (typeof b.specialty !== 'string' || b.specialty.length === 0 || b.specialty.length > 40) return undefined;
  const genotype = typeof b.genotype === 'string' && /^(LQT[123]|UNKNOWN)$/.test(b.genotype) ? b.genotype : 'UNKNOWN';
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
  };
}

// Model text → summary, or undefined when it is empty, too long or breaks a rule.
export function checkSummary(text: unknown): string | undefined {
  if (typeof text !== 'string') return undefined;
  const t = text.trim().replace(/\s+/g, ' ');
  if (t.length < 20 || t.length > MAX_SUMMARY || BANNED.test(t)) return undefined;
  return t;
}
