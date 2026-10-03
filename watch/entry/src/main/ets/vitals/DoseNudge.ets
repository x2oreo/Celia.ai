/**
 * Missed-dose nudge: if no `medication_taken` was logged today by the reminder time + 2 h, ask "Did you take it?".
 * Decided on the watch from its own taps, so it works offline. Pure logic (state in, decision out), unit-tested.
 */

/** Shown at most this many times a day: the first nudge plus two "Not yet" snoozes. */
export const NUDGE_MAX_SHOWS = 3;
export const NUDGE_GRACE_MS = 2 * 3600 * 1000;
export const NUDGE_SNOOZE_MS = 3600 * 1000;

export interface DoseState {
  /** Local day (YYYY-MM-DD) of the last `medication_taken`. */
  lastDoseDay: string;
  /** Local day the counters below belong to. */
  nudgeDay: string;
  timesShown: number;
  snoozeUntilMs: number;
}

export function emptyDoseState(): DoseState {
  const s: DoseState = { lastDoseDay: '', nudgeDay: '', timesShown: 0, snoozeUntilMs: 0 };
  return s;
}

export function dayKey(ms: number): string {
  const d = new Date(ms);
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return `${d.getFullYear()}-${m < 10 ? '0' : ''}${m}-${day < 10 ? '0' : ''}${day}`;
}

/** Today's reminder time in ms, or -1 when the time is empty/invalid (nudge off). */
export function reminderAtMs(nowMs: number, hhmm: string): number {
  const m = new RegExp('^([01]?[0-9]|2[0-3]):([0-5][0-9])$').exec(hhmm);
  if (m === null) {
    return -1;
  }
  const d = new Date(nowMs);
  d.setHours(Number(m[1]), Number(m[2]), 0, 0);
  return d.getTime();
}

/** Resets the per-day counters when the day changed. */
export function forToday(s: DoseState, nowMs: number): DoseState {
  const today = dayKey(nowMs);
  if (s.nudgeDay === today) {
    return s;
  }
  const next: DoseState = { lastDoseDay: s.lastDoseDay, nudgeDay: today, timesShown: 0, snoozeUntilMs: 0 };
  return next;
}

export function shouldNudge(s: DoseState, nowMs: number, hhmm: string): boolean {
  const reminder = reminderAtMs(nowMs, hhmm);
  if (reminder < 0 || nowMs < reminder + NUDGE_GRACE_MS) {
    return false;
  }
  const today = forToday(s, nowMs);
  if (today.lastDoseDay === dayKey(nowMs)) {
    return false;
  }
  return today.timesShown < NUDGE_MAX_SHOWS && nowMs >= today.snoozeUntilMs;
}

/** "Not yet" is offered while a later re-show is still allowed. */
export function canSnooze(s: DoseState): boolean {
  return s.timesShown < NUDGE_MAX_SHOWS;
}
