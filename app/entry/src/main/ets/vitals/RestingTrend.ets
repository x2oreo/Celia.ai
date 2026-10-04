// Missed beta-blocker check (pure - unit tested). Beta-blockers lower resting heart rate, so a resting HR that stays
// well above the person's own baseline for several days is a cue to ask about missed doses. It is a question, never
// a verdict: fever, illness, stress or dehydration raise resting HR too, and the message says so.

import { Medication } from '../model/Medication';
import { DoseLog, DoseReminder, dayKey } from '../reminders/DoseSchedule';

/** One day's resting heart rate (from the watch's `vitals` rows, or demo history). */
export interface DailyResting {
  day: string;          // YYYY-MM-DD local
  bpm: number;          // resting HR for the day
  restMinutes: number;  // minutes of rest/sleep data behind `bpm`
  simulated: boolean;
}

/** Baseline window: median of up to this many valid days before the recent ones. */
export const BASELINE_DAYS: number = 14;
/** No check until the baseline has this many valid days (cold start: first week says nothing). */
export const MIN_BASELINE_DAYS: number = 5;
/** Consecutive recent days that must all be raised. */
export const RECENT_DAYS: number = 2;
/** Rise over baseline that counts as "raised". Beta-blockers typically lower resting HR by 10–20 bpm. */
export const RISE_BPM: number = 10;
/** A day needs this much rest/sleep data to count (watch worn ~at night or for a few quiet hours). */
export const MIN_REST_MINUTES: number = 60;

const DAY_MS: number = 24 * 3600 * 1000;

/** Generic names (lowercase). Matched against Medication.ingredient, then name. */
export const BETA_BLOCKERS: string[] = [
  'nadolol', 'propranolol', 'metoprolol', 'bisoprolol', 'atenolol', 'carvedilol', 'nebivolol'
];

/** What the dose log says about the raised days. */
export type DoseEvidence = 'MISSED_OR_SKIPPED' | 'ALL_TAKEN' | 'NOT_TRACKED';

export interface BetaBlockerFinding {
  med: Medication;
  baselineBpm: number;
  recent: DailyResting[];   // newest first
  evidence: DoseEvidence;
  simulated: boolean;
  message: string;
}

export function findBetaBlocker(meds: Medication[]): Medication | undefined {
  return meds.find((m: Medication) => {
    const ing: string = m.ingredient.toLowerCase();
    const name: string = m.name.toLowerCase();
    return BETA_BLOCKERS.some((b: string) => ing.includes(b) || name.includes(b));
  });
}

export function median(values: number[]): number {
  const s: number[] = values.slice().sort((a: number, b: number) => a - b);
  const mid: number = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function endOfDay(ts: number): number {
  const d: Date = new Date(ts);
  d.setHours(23, 59, 59, 999);
  return d.getTime();
}

/** `dayTs`: any timestamp inside each raised day. */
function doseEvidence(med: Medication, dayTs: number[], reminders: DoseReminder[], logs: DoseLog[]): DoseEvidence {
  const mine: DoseReminder[] = reminders.filter((r: DoseReminder) => r.medId === med.id);
  let checked: number = 0;
  for (const ts of dayTs) {
    const day: string = dayKey(ts);
    for (const r of mine) {
      // A reminder's id is its creation time; it can't have been taken on days before it existed.
      if (r.id > endOfDay(ts)) {
        continue;
      }
      checked++;
      const l: DoseLog | undefined = logs.find((x: DoseLog) => x.reminderId === r.id && x.day === day);
      if (l === undefined || l.status !== 'TAKEN') {
        return 'MISSED_OR_SKIPPED';
      }
    }
  }
  return checked === 0 ? 'NOT_TRACKED' : 'ALL_TAKEN';
}

function buildMessage(med: Medication, baseline: number, recent: DailyResting[], evidence: DoseEvidence): string {
  const name: string = med.name;
  let lowest: number = Number.MAX_VALUE;
  for (const d of recent) {
    lowest = Math.min(lowest, d.bpm);
  }
  const rise: number = Math.round(lowest - baseline);
  const facts: string = `Your resting heart rate has been about ${rise} bpm above your usual ` +
    `${Math.round(baseline)} bpm for ${recent.length} days.`;
  if (evidence === 'ALL_TAKEN') {
    return `${facts} You logged every ${name} dose, so it may be something else: a fever, an infection, stress or ` +
      'not drinking enough. If it continues, tell your cardiologist.';
  }
  const doses: string = evidence === 'MISSED_OR_SKIPPED' ? ` Your dose log shows ${name} wasn't marked as taken.` : '';
  return `${facts}${doses} Did you miss any ${name} doses? Taking it every day matters with Long QT. ` +
    'Don\'t double up - take your next dose as usual, and ask your doctor if you missed several. ' +
    'Feeling unwell or feverish can raise resting heart rate too.';
}

/**
 * Returns a finding when the person takes a beta-blocker and their resting HR was at least RISE_BPM above their
 * baseline on each of the last RECENT_DAYS complete days. Today (incomplete) is never used.
 */
export function checkBetaBlocker(history: DailyResting[], meds: Medication[], reminders: DoseReminder[],
  logs: DoseLog[], now: number): BetaBlockerFinding | undefined {
  const med: Medication | undefined = findBetaBlocker(meds);
  if (med === undefined) {
    return undefined;
  }
  const today: string = dayKey(now);
  const valid: DailyResting[] = history
    .filter((d: DailyResting) => d.day < today && d.restMinutes >= MIN_REST_MINUTES && d.bpm > 25 && d.bpm < 200)
    .sort((a: DailyResting, b: DailyResting) => a.day < b.day ? 1 : a.day > b.day ? -1 : 0);

  // The recent days must be exactly the last RECENT_DAYS calendar days: a watch left in a drawer last week
  // must not produce a "this week" question.
  const expectedTs: number[] = [];
  const expected: string[] = [];
  for (let i = 1; i <= RECENT_DAYS; i++) {
    expectedTs.push(now - i * DAY_MS);
    expected.push(dayKey(now - i * DAY_MS));
  }
  const recent: DailyResting[] = valid.slice(0, RECENT_DAYS);
  if (recent.length < RECENT_DAYS || recent.some((d: DailyResting, i: number) => d.day !== expected[i])) {
    return undefined;
  }
  const base: DailyResting[] = valid.slice(RECENT_DAYS, RECENT_DAYS + BASELINE_DAYS);
  if (base.length < MIN_BASELINE_DAYS) {
    return undefined;
  }
  const baseline: number = median(base.map((d: DailyResting) => d.bpm));
  if (!recent.every((d: DailyResting) => d.bpm >= baseline + RISE_BPM)) {
    return undefined;
  }
  const evidence: DoseEvidence = doseEvidence(med, expectedTs, reminders, logs);
  const finding: BetaBlockerFinding = {
    med: med,
    baselineBpm: baseline,
    recent: recent,
    evidence: evidence,
    simulated: recent.some((d: DailyResting) => d.simulated) || base.some((d: DailyResting) => d.simulated),
    message: buildMessage(med, baseline, recent, evidence)
  };
  return finding;
}
