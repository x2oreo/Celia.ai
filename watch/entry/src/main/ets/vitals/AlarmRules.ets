import { Activity, AlertDirection, HrAlertValues } from '../model/WatchMetric';
import { HrLimits } from './Limits';

export interface AlarmTiming {
  /** HR must stay out of range this long before we alert (filters motion artefacts). */
  sustainSec: number;
  /** After an alert, the same direction stays quiet this long. */
  cooldownSec: number;
}

/**
 * Deterministic HR alarm rules. Limits come from `limitsFor()` (state + genotype + drug), so the same code serves
 * rest, activity and sleep. Pure logic, no timers. Not a diagnosis: "heart rate outside your limits for N seconds".
 */
export class AlarmRules {
  private timing: AlarmTiming;
  private highSince: number = -1;
  private lowSince: number = -1;
  private lastHighAlert: number = -1;
  private lastLowAlert: number = -1;

  constructor(timing: AlarmTiming) {
    this.timing = timing;
  }

  static defaultTiming(): AlarmTiming {
    const t: AlarmTiming = { sustainSec: 5, cooldownSec: 60 };
    return t;
  }

  reset(): void {
    this.highSince = -1;
    this.lowSince = -1;
    this.lastHighAlert = -1;
    this.lastLowAlert = -1;
  }

  /** Returns an alert when a limit has just been crossed for long enough, otherwise undefined. */
  evaluate(bpm: number, tsMs: number, limits: HrLimits, activity: Activity): HrAlertValues | undefined {
    if (bpm > limits.high) {
      this.lowSince = -1;
      if (this.highSince < 0) {
        this.highSince = tsMs;
      }
      return this.maybeAlert('high', bpm, limits.high, tsMs, activity);
    }
    if (bpm < limits.low) {
      this.highSince = -1;
      if (this.lowSince < 0) {
        this.lowSince = tsMs;
      }
      return this.maybeAlert('low', bpm, limits.low, tsMs, activity);
    }
    this.highSince = -1;
    this.lowSince = -1;
    return undefined;
  }

  private maybeAlert(direction: AlertDirection, bpm: number, limit: number, tsMs: number,
    activity: Activity): HrAlertValues | undefined {
    const since = direction === 'high' ? this.highSince : this.lowSince;
    const sustainedMs = tsMs - since;
    if (sustainedMs < this.timing.sustainSec * 1000) {
      return undefined;
    }
    const last = direction === 'high' ? this.lastHighAlert : this.lastLowAlert;
    if (last >= 0 && tsMs - last < this.timing.cooldownSec * 1000) {
      return undefined;
    }
    if (direction === 'high') {
      this.lastHighAlert = tsMs;
    } else {
      this.lastLowAlert = tsMs;
    }
    const alert: HrAlertValues = {
      bpm: bpm,
      limitBpm: limit,
      direction: direction,
      sustainedSec: Math.round(sustainedMs / 1000),
      activity: activity
    };
    return alert;
  }
}
