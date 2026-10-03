// SOS escalation state machine (F-27). Pure — time is passed in, so it is unit tested without timers.
//
//   IDLE ──start──► COUNTDOWN ──ack──► ACKED       ("I'm OK")
//                       │──timeout / sendNow──► SENT
//                       └──cancel──► CANCELLED
//
// Cooldown: after SENT, automatic triggers (vitals alerts) are ignored for 10 minutes so contacts are not
// spammed. Manual SOS and calling are never blocked.

export type SosState = 'IDLE' | 'COUNTDOWN' | 'ACKED' | 'SENT' | 'CANCELLED';

export const COOLDOWN_MS: number = 10 * 60 * 1000;
export const COUNTDOWN_S: number = 30;
export const TEST_COUNTDOWN_S: number = 10;

export class SosController {
  private static instance: SosController | undefined = undefined;

  state: SosState = 'IDLE';
  test: boolean = false;
  private deadline: number = 0;
  private lastSentTs: number = -1;

  static get(): SosController {
    if (SosController.instance === undefined) {
      SosController.instance = new SosController();
    }
    return SosController.instance;
  }

  // Automatic triggers respect the cooldown and never interrupt a running countdown.
  canAutoStart(now: number): boolean {
    return this.state !== 'COUNTDOWN' && !this.inCooldown(now);
  }

  inCooldown(now: number): boolean {
    return this.lastSentTs >= 0 && now - this.lastSentTs < COOLDOWN_MS;
  }

  minutesSinceSent(now: number): number {
    return this.lastSentTs < 0 ? -1 : Math.floor((now - this.lastSentTs) / 60000);
  }

  start(now: number, seconds: number, test: boolean): void {
    this.state = 'COUNTDOWN';
    this.test = test;
    this.deadline = now + seconds * 1000;
  }

  remainingSeconds(now: number): number {
    if (this.state !== 'COUNTDOWN') {
      return 0;
    }
    return Math.max(0, Math.ceil((this.deadline - now) / 1000));
  }

  // Advance time; returns the state after the tick.
  tick(now: number): SosState {
    if (this.state === 'COUNTDOWN' && now >= this.deadline) {
      this.markSent(now);
    }
    return this.state;
  }

  ack(): void {
    if (this.state === 'COUNTDOWN') {
      this.state = 'ACKED';
    }
  }

  sendNow(now: number): void {
    if (this.state === 'COUNTDOWN' || this.state === 'IDLE') {
      this.markSent(now);
    }
  }

  cancel(): void {
    if (this.state === 'COUNTDOWN') {
      this.state = 'CANCELLED';
    }
  }

  // Back to idle after the SOS screen closes (keeps the cooldown).
  reset(): void {
    this.state = 'IDLE';
    this.test = false;
  }

  private markSent(now: number): void {
    this.state = 'SENT';
    if (!this.test) {
      this.lastSentTs = now;
    }
  }
}
