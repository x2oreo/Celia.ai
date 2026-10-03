import { sensor } from '@kit.SensorServiceKit';
import { Activity, HrSourceKind } from '../model/WatchMetric';
import { ContextSensors, StepsCallback, WearCallback } from '../vitals/ContextSensors';
import { ErrorCallback, HeartRateSource, SampleCallback } from '../vitals/HeartRateSource';
import { MotionAnalyzer } from '../vitals/MotionAnalyzer';
import { SCENARIOS, Scenario, stateAt } from '../vitals/Scenarios';
import { SensorHeartRateSource } from '../vitals/SensorHeartRateSource';
import { SimulatedHeartRateSource } from '../vitals/SimulatedHeartRateSource';
import { isAsleep } from '../vitals/SleepDetector';

export type FallCallback = () => void;

/** What the automatic state detection needs besides the sensors. */
export interface ActivityInputs {
  nowMs: number;
  onWrist: boolean;
  bpm: number;
  restingBpm: number;
}

/**
 * All sensors in one place: the heart-rate source (watch sensor or scripted scenario), accelerometer → rest/active
 * and falls, wear detection and the step counter.
 */
export class SensorHub {
  private source: HeartRateSource | undefined = undefined;
  private simSource: SimulatedHeartRateSource | undefined = undefined;
  private scenario: Scenario = SCENARIOS[0];
  private context: ContextSensors = new ContextSensors();
  private motion: MotionAnalyzer = new MotionAnalyzer();
  private motionAvailable: boolean = false;
  private stillSinceMs: number = -1;
  private sensorStepsBase: number = -1;
  private simSteps: number = 0;

  /** True when the device has a heart-rate sensor. */
  static heartRateSensorPresent(): boolean {
    try {
      sensor.getSingleSensorSync(sensor.SensorId.HEART_RATE);
      return true;
    } catch (e) {
      return false;
    }
  }

  /** True while scripted demo data drives the heart rate. */
  get simulated(): boolean {
    return this.simSource !== undefined;
  }

  /** Seconds into the demo scenario; 0 without one. */
  get scenarioSec(): number {
    return this.simSource !== undefined ? this.simSource.elapsedSec : 0;
  }

  /** Starts the HR source and the context sensors. Returns which context sensors started, for the log. */
  start(kind: HrSourceKind, scenarioIdx: number, demoSpeed: number, canCountSteps: boolean, onSample: SampleCallback,
    onError: ErrorCallback, onFall: FallCallback, onWear: WearCallback, onSteps: StepsCallback): string[] {
    this.stillSinceMs = -1;
    this.motion = new MotionAnalyzer();
    this.scenario = SCENARIOS[scenarioIdx];
    if (kind === 'SENSOR') {
      this.source = new SensorHeartRateSource();
    } else {
      const sim = new SimulatedHeartRateSource(this.scenario.id, demoSpeed);
      this.simSource = sim;
      this.source = sim;
    }
    this.source.start(onSample, onError);
    const started = this.context.start((x: number, y: number, z: number, tsMs: number) => {
      if (this.motion.feed(x, y, z, tsMs)) {
        onFall();
      }
    }, onWear, (total: number) => {
      onSteps(this.stepsFromTotal(total));
    }, canCountSteps);
    this.motionAvailable = started.indexOf('motion') >= 0;
    return started;
  }

  stop(): void {
    this.source?.stop();
    this.source = undefined;
    this.simSource = undefined;
    this.context.stop();
  }

  /** Clock for timing rules: scenario time in demo mode (fast-forwarded), wall clock otherwise. */
  logicNow(nowMs: number): number {
    return this.simSource !== undefined ? this.simSource.virtualNowMs : nowMs;
  }

  /** Demo scenario → its scripted state; otherwise accelerometer (+ sleep detector). */
  activity(inp: ActivityInputs): Activity {
    if (this.simSource !== undefined) {
      return stateAt(this.scenario, this.simSource.elapsedSec);
    }
    const now = inp.nowMs;
    const moving = this.motionAvailable ? this.motion.activityAt(now) : 'UNKNOWN';
    if (moving === 'REST') {
      if (this.stillSinceMs < 0) {
        this.stillSinceMs = now;
      }
      const asleep = isAsleep({
        onWrist: inp.onWrist,
        stillSec: (now - this.stillSinceMs) / 1000,
        bpm: inp.bpm,
        restingBpm: inp.restingBpm,
        hour: new Date(now).getHours()
      });
      return asleep ? 'ASLEEP' : 'REST';
    }
    this.stillSinceMs = -1;
    return moving;
  }

  /** Demo cadence while active in a scenario; returns the steps added. */
  addSimSteps(steps: number): number {
    this.simSteps += steps;
    return steps;
  }

  /** The step counter reports a running total since boot; show steps since the app started. */
  stepsFromTotal(total: number): number {
    if (this.sensorStepsBase < 0) {
      this.sensorStepsBase = total;
    }
    return this.simSteps + total - this.sensorStepsBase;
  }
}
