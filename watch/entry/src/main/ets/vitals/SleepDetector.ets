/** Approximate sleep: watch on wrist + no movement for a while + low heart rate + night-time. Pure logic. */
export interface SleepInputs {
  onWrist: boolean;
  /** How long the wearer has been still (seconds). */
  stillSec: number;
  bpm: number;
  restingBpm: number;
  /** Local hour 0-23. */
  hour: number;
}

export const SLEEP_STILL_SEC = 10 * 60;

export function isNight(hour: number): boolean {
  return hour >= 22 || hour < 7;
}

export function isAsleep(i: SleepInputs): boolean {
  return i.onWrist && isNight(i.hour) && i.stillSec >= SLEEP_STILL_SEC && i.bpm > 0 && i.bpm <= i.restingBpm + 10;
}
