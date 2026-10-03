import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { ACCEL_ACTIVE_NS } from './AccelRate';

export type MotionCallback = (x: number, y: number, z: number, tsMs: number) => void;
export type WearCallback = (onWrist: boolean) => void;
export type StepsCallback = (steps: number) => void;

/**
 * Accelerometer, wear detection and step counter. Each is optional: the emulator has some of them, and the app
 * relies on scenario data or the Simulate page for the rest.
 */
export class ContextSensors {
  private accelOn: boolean = false;
  private wearOn: boolean = false;
  private stepsOn: boolean = false;
  private onMotion: MotionCallback | undefined = undefined;
  private accelIntervalNs: number = ACCEL_ACTIVE_NS;

  /** Returns which sensors started, e.g. for the log. */
  start(onMotion: MotionCallback, onWear: WearCallback, onSteps: StepsCallback, canCountSteps: boolean): string[] {
    this.stop();
    const started: string[] = [];
    this.onMotion = onMotion;
    this.accelIntervalNs = ACCEL_ACTIVE_NS;
    try {
      sensor.getSingleSensorSync(sensor.SensorId.ACCELEROMETER);
      this.subscribeAccel();
      this.accelOn = true;
      started.push('motion');
    } catch (e) {
      Logger.warn(`accelerometer unavailable: ${(e as BusinessError).code}`);
    }
    try {
      sensor.getSingleSensorSync(sensor.SensorId.WEAR_DETECTION);
      sensor.on(sensor.SensorId.WEAR_DETECTION, (d: sensor.WearDetectionResponse) => {
        onWear(d.value === 1);
      });
      this.wearOn = true;
      started.push('wear');
    } catch (e) {
      Logger.warn(`wear detection unavailable: ${(e as BusinessError).code}`);
    }
    if (canCountSteps) {
      try {
        sensor.getSingleSensorSync(sensor.SensorId.PEDOMETER);
        sensor.on(sensor.SensorId.PEDOMETER, (d: sensor.PedometerResponse) => {
          onSteps(d.steps);
        });
        this.stepsOn = true;
        started.push('steps');
      } catch (e) {
        Logger.warn(`step counter unavailable: ${(e as BusinessError).code}`);
      }
    }
    return started;
  }

  /**
   * Changes the accelerometer report interval (energy: slower at rest). Resubscribes, since the interval is fixed per
   * subscription.
   */
  setAccelInterval(intervalNs: number): void {
    if (!this.accelOn || intervalNs === this.accelIntervalNs) {
      return;
    }
    this.accelIntervalNs = intervalNs;
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
      this.subscribeAccel();
      Logger.info(`accelerometer every ${intervalNs / 1000000} ms`);
    } catch (e) {
      this.accelOn = false;
      Logger.warn(`accelerometer interval change failed: ${(e as BusinessError).code}`);
    }
  }

  /** Throws like sensor.on; callers catch. */
  private subscribeAccel(): void {
    const onMotion = this.onMotion;
    sensor.on(sensor.SensorId.ACCELEROMETER, (d: sensor.AccelerometerResponse) => {
      if (onMotion !== undefined) {
        onMotion(d.x, d.y, d.z, Date.now());
      }
    }, { interval: this.accelIntervalNs });
  }

  stop(): void {
    try {
      if (this.accelOn) {
        sensor.off(sensor.SensorId.ACCELEROMETER);
      }
      if (this.wearOn) {
        sensor.off(sensor.SensorId.WEAR_DETECTION);
      }
      if (this.stepsOn) {
        sensor.off(sensor.SensorId.PEDOMETER);
      }
    } catch (e) {
      Logger.warn(`context sensors off failed: ${(e as BusinessError).code}`);
    }
    this.accelOn = false;
    this.wearOn = false;
    this.stepsOn = false;
  }
}
