/**
 * What the watch screens say about a number: fixed rules, never model output, never a diagnosis. Pure and
 * unit-tested. The words and shapes are the phone's (DESIGN.md §6.10): Good, Okay, Worth a look, No data.
 * Alerts (red) are a separate thing and come from AlarmRules / MockedVitals, not from here.
 */
import { Activity, Genotype } from '../model/WatchMetric';
import { shortDrugName } from './DrugBadge';
import { HrBucket } from './HrTrend';
import { HRV_LOW_MS, SPO2_LOW } from './MockedVitals';

export type Level = 'GOOD' | 'OKAY' | 'LOOK' | 'NONE';

export function levelWord(level: Level): string {
  switch (level) {
    case 'GOOD':
      return 'Good';
    case 'OKAY':
      return 'Okay';
    case 'LOOK':
      return 'Worth a look';
    default:
      return 'No data';
  }
}

/** HRV in ms. Below the alert line is worth a look; a little above it is okay. */
export function hrvLevel(ms: number): Level {
  if (ms <= 0) {
    return 'NONE';
  }
  if (ms < HRV_LOW_MS) {
    return 'LOOK';
  }
  return ms < 30 ? 'OKAY' : 'GOOD';
}

/** Blood oxygen in %. Usual range 95-100. */
export function spo2Level(pct: number): Level {
  if (pct <= 0) {
    return 'NONE';
  }
  if (pct < SPO2_LOW) {
    return 'LOOK';
  }
  return pct < 95 ? 'OKAY' : 'GOOD';
}

/** Breaths per minute at rest. Usual range 12-20. */
export function breathingLevel(perMin: number): Level {
  if (perMin <= 0) {
    return 'NONE';
  }
  if (perMin < 10 || perMin > 24) {
    return 'LOOK';
  }
  return perMin < 12 || perMin > 20 ? 'OKAY' : 'GOOD';
}

/** Resting heart rate in bpm. */
export function restingLevel(bpm: number): Level {
  if (bpm <= 0) {
    return 'NONE';
  }
  if (bpm < 45 || bpm > 100) {
    return 'LOOK';
  }
  return bpm < 50 || bpm > 85 ? 'OKAY' : 'GOOD';
}

export function rhythmLevel(irregular: boolean, known: boolean): Level {
  if (!known) {
    return 'NONE';
  }
  return irregular ? 'LOOK' : 'GOOD';
}

/** Home zone: where the live bpm sits against the current limits. */
export type Zone = 'WAITING' | 'CALM' | 'NEAR' | 'ABOVE' | 'BELOW';

/** Within 10% of the max (or stressed at rest) reads as "near"; outside a limit is above / below. */
export function zoneFor(bpm: number, low: number, high: number, stressed: boolean): Zone {
  if (bpm <= 0) {
    return 'WAITING';
  }
  if (bpm > high) {
    return 'ABOVE';
  }
  if (bpm < low) {
    return 'BELOW';
  }
  if (bpm >= high * 0.9 || stressed) {
    return 'NEAR';
  }
  return 'CALM';
}

export function zoneWord(zone: Zone): string {
  switch (zone) {
    case 'CALM':
      return 'All good';
    case 'NEAR':
      return 'Near your max';
    case 'ABOVE':
      return 'Above your max';
    case 'BELOW':
      return 'Below your min';
    default:
      return 'Waiting';
  }
}

/** Ring fill 0-1: where the bpm sits between the min (empty) and the max (full). */
export function ringRatio(bpm: number, low: number, high: number): number {
  const span = high - low;
  if (span <= 0 || bpm <= 0) {
    return 0;
  }
  return Math.max(0.03, Math.min(1, (bpm - low) / span));
}

/** "At rest" / "Active" / "Asleep", '' when unknown. */
export function stateWord(activity: Activity): string {
  switch (activity) {
    case 'REST':
      return 'At rest';
    case 'ACTIVE':
      return 'Active';
    case 'ASLEEP':
      return 'Asleep';
    default:
      return '';
  }
}

/**
 * Home context line: "At rest · max 110". Asleep (or below the min) it shows the min instead, because that is the
 * limit that matters then.
 */
export function contextLine(activity: Activity, zone: Zone, low: number, high: number): string {
  const showMin = activity === 'ASLEEP' || zone === 'BELOW';
  const limit = showMin ? `min ${low}` : `max ${high}`;
  const s = stateWord(activity);
  return s.length > 0 ? `${s} · ${limit}` : `${limit.charAt(0).toUpperCase()}${limit.substring(1)}`;
}

/** Settings "Limits now" sub-line: "LQT2 · at rest · lowered for Clarithromycin". */
export function limitsWhy(genotype: Genotype, activity: Activity, riskyDrug: string): string {
  const parts: string[] = [];
  if (genotype !== 'UNKNOWN') {
    parts.push(genotype);
  }
  const s = stateWord(activity).toLowerCase();
  if (s.length > 0) {
    parts.push(s);
  }
  if (riskyDrug.length > 0) {
    parts.push(`lowered for ${shortDrugName(riskyDrug)}`);
  }
  return parts.length > 0 ? parts.join(' · ') : 'Standard limits';
}

/** Trend slots whose highest reading crossed the max ("3 over max"). */
export function slotsOverMax(slots: HrBucket[], high: number): number {
  let n = 0;
  for (const b of slots) {
    if (b.count > 0 && b.max > high) {
      n += 1;
    }
  }
  return n;
}

/** A typical healthy heart-rate drop one minute after exercise; the slow-recovery alert compares against it. */
export const USUAL_RECOVERY_DROP_BPM: number = 20;

/** Heartbeat glyph period: 1.1 s calm, quicker as the state gets more urgent (DESIGN.md §8). */
export function beatPeriodMs(zone: Zone): number {
  switch (zone) {
    case 'ABOVE':
    case 'BELOW':
      return 500;
    case 'NEAR':
      return 800;
    default:
      return 1100;
  }
}
