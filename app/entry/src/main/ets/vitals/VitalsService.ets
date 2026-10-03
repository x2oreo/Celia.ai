// OWNER: Mark — STUB. Replace with WearEngineSource (real watch) / SimulatedSource (emulator) + AlarmRules.

import { VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Vitals');

export class VitalsService {
  private static instance: VitalsService | undefined = undefined;

  private samples: Listeners<VitalsSample> = new Listeners<VitalsSample>();
  private alerts: Listeners<VitalsAlert> = new Listeners<VitalsAlert>();
  private source: VitalsSourceKind | undefined = undefined;

  static get(): VitalsService {
    if (VitalsService.instance === undefined) {
      VitalsService.instance = new VitalsService();
    }
    return VitalsService.instance;
  }

  start(source: VitalsSourceKind): void {
    this.source = source;
    log.info(`start(${source}) — stub, no samples emitted`);
  }

  stop(): void {
    this.source = undefined;
  }

  isRunning(): boolean {
    return this.source !== undefined;
  }

  // Returns an unsubscribe function.
  onSample(cb: Listener<VitalsSample>): () => void {
    return this.samples.add(cb);
  }

  onAlert(cb: Listener<VitalsAlert>): () => void {
    return this.alerts.add(cb);
  }

  runScenario(name: string): void {
    log.info(`runScenario(${name}) — stub`);
  }
}
