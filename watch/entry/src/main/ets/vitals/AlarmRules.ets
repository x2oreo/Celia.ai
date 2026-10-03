import { Activity, AlertDirection, HrAlertValues } from '../model/WatchMetric';

export interface AlarmConfig {
  /** High limit while moving, or when activity is unknown. */
  highBpm: number;
  /** Stricter high limit at rest: a racing heart without exertion is the LQT2 warning pattern. */
  restHighBpm: number;
  lowBpm: number;
  /** HR must stay out of range this long before we alert (filters motion artefacts). */
  sustainSec: number;
  /** After an alert, the same direction stays quiet this long. */
  cooldownSec: number;
}

/**
 * Deterministic, context-aware HR alarm rules. Pure logic, no timers: feed it samples with their timestamps.
 * Not a diagnosis: it only says "heart rate outside your limits for N seconds".
 */
export class AlarmRules {
  private cfg: AlarmConfig;
  private highSince: number = -1;
  private lowSince: number = -1;
  private lastHighAlert: number = -1;
  private lastLowAlert: number = -1;

  constructor(cfg: AlarmConfig) {
    this.cfg = cfg;
  }

  static defaultConfig(highBpm: number, restHighBpm: number, lowBpm: number): AlarmConfig {
    const cfg: AlarmConfig = {
      highBpm: highBpm,
      restHighBpm: restHighBpm,
      lowBpm: lowBpm,
      sustainSec: 10,
      cooldownSec: 60
    };
    return cfg;
  }

  get config(): AlarmConfig {
    return this.cfg;
  }

  highLimitFor(activity: Activity): number {
    return activity === 'REST' ? this.cfg.restHighBpm : this.cfg.highBpm;
  }

  reset(): void {
    this.highSince = -1;
    this.lowSince = -1;
    this.lastHighAlert = -1;
    this.lastLowAlert = -1;
  }

  /** Returns an alert when a limit has just been crossed for long enough, otherwise undefined. */
  evaluate(bpm: number, tsMs: number, activity: Activity): HrAlertValues | undefined {
    const highLimit = this.highLimitFor(activity);
    if (bpm > highLimit) {
      this.lowSince = -1;
      if (this.highSince < 0) {
        this.highSince = tsMs;
      }
      return this.maybeAlert('high', bpm, highLimit, tsMs, activity);
    }
    if (bpm < this.cfg.lowBpm) {
      this.highSince = -1;
      if (this.lowSince < 0) {
        this.lowSince = tsMs;
      }
      return this.maybeAlert('low', bpm, this.cfg.lowBpm, tsMs, activity);
    }
    this.highSince = -1;
    this.lowSince = -1;
    return undefined;
  }

  private maybeAlert(direction: AlertDirection, bpm: number, limit: number, tsMs: number,
    activity: Activity): HrAlertValues | undefined {
    const since = direction === 'high' ? this.highSince : this.lowSince;
    const sustainedMs = tsMs - since;
    if (sustainedMs < this.cfg.sustainSec * 1000) {
      return undefined;
    }
    const last = direction === 'high' ? this.lastHighAlert : this.lastLowAlert;
    if (last >= 0 && tsMs - last < this.cfg.cooldownSec * 1000) {
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
