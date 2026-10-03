import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HrSourceKind } from '../model/WatchMetric';
import { Logger } from '../common/Logger';
import { ErrorCallback, HeartRateSource, SampleCallback } from './HeartRateSource';

interface BridgeReading {
  bpm: number;
  /** Unix ms when the Mac received the BLE notification. */
  ts: number;
}

const STALE_MS = 10000;

/**
 * Real heart rate from a GT 6 Pro: the watch broadcasts HR over BLE during a workout ("Share heart rate"),
 * a script on the Mac (tools/hr-bridge) reads it and serves the latest value at GET {bridgeUrl}/hr.
 * This source polls it once per second.
 */
export class BridgeHeartRateSource implements HeartRateSource {
  readonly kind: HrSourceKind = 'BRIDGE';
  private baseUrl: string;
  private timer: number = -1;
  private lastTs: number = 0;
  private inFlight: boolean = false;
  private failures: number = 0;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  start(onSample: SampleCallback, onError: ErrorCallback): void {
    this.stop();
    this.timer = setInterval(() => {
      this.poll(onSample, onError);
    }, 1000);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private poll(onSample: SampleCallback, onError: ErrorCallback): void {
    if (this.inFlight) {
      return;
    }
    this.inFlight = true;
    const req = http.createHttp();
    req.request(`${this.baseUrl}/hr`, {
      method: http.RequestMethod.GET,
      connectTimeout: 2000,
      readTimeout: 2000,
      expectDataType: http.HttpDataType.STRING
    }).then((resp: http.HttpResponse) => {
      if (resp.responseCode !== 200) {
        this.fail(onError, `bridge HTTP ${resp.responseCode}`);
        return;
      }
      const reading = JSON.parse(resp.result as string) as BridgeReading;
      if (typeof reading.bpm !== 'number' || typeof reading.ts !== 'number') {
        this.fail(onError, 'bridge sent malformed data');
        return;
      }
      this.failures = 0;
      // Only forward new, fresh readings; an old value means the watch stopped broadcasting.
      if (reading.ts > this.lastTs && Date.now() - reading.ts < STALE_MS && reading.bpm > 0) {
        this.lastTs = reading.ts;
        onSample(Math.round(reading.bpm), reading.ts);
      }
    }).catch((err: BusinessError) => {
      this.fail(onError, `bridge unreachable (${err.code})`);
    }).finally(() => {
      this.inFlight = false;
      req.destroy();
    });
  }

  private fail(onError: ErrorCallback, msg: string): void {
    this.failures++;
    // Report once per streak of failures instead of every second.
    if (this.failures === 3) {
      Logger.warn(msg);
      onError(msg);
    }
  }
}
