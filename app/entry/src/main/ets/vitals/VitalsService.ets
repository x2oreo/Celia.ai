// Heart monitoring: a sample source (simulated on the emulator; Wear Engine on a real watch — not wired yet),
// AlarmRules per genotype, a short in-memory history for the chart, and alerts logged to LocalStore.

import { VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { Profile } from '../model/Profile';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { AlarmRules } from './AlarmRules';
import { ScenarioName, scenarioSample } from './SimulatedSource';

const log: Logger = new Logger('Vitals');

const TICK_MS: number = 1000;
const SILENCE_MS: number = 10000;
const KEEP_SAMPLES: number = 90;
const KEEP_ALERTS: number = 30;

export class VitalsService {
  private static instance: VitalsService | undefined = undefined;

  private samples: Listeners<VitalsSample> = new Listeners<VitalsSample>();
  private alerts: Listeners<VitalsAlert> = new Listeners<VitalsAlert>();
  private source: VitalsSourceKind | undefined = undefined;
  private rules: AlarmRules = new AlarmRules('UNKNOWN');
  private timer: number = -1;
  private scenario: ScenarioName = 'normal';
  private scenarioStart: number = 0;
  private lastSampleTs: number = 0;
  private recent: VitalsSample[] = [];
  private recentAlerts: VitalsAlert[] = [];

  static get(): VitalsService {
    if (VitalsService.instance === undefined) {
      VitalsService.instance = new VitalsService();
    }
    return VitalsService.instance;
  }

  start(source: VitalsSourceKind): void {
    if (this.source !== undefined) {
      return;
    }
    if (source === 'WATCH') {
      // Wear Engine needs a paired real device (see ARCHITECTURE capability table). Fall back, clearly labelled.
      log.warn('WATCH source not available in this build — using SIMULATED');
    }
    this.source = 'SIMULATED';
    this.loadGenotype();
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile') {
        this.loadGenotype();
      }
    });
    this.scenarioStart = Date.now();
    this.lastSampleTs = Date.now();
    this.timer = setInterval(() => this.tick(), TICK_MS);
    log.info('started SIMULATED');
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.source = undefined;
  }

  isRunning(): boolean {
    return this.source !== undefined;
  }

  sourceKind(): VitalsSourceKind | undefined {
    return this.source;
  }

  currentScenario(): ScenarioName {
    return this.scenario;
  }

  // Returns an unsubscribe function.
  onSample(cb: Listener<VitalsSample>): () => void {
    return this.samples.add(cb);
  }

  onAlert(cb: Listener<VitalsAlert>): () => void {
    return this.alerts.add(cb);
  }

  latest(): VitalsSample | undefined {
    return this.recent.length === 0 ? undefined : this.recent[this.recent.length - 1];
  }

  history(): VitalsSample[] {
    return this.recent.slice();
  }

  alertHistory(): VitalsAlert[] {
    return this.recentAlerts.slice().reverse();
  }

  runScenario(name: string): void {
    this.scenario = name as ScenarioName;
    this.scenarioStart = Date.now();
    this.lastSampleTs = Date.now();
    this.rules.reset();
    log.info(`scenario ${name}`);
  }

  private async loadGenotype(): Promise<void> {
    const p: Profile | undefined = await LocalStore.get().getProfile();
    this.rules.setGenotype(p?.genotype ?? 'UNKNOWN');
  }

  private tick(): void {
    const now: number = Date.now();
    const t: number = (now - this.scenarioStart) / 1000;
    const s: VitalsSample | undefined = scenarioSample(this.scenario, t, now);
    if (s === undefined) {
      if (now - this.lastSampleTs > SILENCE_MS) {
        const a: VitalsAlert | undefined = this.rules.disconnected(now);
        if (a !== undefined) {
          this.fire(a);
        }
      }
      return;
    }
    this.lastSampleTs = now;
    this.recent.push(s);
    if (this.recent.length > KEEP_SAMPLES) {
      this.recent.shift();
    }
    this.samples.emit(s);
    const a: VitalsAlert | undefined = this.rules.evaluate(s);
    if (a !== undefined) {
      this.fire(a);
    }
  }

  // Alerts from slower checks outside the per-sample rules (e.g. BetaBlockerWatch's multi-day trend).
  report(a: VitalsAlert): void {
    this.fire(a);
  }

  private fire(a: VitalsAlert): void {
    this.recentAlerts.push(a);
    if (this.recentAlerts.length > KEEP_ALERTS) {
      this.recentAlerts.shift();
    }
    log.info(`alert ${a.kind} ${a.severity ?? ''} hr=${a.hr}`);
    LocalStore.get().logEvent('VITALS_ALERT', JSON.stringify(a));
    this.alerts.emit(a);
  }
}
