// Heart monitoring: a sample source (the Celia watch via Supabase when a backend is configured, otherwise simulated),
// AlarmRules per genotype, a short in-memory history for the chart, and alerts logged to LocalStore.

import { VitalsAlert, VitalsSample, VitalsSourceKind } from '../model/Vitals';
import { Profile } from '../model/Profile';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { AlarmRules } from './AlarmRules';
import { ScenarioName, scenarioSample } from './SimulatedSource';
import { WatchCloudSource } from './WatchCloudSource';
import { Config } from '../common/Config';

const log: Logger = new Logger('Vitals');

const TICK_MS: number = 1000;
const SILENCE_MS: number = 10000;
const KEEP_SAMPLES: number = 90;
const KEEP_ALERTS: number = 30;

export class VitalsService {
  private static instance: VitalsService | undefined = undefined;

  private samples: Listeners<VitalsSample> = new Listeners<VitalsSample>();
  private alerts: Listeners<VitalsAlert> = new Listeners<VitalsAlert>();
  private answers: Listeners<string> = new Listeners<string>();
  private source: VitalsSourceKind | undefined = undefined;
  private rules: AlarmRules = new AlarmRules('UNKNOWN');
  private timer: number = -1;
  private scenario: ScenarioName = 'normal';
  private scenarioStart: number = 0;
  private lastSampleTs: number = 0;
  private recent: VitalsSample[] = [];
  private recentAlerts: VitalsAlert[] = [];
  private watch: WatchCloudSource | undefined = undefined;

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
    if (source === 'WATCH' && !Config.hasBackend()) {
      // The watch reaches the phone through Supabase; without a backend fall back, clearly labelled.
      log.warn('WATCH source needs a backend (LocalConfig.ets) — using SIMULATED');
    }
    this.source = source === 'WATCH' && Config.hasBackend() ? 'WATCH' : 'SIMULATED';
    this.loadGenotype();
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile') {
        this.loadGenotype();
      }
    });
    this.scenarioStart = Date.now();
    this.lastSampleTs = Date.now();
    if (this.source === 'WATCH') {
      const w: WatchCloudSource = new WatchCloudSource();
      w.start({
        onSample: (s: VitalsSample) => this.ingest(s),
        onAlert: (a: VitalsAlert) => this.fire(a),
        onAnswer: (kind: string) => this.answers.emit(kind)
      });
      this.watch = w;
      // Same silence check as the simulated source: no watch data for a while → WATCH_DISCONNECTED.
      this.timer = setInterval(() => this.checkSilence(Date.now()), TICK_MS);
    } else {
      this.timer = setInterval(() => this.tick(), TICK_MS);
    }
    log.info(`started ${this.source}`);
  }

  stop(): void {
    this.watch?.stop();
    this.watch = undefined;
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

  // "How do you feel?" answers given on the watch. Returns an unsubscribe function.
  onWatchAnswer(cb: Listener<string>): () => void {
    return this.answers.add(cb);
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
    if (this.source === 'WATCH') {
      log.info('scenarios only apply to the simulated source');
      return;
    }
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
      this.checkSilence(now);
      return;
    }
    this.ingest(s);
  }

  private checkSilence(now: number): void {
    if (now - this.lastSampleTs > SILENCE_MS) {
      const a: VitalsAlert | undefined = this.rules.disconnected(now);
      if (a !== undefined) {
        this.fire(a);
      }
    }
  }

  // One sample from any source: history for the chart, listeners, per-sample alarm rules.
  private ingest(s: VitalsSample): void {
    this.lastSampleTs = Date.now();
    this.recent.push(s);
    if (this.recent.length > KEEP_SAMPLES) {
      this.recent.shift();
    }
    this.samples.emit(s);
    // With a real watch, its own hr_alert / rhythm_alert / vitals_alert rows are the alerts (WatchCloudSource.toAlert).
    // Running the phone's rules on the same numbers too gave two answers for one heart rate (e.g. 120 at rest).
    if (this.source === 'WATCH') {
      return;
    }
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
