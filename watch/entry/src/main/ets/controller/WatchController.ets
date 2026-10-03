import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { sensor, vibrator } from '@kit.SensorServiceKit';
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
/** Monitoring is continuous, so summaries are sent per window instead of per start/stop. */
const SUMMARY_WINDOW_MS = 5 * 60 * 1000;
/**
 * Heart-rate sensors (and the emulator's virtual one) may report only when the value changes, so the last reading
 * stays valid this long; after that we show "waiting" and stop evaluating.
 */
const READING_VALID_MS = 30000;
const BATCH = 50;
const WAITING = 'Waiting for heart rate…';

/**
 * All watch state and behaviour. The UI only renders it and forwards taps.
 * Monitoring is always on while the app is visible: the page calls resume() on show and pause() on hide.
 * (HarmonyOS freezes background apps and has no continuous-task type for heart-rate monitoring; on a real watch
 * 24/7 data comes from the system's own HR history via Health Service Kit. See watch/README.md.)
 */
@ObservedV2
export class WatchController {
  @Trace bpm: number = 0;
  @Trace running: boolean = false;
  @Trace sourceKind: HrSourceKind = 'SENSOR';
  @Trace scenarioIdx: number = 0;
  @Trace alertText: string = '';
  @Trace statusText: string = '';
  @Trace syncState: SyncState = 'OFF';
  @Trace pending: number = 0;
  @Trace monitoringSec: number = 0;
  @Trace highBpm: number = 140;
  @Trace lowBpm: number = 45;

  private ctx: common.UIAbilityContext | undefined = undefined;
  private cfg: AppConfigData = AppConfig.defaults();
  private source: HeartRateSource | undefined = undefined;
  private alarm: AlarmRules = new AlarmRules(AlarmRules.defaultConfig(140, 45));
  private window: SessionStats = new SessionStats();
  private windowStartMs: number = 0;
  private outbox: MetricOutbox = new MetricOutbox(new MemoryOutboxStore(), 500);
  private uploader: SupabaseUploader | undefined = undefined;
  private lastLiveMs: number = 0;
  private lastSampleMs: number = 0;
  private monitoringSinceMs: number = 0;
  private tickTimer: number = -1;
  private syncTimer: number = -1;
  private syncing: boolean = false;
  private visible: boolean = false;
  private healthPermission: boolean = false;
  private ready: Promise<void> = Promise.resolve();

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
    this.monitoringSinceMs = Date.now();
    // Ask for the HR permission once, up front, so the dialog doesn't interrupt a running monitor.
    this.ready = this.ensureHealthPermission().then((granted: boolean) => {
      this.healthPermission = granted;
    });
  }

  dispose(): void {
    this.pause();
    if (this.syncTimer >= 0) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
    }
  }

  get scenarioLabel(): string {
    return SCENARIOS[this.scenarioIdx].label;
  }

  get medicationName(): string {
    return this.cfg.medicationName;
  }

  /** App became visible: (re)start monitoring. */
  async resume(): Promise<void> {
    this.visible = true;
    await this.ready;
    if (this.visible) {
      this.startSource();
    }
  }

  /** App hidden: the OS will freeze us, so close the summary window and push what we have. */
  pause(): void {
    this.visible = false;
    this.stopSource();
    this.flushWindow(Date.now());
    this.syncNow();
  }

  /** Toggles watch sensor ↔ demo data. */
  cycleSource(): void {
    this.sourceKind = this.sourceKind === 'SENSOR' ? 'SIMULATED' : 'SENSOR';
    this.restart();
  }

  cycleScenario(): void {
    this.scenarioIdx = (this.scenarioIdx + 1) % SCENARIOS.length;
    if (this.sourceKind === 'SIMULATED') {
      this.restart();
    }
  }

  dismissAlert(): void {
    this.alertText = '';
  }

  logSymptom(kind: SymptomKind): void {
    const v: SymptomValues = { kind: kind, bpm: this.bpm };
    this.record('symptom', v, Date.now());
  }

  logMedication(): void {
    const v: MedicationTakenValues = { name: this.cfg.medicationName };
    this.record('medication_taken', v, Date.now());
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

  private restart(): void {
    this.statusText = '';
    if (this.running) {
      this.stopSource();
      this.startSource();
    }
  }

  private startSource(): void {
    if (this.running) {
      return;
    }
    if (this.sourceKind === 'SENSOR' && !this.sensorUsable()) {
      this.sourceKind = 'SIMULATED';
    }
    this.alarm.reset();
    this.bpm = 0;
    this.lastLiveMs = 0;
    this.lastSampleMs = Date.now();
    this.windowStartMs = Date.now();
    this.window = new SessionStats();
    this.running = true;
    this.source = this.createSource(this.sourceKind);
    this.source.start((bpm: number, tsMs: number) => {
      this.onSample(bpm, tsMs);
    }, (msg: string) => {
      this.onSourceError(msg);
    });
    this.tickTimer = setInterval(() => {
      this.onTick();
    }, 1000);
    Logger.info(`monitoring started, source=${this.sourceKind}`);
  }

  private stopSource(): void {
    if (!this.running) {
      return;
    }
    this.source?.stop();
    this.source = undefined;
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }
    this.running = false;
    Logger.info('monitoring paused');
  }

  /** Sensor present and permission granted; otherwise explain and fall back to labelled demo data. */
  private sensorUsable(): boolean {
    if (!this.healthPermission) {
      this.statusText = 'No heart-rate permission, demo data';
      return false;
    }
    try {
      sensor.getSingleSensorSync(sensor.SensorId.HEART_RATE);
      return true;
    } catch (e) {
      this.statusText = 'No heart-rate sensor, demo data';
      return false;
    }
  }

  private createSource(kind: HrSourceKind): HeartRateSource {
    if (kind === 'SENSOR') {
      return new SensorHeartRateSource();
    }
    return new SimulatedHeartRateSource(SCENARIOS[this.scenarioIdx].id);
  }

  /** Sources only update the current reading; all processing runs once per second here. */
  private onSample(bpm: number, tsMs: number): void {
    this.bpm = bpm;
    this.lastSampleMs = tsMs;
    if (this.statusText === WAITING) {
      this.statusText = '';
    }
  }

  private onTick(): void {
    const now = Date.now();
    this.monitoringSec = Math.round((now - this.monitoringSinceMs) / 1000);
    if (now - this.windowStartMs >= SUMMARY_WINDOW_MS) {
      this.flushWindow(now);
    }
    if (this.bpm <= 0 || now - this.lastSampleMs > READING_VALID_MS) {
      if (this.sourceKind === 'SENSOR' && now - this.lastSampleMs > 8000) {
        this.statusText = WAITING;
        this.bpm = 0;
      }
      return;
    }
    this.window.add(this.bpm, now);
    if (now - this.lastLiveMs >= LIVE_EVERY_MS) {
      this.lastLiveMs = now;
      const live: HrLiveValues = { bpm: this.bpm };
      this.record('hr_live', live, now);
    }
    const alert = this.alarm.evaluate(this.bpm, now);
    if (alert !== undefined) {
      this.raiseAlert(alert, now);
    }
  }

  /** Sends the current window as an `hr_session` summary and starts a new window. */
  private flushWindow(nowMs: number): void {
    const summary = this.window.summary();
    if (summary !== undefined) {
      this.record('hr_session', summary, nowMs);
    }
    this.window = new SessionStats();
    this.windowStartMs = nowMs;
  }

  private onSourceError(msg: string): void {
    this.statusText = msg;
    if (this.sourceKind === 'SENSOR') {
      // Sensor failed at runtime: keep monitoring on scripted data, clearly labelled.
      this.stopSource();
      this.sourceKind = 'SIMULATED';
      this.statusText = 'Sensor failed, demo data';
      this.startSource();
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
