import { HrSourceKind } from '../model/WatchMetric';
import { ErrorCallback, HeartRateSource, SampleCallback } from './HeartRateSource';
import { Scenario, bpmAt, findScenario } from './Scenarios';

/**
 * Emits one scripted sample per real second (with ±2 bpm noise). `speed` > 1 fast-forwards the scenario for demos;
 * the controller then runs its timing rules on `virtualNowMs` so sustain/cooldown/recovery speed up too.
 */
export class SimulatedHeartRateSource implements HeartRateSource {
  readonly kind: HrSourceKind = 'SIMULATED';
  private scenario: Scenario;
  private speed: number;
  private timer: number = -1;
  private startedAt: number = 0;

  constructor(scenarioId: string, speed: number) {
    this.scenario = findScenario(scenarioId);
    this.speed = Math.max(1, speed);
  }

  /** Scenario seconds since start (real seconds × speed). */
  get elapsedSec(): number {
    return (Date.now() - this.startedAt) / 1000 * this.speed;
  }

  /** Clock for timing rules in demo mode: start + scenario time. */
  get virtualNowMs(): number {
    return this.startedAt + this.elapsedSec * 1000;
  }

  start(onSample: SampleCallback, onError: ErrorCallback): void {
    this.stop();
    this.startedAt = Date.now();
    this.timer = setInterval(() => {
      const base = bpmAt(this.scenario, this.elapsedSec);
      const noise = (Math.random() - 0.5) * 4;
      onSample(Math.round(base + noise), Date.now());
    }, 1000);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
}
