import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConfig, AppConfigData } from '../common/AppConfig';
import { Logger } from '../common/Logger';
import {
  HrAlertValues,
  HrLiveValues,
  HrSourceKind,
  MedicationTakenValues,
  MetricPayload,
  MetricType,
  SymptomKind,
  SymptomValues,
  makeRow,
  sourceForKind
} from '../model/WatchMetric';
import { AlarmRules } from '../vitals/AlarmRules';
import { HeartRateSource } from '../vitals/HeartRateSource';
import { SCENARIOS } from '../vitals/Scenarios';
import { SensorHeartRateSource } from '../vitals/SensorHeartRateSource';
import { SessionStats } from '../vitals/SessionStats';
import { SimulatedHeartRateSource } from '../vitals/SimulatedHeartRateSource';
import { MemoryOutboxStore, MetricOutbox } from '../sync/MetricOutbox';
import { PreferencesOutboxStore } from '../sync/PreferencesOutboxStore';
import { SupabaseUploader } from '../sync/SupabaseUploader';

export type SyncState = 'OFF' | 'OK' | 'PENDING' | 'ERROR';

const LIVE_EVERY_MS = 5000;
const SYNC_EVERY_MS = 3000;
const BATCH = 50;

/** All watch state and behaviour. The UI only renders it and forwards taps. */
@ObservedV2
export class WatchController {
  @Trace bpm: number = 0;
  @Trace running: boolean = false;
  @Trace sourceKind: HrSourceKind = 'SIMULATED';
  @Trace scenarioIdx: number = 0;
  @Trace alertText: string = '';
  @Trace statusText: string = '';
  @Trace syncState: SyncState = 'OFF';
  @Trace pending: number = 0;
  @Trace elapsedSec: number = 0;
  @Trace highBpm: number = 140;
  @Trace lowBpm: number = 45;

  private ctx: common.UIAbilityContext | undefined = undefined;
  private cfg: AppConfigData = AppConfig.defaults();
  private source: HeartRateSource | undefined = undefined;
  private alarm: AlarmRules = new AlarmRules(AlarmRules.defaultConfig(140, 45));
  private stats: SessionStats = new SessionStats();
  private outbox: MetricOutbox = new MetricOutbox(new MemoryOutboxStore(), 500);
  private uploader: SupabaseUploader | undefined = undefined;
  private lastLiveMs: number = 0;
  private syncTimer: number = -1;
  private syncing: boolean = false;

  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
    this.cfg = AppConfig.load(ctx);
    this.sourceKind = this.cfg.defaultSource;
    this.highBpm = this.cfg.highBpm;
    this.lowBpm = this.cfg.lowBpm;
    this.alarm = new AlarmRules(AlarmRules.defaultConfig(this.cfg.highBpm, this.cfg.lowBpm));
    try {
      this.outbox = new MetricOutbox(new PreferencesOutboxStore(ctx), 500);
    } catch (e) {
      Logger.warn('preferences unavailable, outbox is in-memory only');
    }
    this.pending = this.outbox.size;
    if (AppConfig.canUpload(this.cfg)) {
      this.uploader = new SupabaseUploader(this.cfg.supabaseUrl, this.cfg.supabaseAnonKey);
      this.syncState = this.pending > 0 ? 'PENDING' : 'OK';
    }
    this.syncTimer = setInterval(() => {
      this.syncNow();
    }, SYNC_EVERY_MS);
  }

  dispose(): void {
    this.stop();
    if (this.syncTimer >= 0) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
    }
  }

  get scenarioLabel(): string {
    return SCENARIOS[this.scenarioIdx].label;
  }

  get isDemoData(): boolean {
    return this.sourceKind === 'SIMULATED';
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    if (this.sourceKind === 'SENSOR' && !(await this.ensureHealthPermission())) {
      this.statusText = 'No heart-rate permission, using demo data';
      this.sourceKind = 'SIMULATED';
    }
    this.stats = new SessionStats();
    this.alarm.reset();
    this.alertText = '';
    this.bpm = 0;
    this.elapsedSec = 0;
    this.lastLiveMs = 0;
    this.running = true;
    this.source = this.createSource(this.sourceKind);
    this.source.start((bpm: number, tsMs: number) => {
      this.onSample(bpm, tsMs);
    }, (msg: string) => {
      this.onSourceError(msg);
    });
    Logger.info(`session started, source=${this.sourceKind}`);
  }

  stop(): void {
    if (!this.running) {
      return;
    }
    this.source?.stop();
    this.source = undefined;
    this.running = false;
    const summary = this.stats.summary();
    if (summary !== undefined) {
      this.record('hr_session', summary, Date.now());
    }
    Logger.info('session stopped');
  }

  async toggle(): Promise<void> {
    if (this.running) {
      this.stop();
    } else {
      await this.start();
    }
  }

  /** Toggles demo data ↔ watch sensor. Restarts the session if one is running. */
  async cycleSource(): Promise<void> {
    this.sourceKind = this.sourceKind === 'SIMULATED' ? 'SENSOR' : 'SIMULATED';
    this.statusText = '';
    await this.restartIfRunning();
  }

  async cycleScenario(): Promise<void> {
    this.scenarioIdx = (this.scenarioIdx + 1) % SCENARIOS.length;
    if (this.sourceKind === 'SIMULATED') {
      await this.restartIfRunning();
    }
  }

  dismissAlert(): void {
    this.alertText = '';
  }

  logSymptom(kind: SymptomKind): void {
    const v: SymptomValues = { kind: kind, bpm: this.running ? this.bpm : 0 };
    this.record('symptom', v, Date.now());
  }

  logMedication(): void {
    const v: MedicationTakenValues = { name: this.cfg.medicationName };
    this.record('medication_taken', v, Date.now());
  }

  get medicationName(): string {
    return this.cfg.medicationName;
  }

  async syncNow(): Promise<void> {
    if (this.uploader === undefined || this.syncing || this.outbox.size === 0) {
      return;
    }
    this.syncing = true;
    const batch = this.outbox.peek(BATCH);
    const res = await this.uploader.upload(batch);
    if (res.ok) {
      this.outbox.ack(batch.length);
      this.syncState = this.outbox.size > 0 ? 'PENDING' : 'OK';
    } else {
      this.syncState = 'ERROR';
      Logger.warn(`sync failed: ${res.message}`);
    }
    this.pending = this.outbox.size;
    this.syncing = false;
  }

  private async restartIfRunning(): Promise<void> {
    if (this.running) {
      this.stop();
      await this.start();
    }
  }

  private createSource(kind: HrSourceKind): HeartRateSource {
    if (kind === 'SENSOR') {
      return new SensorHeartRateSource();
    }
    return new SimulatedHeartRateSource(SCENARIOS[this.scenarioIdx].id);
  }

  private onSample(bpm: number, tsMs: number): void {
    this.bpm = bpm;
    this.statusText = '';
    this.stats.add(bpm, tsMs);
    this.elapsedSec = this.stats.durationSec;
    if (tsMs - this.lastLiveMs >= LIVE_EVERY_MS) {
      this.lastLiveMs = tsMs;
      const live: HrLiveValues = { bpm: bpm };
      this.record('hr_live', live, tsMs);
    }
    const alert = this.alarm.evaluate(bpm, tsMs);
    if (alert !== undefined) {
      this.raiseAlert(alert, tsMs);
    }
  }

  private onSourceError(msg: string): void {
    this.statusText = msg;
    if (this.sourceKind === 'SENSOR') {
      // Emulator / no sensor: keep the demo alive on scripted data, clearly labelled.
      this.source?.stop();
      this.sourceKind = 'SIMULATED';
      this.statusText = 'No HR sensor, using demo data';
      this.source = this.createSource('SIMULATED');
      this.source.start((bpm: number, tsMs: number) => {
        this.onSample(bpm, tsMs);
      }, (m: string) => {
        this.statusText = m;
      });
    }
  }

  private raiseAlert(alert: HrAlertValues, tsMs: number): void {
    this.alertText = alert.direction === 'high'
      ? `High heart rate ${alert.bpm} (limit ${alert.limitBpm})`
      : `Low heart rate ${alert.bpm} (limit ${alert.limitBpm})`;
    this.record('hr_alert', alert, tsMs);
    this.vibrate();
    Logger.info(`alert: ${this.alertText}`);
  }

  private record(type: MetricType, payload: MetricPayload, tsMs: number): void {
    this.outbox.enqueue(makeRow(this.cfg.deviceId, type, payload, tsMs, sourceForKind(this.sourceKind)));
    this.pending = this.outbox.size;
    if (this.uploader !== undefined) {
      this.syncState = 'PENDING';
    }
  }

  private vibrate(): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: 1200 };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'alarm' };
    vibrator.startVibration(effect, attr).catch((err: BusinessError) => {
      Logger.warn(`vibrate failed: ${err.code}`);
    });
  }

  private async ensureHealthPermission(): Promise<boolean> {
    if (this.ctx === undefined) {
      return false;
    }
    const perms: Permissions[] = ['ohos.permission.READ_HEALTH_DATA'];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(this.ctx, perms);
      return res.authResults.length > 0 && res.authResults[0] === 0;
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`permission request failed: ${err.code}`);
      return false;
    }
  }
}
