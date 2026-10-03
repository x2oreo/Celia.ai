import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

export type MotionCallback = (x: number, y: number, z: number, tsMs: number) => void;
export type WearCallback = (onWrist: boolean) => void;
export type StepsCallback = (steps: number) => void;

/** 25 Hz is enough for activity and impact detection and cheap on battery. */
const ACCEL_INTERVAL_NS = 40000000;

/**
 * Accelerometer, wear detection and step counter. Each is optional: the emulator has some of them, and the app
 * relies on scenario data or the Simulate page for the rest.
 */
export class ContextSensors {
  private accelOn: boolean = false;
  private wearOn: boolean = false;
  private stepsOn: boolean = false;

  /** Returns which sensors started, e.g. for the log. */
  start(onMotion: MotionCallback, onWear: WearCallback, onSteps: StepsCallback, canCountSteps: boolean): string[] {
    this.stop();
    const started: string[] = [];
    try {
      sensor.getSingleSensorSync(sensor.SensorId.ACCELEROMETER);
      sensor.on(sensor.SensorId.ACCELEROMETER, (d: sensor.AccelerometerResponse) => {
        onMotion(d.x, d.y, d.z, Date.now());
      }, { interval: ACCEL_INTERVAL_NS });
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
