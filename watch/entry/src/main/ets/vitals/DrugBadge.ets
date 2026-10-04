/**
 * Home-screen badge while a QT-risk drug the user took is still in its watch window (72 h, set from the phone's
 * "I took it"): "Clarithromycin · 2d left". Pure, unit-tested. Heart rate only: it says the watch is watching more
 * closely, never that the drug is safe or what it does to the QT interval.
 */

export const DRUG_WINDOW_MS: number = 72 * 3600 * 1000;
const HOUR_MS: number = 3600 * 1000;
const MAX_NAME: number = 14;

/** Capitalised and short enough for the round screen: "clarithromycin" → "Clarithromycin". */
export function shortDrugName(name: string): string {
  const n = name.trim();
  if (n.length === 0) {
    return '';
  }
  const cap = n.charAt(0).toUpperCase() + n.substring(1);
  return cap.length > MAX_NAME ? `${cap.substring(0, MAX_NAME - 1)}…` : cap;
}

/** "2d left" / "5h left" / "<1h left"; '' when the window is over or the time is unknown. */
export function timeLeft(takenAtMs: number, nowMs: number): string {
  if (takenAtMs <= 0) {
    return '';
  }
  const left = takenAtMs + DRUG_WINDOW_MS - nowMs;
  if (left <= 0) {
    return '';
  }
  if (left >= 24 * HOUR_MS) {
    return `${Math.floor(left / (24 * HOUR_MS))}d left`;
  }
  return left < HOUR_MS ? '<1h left' : `${Math.floor(left / HOUR_MS)}h left`;
}

/** Badge text, or '' for no badge. Without a known time it still names the drug. */
export function drugBadgeText(name: string, takenAtMs: number, nowMs: number): string {
  const n = shortDrugName(name);
  if (n.length === 0) {
    return '';
  }
  if (takenAtMs > 0 && takenAtMs + DRUG_WINDOW_MS <= nowMs) {
    return '';
  }
  const left = timeLeft(takenAtMs, nowMs);
  return left.length > 0 ? `${n} · ${left}` : n;
}

/** A symptom this soon after taking a QT-risk drug gets the stronger warning (same window as watch_insights). */
export const DRUG_SYMPTOM_WINDOW_MS: number = 24 * 3600 * 1000;

/**
 * "Dizzy after Clarithromycin" when a symptom answer comes within 24 h of a logged risky drug; '' otherwise.
 * 'fine' never warns. Pure, unit-tested; the phone applies the same rule (app/…/drugs/DrugIntake.ets).
 */
export function symptomAfterDrugTitle(kind: string, drug: string, takenAtMs: number, nowMs: number): string {
  const n = shortDrugName(drug);
  if (n.length === 0 || takenAtMs <= 0 || nowMs < takenAtMs || nowMs - takenAtMs > DRUG_SYMPTOM_WINDOW_MS) {
    return '';
  }
  switch (kind) {
    case 'dizziness':
      return `Dizzy after ${n}`;
    case 'palpitations':
      return `Racing heart after ${n}`;
    case 'fainting':
      return `Fainted after ${n}`;
    case 'other':
      return `Unwell after ${n}`;
    default:
      return '';
  }
}
