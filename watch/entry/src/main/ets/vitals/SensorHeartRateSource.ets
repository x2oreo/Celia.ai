import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HrSourceKind } from '../model/WatchMetric';
import { Logger } from '../common/Logger';
import { ErrorCallback, HeartRateSource, SampleCallback } from './HeartRateSource';

/**
 * Real PPG heart rate from the watch's own sensor (full HarmonyOS wearables).
 * Needs ohos.permission.READ_HEALTH_DATA granted at runtime. The emulator has no HR sensor, so start() reports
 * an error there and the controller falls back to the simulated source.
 */
export class SensorHeartRateSource implements HeartRateSource {
  readonly kind: HrSourceKind = 'SENSOR';
  private active: boolean = false;

  start(onSample: SampleCallback, onError: ErrorCallback): void {
    this.stop();
    try {
      sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
        // The sensor reports <= 0 while it is still locking on or the watch is off the wrist.
        if (data.heartRate > 0) {
          onSample(Math.round(data.heartRate), Date.now());
        }
      }, { interval: 1000000000 });
      this.active = true;
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`HR sensor unavailable: ${err.code} ${err.message}`);
      onError(`HR sensor unavailable (${err.code})`);
    }
  }

  stop(): void {
    if (!this.active) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.HEART_RATE);
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`HR sensor off failed: ${err.code}`);
    }
    this.active = false;
  }
}
