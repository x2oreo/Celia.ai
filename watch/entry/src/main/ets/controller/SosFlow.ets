import { Activity, FallResponse, FallValues, SosReason, SosValues } from '../model/WatchMetric';
import { Fix } from '../sync/SosLocation';

/** How long the wearer has to answer "Are you OK?" after a fall. */
export const FALL_COUNTDOWN_SEC = 30;
/** SOS countdown before the emergency row is sent; Cancel stops it. */
export const SOS_COUNTDOWN_SEC = 10;

/** What a one-second tick of the fall countdown asks the controller to do. */
export type FallTick = 'NONE' | 'VIBRATE' | 'TIMED_OUT';

/** A finished fall: the `fall_detected` row and when the fall happened (the row's timestamp). */
export interface FallRecord {
  values: FallValues;
  atMs: number;
}

/**
 * Fall "Are you OK?" countdown and SOS countdown → `sos` row → delivered. Pure state machine with the clock passed
 * in; the controller does the side effects (rows, vibration, notifications, location).
 */
@ObservedV2
export class SosFlow {
  /** Seconds left to answer "Are you OK?"; 0 = no fall in progress. */
  @Trace fallCountdown: number = 0;
  @Trace sosCountdown: number = 0;
  @Trace sosSent: boolean = false;
  /** True once the `sos` row reached the server. Until then the screen says saved, not sent. */
  @Trace sosDelivered: boolean = false;

  private fallStartMs: number = 0;
  private fallBpm: number = 0;
  private sosStartMs: number = 0;
  private sosReason: SosReason = 'need_help';
  private sosFix: Fix | undefined = undefined;

  /** False while a fall countdown is already running. */
  startFall(bpm: number, now: number): boolean {
    if (this.fallCountdown > 0) {
      return false;
    }
    this.fallBpm = bpm;
    this.fallStartMs = now;
    this.fallCountdown = FALL_COUNTDOWN_SEC;
    return true;
  }

  tickFall(now: number): FallTick {
    if (this.fallCountdown <= 0) {
      return 'NONE';
    }
    const left = FALL_COUNTDOWN_SEC - Math.floor((now - this.fallStartMs) / 1000);
    if (left <= 0) {
      return 'TIMED_OUT';
    }
    this.fallCountdown = left;
    return left % 5 === 0 ? 'VIBRATE' : 'NONE';
  }

  finishFall(response: FallResponse, now: number): FallRecord {
    const v: FallValues = {
      bpm: this.fallBpm,
      response: response,
      responseSec: Math.round((now - this.fallStartMs) / 1000)
    };
    this.fallCountdown = 0;
    const r: FallRecord = { values: v, atMs: this.fallStartMs };
    return r;
  }

  /** False while an SOS countdown is already running. */
  startSos(reason: SosReason, now: number): boolean {
    if (this.sosCountdown > 0) {
      return false;
    }
    this.sosReason = reason;
    this.sosStartMs = now;
    this.sosCountdown = SOS_COUNTDOWN_SEC;
    this.sosFix = undefined;
    return true;
  }

  /** Location for the `sos` row, if it arrives before the countdown ends. */
  setFix(fix: Fix | undefined): void {
    this.sosFix = fix;
  }

  /** The `sos` row when the countdown has just run out, otherwise undefined. */
  tickSos(now: number, bpm: number, activity: Activity): SosValues | undefined {
    if (this.sosCountdown <= 0) {
      return undefined;
    }
    const left = SOS_COUNTDOWN_SEC - Math.floor((now - this.sosStartMs) / 1000);
    if (left > 0) {
      this.sosCountdown = left;
      return undefined;
    }
    this.sosCountdown = 0;
    const v: SosValues = { reason: this.sosReason, bpm: bpm, activity: activity };
    if (this.sosFix !== undefined) {
      v.lat = this.sosFix.lat;
      v.lon = this.sosFix.lon;
      v.accuracyM = this.sosFix.accuracyM;
    }
    this.sosSent = true;
    this.sosDelivered = false;
    return v;
  }

  cancelSos(): void {
    this.sosCountdown = 0;
  }

  dismissSent(): void {
    this.sosSent = false;
  }

  /**
   * After a successful upload: true when this is the moment the sent `sos` row left the queue. A dropped
   * (server-rejected) row never gets here, so it stays "saved".
   */
  confirmDelivery(sosStillQueued: boolean): boolean {
    if (!this.sosSent || this.sosDelivered || sosStillQueued) {
      return false;
    }
    this.sosDelivered = true;
    return true;
  }
}
