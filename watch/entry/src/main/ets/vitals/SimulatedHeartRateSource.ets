import { HrSourceKind } from '../model/WatchMetric';
import { ErrorCallback, HeartRateSource, SampleCallback } from './HeartRateSource';
import { Scenario, bpmAt, findScenario } from './Scenarios';

/** Emits one scripted sample per second (with ±2 bpm noise). Used on the emulator and in the previewer. */
export class SimulatedHeartRateSource implements HeartRateSource {
  readonly kind: HrSourceKind = 'SIMULATED';
  private scenario: Scenario;
  private timer: number = -1;
  private startedAt: number = 0;

  constructor(scenarioId: string) {
    this.scenario = findScenario(scenarioId);
  }

  start(onSample: SampleCallback, onError: ErrorCallback): void {
    this.stop();
    this.startedAt = Date.now();
    this.timer = setInterval(() => {
      const now = Date.now();
      const base = bpmAt(this.scenario, (now - this.startedAt) / 1000);
      const noise = (Math.random() - 0.5) * 4;
      onSample(Math.round(base + noise), now);
    }, 1000);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
}
