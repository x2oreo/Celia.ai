import { AlertDirection, HrAlertValues } from '../model/WatchMetric';

export interface AlarmConfig {
  highBpm: number;
  lowBpm: number;
  /** HR must stay out of range this long before we alert (filters motion artefacts). */
  sustainSec: number;
  /** After an alert, the same direction stays quiet this long. */
  cooldownSec: number;
}

/**
 * Deterministic HR alarm rules. Pure logic, no timers: feed it samples with their timestamps.
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

  static defaultConfig(highBpm: number, lowBpm: number): AlarmConfig {
    const cfg: AlarmConfig = { highBpm: highBpm, lowBpm: lowBpm, sustainSec: 10, cooldownSec: 60 };
    return cfg;
  }

  get config(): AlarmConfig {
    return this.cfg;
  }

  reset(): void {
    this.highSince = -1;
    this.lowSince = -1;
    this.lastHighAlert = -1;
    this.lastLowAlert = -1;
  }

  /** Returns an alert when a limit has just been crossed for long enough, otherwise undefined. */
  evaluate(bpm: number, tsMs: number): HrAlertValues | undefined {
    if (bpm > this.cfg.highBpm) {
      this.lowSince = -1;
      if (this.highSince < 0) {
        this.highSince = tsMs;
      }
      return this.maybeAlert('high', bpm, tsMs);
    }
    if (bpm < this.cfg.lowBpm) {
      this.highSince = -1;
      if (this.lowSince < 0) {
        this.lowSince = tsMs;
      }
      return this.maybeAlert('low', bpm, tsMs);
    }
    this.highSince = -1;
    this.lowSince = -1;
    return undefined;
  }

  private maybeAlert(direction: AlertDirection, bpm: number, tsMs: number): HrAlertValues | undefined {
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
      limitBpm: direction === 'high' ? this.cfg.highBpm : this.cfg.lowBpm,
      direction: direction,
      sustainedSec: Math.round(sustainedMs / 1000)
    };
    return alert;
  }
}
