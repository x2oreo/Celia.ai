import { Activity, Genotype } from '../model/WatchMetric';

/** Base limits from config (.env). */
export interface BaseLimits {
  activeHigh: number;
  restHigh: number;
  sleepHigh: number;
  awakeLow: number;
  sleepLow: number;
}

export interface HrLimits {
  high: number;
  low: number;
  /** Short human-readable reason, shown on the watch ("LQT2 at rest"). */
  reason: string;
}

/** A risky drug lowers the high limits by this much while it is active. */
const RISKY_DRUG_MARGIN = 10;

export function defaultBaseLimits(): BaseLimits {
  const b: BaseLimits = { activeHigh: 140, restHigh: 120, sleepHigh: 100, awakeLow: 45, sleepLow: 40 };
  return b;
}

function stateLabel(activity: Activity): string {
  switch (activity) {
    case 'REST':
      return 'at rest';
    case 'ACTIVE':
      return 'active';
    case 'ASLEEP':
      return 'asleep';
    default:
      return 'awake';
  }
}

/**
 * Deterministic HR limits for the current state, genotype and drug context. Demo heuristics, configurable, not
 * clinical advice:
 * - LQT1 (exercise trigger): lower limit while active.
 * - LQT2 (startle/emotion at rest): lower limit at rest.
 * - LQT3 (events at rest/sleep with slow HR): higher low-limits, earlier bradycardia alert.
 * - Recently scanned QT-risk drug: all high limits lower.
 */
export function limitsFor(activity: Activity, genotype: Genotype, riskyDrug: boolean, base: BaseLimits): HrLimits {
  let high = base.activeHigh;
  let low = base.awakeLow;
  if (activity === 'REST') {
    high = base.restHigh;
  } else if (activity === 'ASLEEP') {
    high = base.sleepHigh;
    low = base.sleepLow;
  }
  if (genotype === 'LQT1' && activity === 'ACTIVE') {
    high -= 10;
  }
  if (genotype === 'LQT2' && activity === 'REST') {
    high -= 10;
  }
  if (genotype === 'LQT3') {
    low += 5;
  }
  if (riskyDrug) {
    high -= RISKY_DRUG_MARGIN;
  }
  // "LQT2 at rest". A risky drug is named by the caller ("lowered for Clarithromycin"), so it is not repeated here.
  const reason = genotype !== 'UNKNOWN' ? `${genotype} ${stateLabel(activity)}` : stateLabel(activity);
  const l: HrLimits = { high: high, low: low, reason: reason };
  return l;
}

/** Stress fallback from the risk model: HR above resting × 1.35 while awake and not moving (plus low HRV if known). */
export function isStressed(bpm: number, restingBpm: number, activity: Activity, hrvMs: number): boolean {
  if (activity !== 'REST' || restingBpm <= 0 || bpm <= 0) {
    return false;
  }
  const hrHigh = bpm > restingBpm * 1.35;
  return hrvMs > 0 ? hrHigh && hrvMs < 25 : hrHigh;
}
