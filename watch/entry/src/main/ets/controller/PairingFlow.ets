import { Logger } from '../common/Logger';
import { PairStatus, PairingApi, PairingCode, RpcResult } from '../sync/PairingClient';

/** Settings: is this watch paired with a phone? UNKNOWN until the first pairing_status answer. */
export type PairState = 'UNKNOWN' | 'PAIRED' | 'NOT_PAIRED' | 'ERROR';

/** Pairing screen state. */
export type PairScreen = 'LOADING' | 'CODE' | 'PAIRED' | 'EXPIRED' | 'ERROR';

export type PairedCallback = () => void;

const NOT_CONFIGURED = 'Supabase is not configured (watch/.env)';

/**
 * Watch ↔ phone pairing: a 6-digit code from the server, shown with a countdown, and pairing_status polled every
 * 2 s until the phone claims it or it expires.
 */
@ObservedV2
export class PairingFlow {
  @Trace pairState: PairState = 'UNKNOWN';
  @Trace pairingOpen: boolean = false;
  @Trace pairScreen: PairScreen = 'LOADING';
  @Trace pairCode: string = '';
  @Trace pairSecondsLeft: number = 0;
  /** The code's whole lifetime in seconds, so the ring can drain over it. */
  @Trace pairTotalSeconds: number = 0;
  @Trace pairError: string = '';

  private api: PairingApi | undefined = undefined;
  private onPaired: PairedCallback = () => {
  };
  private timer: number = -1;
  private expiresMs: number = 0;
  private ticks: number = 0;

  /** No api = Supabase not configured: every call reports an error. */
  configure(api: PairingApi | undefined, onPaired: PairedCallback): void {
    this.api = api;
    this.onPaired = onPaired;
  }

  /** Settings opened: one pairing_status call → "Paired with phone" / "Not paired". */
  async refresh(deviceId: string): Promise<void> {
    if (this.api === undefined) {
      this.pairState = 'ERROR';
      return;
    }
    const r: RpcResult<PairStatus> = await this.api.status(deviceId);
    if (!r.ok) {
      this.pairState = 'ERROR';
      return;
    }
    this.pairState = r.value === 'PAIRED' ? 'PAIRED' : 'NOT_PAIRED';
  }

  /** "Pair with phone" / "New code": asks the server for a code. Returns '' or an error for a toast. */
  async start(deviceId: string): Promise<string> {
    this.pairingOpen = true;
    this.stopPolling();
    if (this.api === undefined) {
      this.pairScreen = 'ERROR';
      this.pairError = NOT_CONFIGURED;
      return this.pairError;
    }
    this.pairScreen = 'LOADING';
    const r: RpcResult<PairingCode> = await this.api.start(deviceId);
    if (!r.ok || r.value === undefined) {
      this.pairScreen = 'ERROR';
      this.pairError = r.error;
      return r.error;
    }
    this.pairCode = r.value.code;
    this.expiresMs = r.value.expiresAtMs;
    this.pairSecondsLeft = Math.max(0, Math.round((this.expiresMs - Date.now()) / 1000));
    this.pairTotalSeconds = this.pairSecondsLeft;
    this.pairScreen = 'CODE';
    this.ticks = 0;
    this.timer = setInterval(() => {
      this.tick(deviceId, Date.now());
    }, 1000);
    Logger.info('pairing code shown');
    return '';
  }

  /** Leaving the pairing screen stops polling. */
  close(): void {
    this.stopPolling();
    this.pairingOpen = false;
  }

  /** Once a second while the code is shown: count down, and poll every other tick. */
  tick(deviceId: string, now: number): void {
    this.pairSecondsLeft = Math.max(0, Math.round((this.expiresMs - now) / 1000));
    this.ticks++;
    if (this.ticks % 2 === 0) {
      this.poll(deviceId);
    }
  }

  stopPolling(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  async poll(deviceId: string): Promise<void> {
    if (this.api === undefined || this.pairScreen !== 'CODE') {
      return;
    }
    const r: RpcResult<PairStatus> = await this.api.status(deviceId);
    if (!r.ok || this.pairScreen !== 'CODE') {
      // Keep polling: a dropped request shouldn't end pairing; the error is logged by the client.
      return;
    }
    if (r.value === 'PAIRED') {
      this.stopPolling();
      this.pairScreen = 'PAIRED';
      this.pairState = 'PAIRED';
      this.onPaired();
      Logger.info('paired with phone');
    } else if (r.value === 'EXPIRED' || r.value === 'NONE' || this.pairSecondsLeft <= 0) {
      this.stopPolling();
      this.pairScreen = 'EXPIRED';
    }
  }
}
