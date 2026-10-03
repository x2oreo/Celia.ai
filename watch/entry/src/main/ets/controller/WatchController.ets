import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { sensor, vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConfig, AppConfigData } from '../common/AppConfig';
import { Logger } from '../common/Logger';
import {
  Activity,
  FallResponse,
  FallValues,
  Genotype,
  HrAlertValues,
  HrLiveValues,
  HrRecoveryValues,
  HrSourceKind,
  MedicationTakenValues,
  MetricPayload,
  MetricType,
  RhythmAlertValues,
  SymptomKind,
  SymptomValues,
  VitalsValues,
  WearStateValues,
  makeRow,
  sourceForKind
} from '../model/WatchMetric';
import { AlarmRules } from '../vitals/AlarmRules';
import { ContextSensors } from '../vitals/ContextSensors';
import { HeartRateSource } from '../vitals/HeartRateSource';
import { BaseLimits, HrLimits, isStressed, limitsFor } from '../vitals/Limits';
import { MOCKED_FIELDS, mockVitals } from '../vitals/MockedVitals';
import { MotionAnalyzer } from '../vitals/MotionAnalyzer';
import { RecoveryTracker } from '../vitals/RecoveryTracker';
import { RestingHr } from '../vitals/RestingHr';
import { SCENARIOS, stateAt } from '../vitals/Scenarios';
import { SensorHeartRateSource } from '../vitals/SensorHeartRateSource';
import { SessionStats } from '../vitals/SessionStats';
import { SimulatedHeartRateSource } from '../vitals/SimulatedHeartRateSource';
import { isAsleep } from '../vitals/SleepDetector';
import { MemoryOutboxStore, MetricOutbox } from '../sync/MetricOutbox';
import { PatientContext, PatientContextClient } from '../sync/PatientContextClient';
import { PreferencesOutboxStore } from '../sync/PreferencesOutboxStore';
import { SupabaseUploader } from '../sync/SupabaseUploader';

export type SyncState = 'OFF' | 'OK' | 'PENDING' | 'ERROR';

/** Simulate-page override for the wearer's state. AUTO = motion sensor / scenario / sleep detector. */
export type ActivityOverride = 'AUTO' | 'REST' | 'ACTIVE' | 'ASLEEP';

const LIVE_EVERY_MS = 5000;
const VITALS_EVERY_MS = 30000;
const MOCK_EVERY_MS = 5000;
const SYNC_EVERY_MS = 3000;
const CONTEXT_EVERY_MS = 60000;
/** Monitoring is continuous, so summaries are sent per window instead of per start/stop. */
const SUMMARY_WINDOW_MS = 5 * 60 * 1000;
/**
 * Heart-rate sensors (and the emulator's virtual one) may report only when the value changes, so the last reading
 * stays valid this long; after that we show "waiting" and stop evaluating.
 */
const READING_VALID_MS = 30000;
/** How long the wearer has to answer "Are you OK?" after a fall. */
const FALL_COUNTDOWN_SEC = 30;
/** Simulated cadence while active in demo scenarios (steps per second). */
const SIM_STEPS_PER_SEC = 2;
const BATCH = 50;
const WAITING = 'Waiting for heart rate…';
const NOT_WORN = 'Watch not worn';

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
  @Trace activity: Activity = 'UNKNOWN';
  @Trace activityOverride: ActivityOverride = 'AUTO';
  @Trace onWrist: boolean = true;
  @Trace limitHigh: number = 120;
  @Trace limitLow: number = 45;
  @Trace limitReason: string = '';
  @Trace genotype: Genotype = 'UNKNOWN';
  @Trace riskyDrug: string = '';
  @Trace restingBpm: number = 65;
  @Trace restingMeasured: boolean = false;
  @Trace stress: boolean = false;
  @Trace steps: number = 0;
  @Trace hrvMs: number = 0;
  @Trace spo2: number = 0;
  @Trace breathingRate: number = 0;
  @Trace irregularRhythm: boolean = false;
  @Trace lastRecovery: string = '';
  @Trace alertText: string = '';
  /** Seconds left to answer "Are you OK?"; 0 = no fall in progress. */
  @Trace fallCountdown: number = 0;
  @Trace emergencyText: string = '';
  @Trace statusText: string = '';
  @Trace syncState: SyncState = 'OFF';
  @Trace pending: number = 0;
  @Trace monitoringSec: number = 0;

  private ctx: common.UIAbilityContext | undefined = undefined;
  private cfg: AppConfigData = AppConfig.defaults();
  private base: BaseLimits = {
    activeHigh: 140,
    restHigh: 120,
    sleepHigh: 100,
    awakeLow: 45,
    sleepLow: 40
  };
  private source: HeartRateSource | undefined = undefined;
  private simSource: SimulatedHeartRateSource | undefined = undefined;
  private sensors: ContextSensors = new ContextSensors();
  private motion: MotionAnalyzer = new MotionAnalyzer();
  private alarm: AlarmRules = new AlarmRules(AlarmRules.defaultTiming());
  private resting: RestingHr = new RestingHr(65);
  private recovery: RecoveryTracker = new RecoveryTracker();
  private window: SessionStats = new SessionStats();
  private windowStartMs: number = 0;
  private outbox: MetricOutbox = new MetricOutbox(new MemoryOutboxStore(), 500);
  private uploader: SupabaseUploader | undefined = undefined;
  private contextClient: PatientContextClient | undefined = undefined;
  private lastLiveMs: number = 0;
  private lastVitalsMs: number = 0;
  private lastMockMs: number = 0;
  private lastContextMs: number = 0;
  private lastSampleMs: number = 0;
  private monitoringSinceMs: number = 0;
  private stillSinceMs: number = -1;
  private motionAvailable: boolean = false;
  private sensorStepsBase: number = -1;
  private simSteps: number = 0;
  private fallStartMs: number = 0;
  private fallBpm: number = 0;
  private scenarioFallDone: boolean = false;
  private tickTimer: number = -1;
  private syncTimer: number = -1;
  private syncing: boolean = false;
  private batchSize: number = BATCH;
  private visible: boolean = false;
  private healthPermission: boolean = false;
  private motionPermission: boolean = false;
  private ready: Promise<void> = Promise.resolve();

  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
    this.cfg = AppConfig.load(ctx);
    this.sourceKind = this.cfg.defaultSource;
    this.genotype = this.cfg.genotype;
    this.base = {
      activeHigh: this.cfg.highBpm,
      restHigh: this.cfg.restHighBpm,
      sleepHigh: this.cfg.sleepHighBpm,
      awakeLow: this.cfg.lowBpm,
      sleepLow: this.cfg.sleepLowBpm
    };
    this.resting = new RestingHr(this.cfg.restingBpm);
    this.restingBpm = this.cfg.restingBpm;
    this.applyLimits();
    try {
      this.outbox = new MetricOutbox(new PreferencesOutboxStore(ctx), 500);
    } catch (e) {
      Logger.warn('preferences unavailable, outbox is in-memory only');
    }
    this.pending = this.outbox.size;
    if (AppConfig.canUpload(this.cfg)) {
      this.uploader = new SupabaseUploader(this.cfg.supabaseUrl, this.cfg.supabaseAnonKey);
      this.contextClient = new PatientContextClient(this.cfg.supabaseUrl, this.cfg.supabaseAnonKey,
        this.cfg.deviceId);
      this.syncState = this.pending > 0 ? 'PENDING' : 'OK';
    }
    this.syncTimer = setInterval(() => {
      this.syncNow();
    }, SYNC_EVERY_MS);
    this.monitoringSinceMs = Date.now();
    // Ask for permissions once, up front, so the dialog doesn't interrupt a running monitor.
    this.ready = this.requestPermissions();
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

  /** App became visible: (re)start monitoring and refresh the patient context. */
  async resume(): Promise<void> {
    this.visible = true;
    await this.ready;
    if (this.visible) {
      this.startSource();
      this.refreshContext();
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

  // ---- Simulate page -------------------------------------------------------------------------------------------

  cycleActivityOverride(): void {
    const order: ActivityOverride[] = ['AUTO', 'REST', 'ACTIVE', 'ASLEEP'];
    this.activityOverride = order[(order.indexOf(this.activityOverride) + 1) % order.length];
    this.activity = this.currentActivity(Date.now());
    this.applyLimits();
  }

  simulateFall(): void {
    this.startFall();
  }

  toggleWorn(): void {
    this.setWorn(!this.onWrist);
  }

  /** Demo stand-in for the phone app's drug scan: toggles a recent known-risk drug. */
  toggleRiskyDrug(): void {
    this.riskyDrug = this.riskyDrug.length > 0 ? '' : 'Clarithromycin';
    this.applyLimits();
  }

  cycleGenotype(): void {
    const order: Genotype[] = ['UNKNOWN', 'LQT1', 'LQT2', 'LQT3'];
    this.genotype = order[(order.indexOf(this.genotype) + 1) % order.length];
    this.applyLimits();
  }

  // ---- User responses ------------------------------------------------------------------------------------------

  dismissAlert(): void {
    this.alertText = '';
  }

  /** "I'm OK" during the fall countdown. */
  confirmOk(): void {
    if (this.fallCountdown > 0) {
      this.finishFall('ok');
    }
  }

  dismissEmergency(): void {
    this.emergencyText = '';
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
    const batch = this.outbox.peek(this.batchSize);
    const res = await this.uploader.upload(batch);
    if (res.ok) {
      this.outbox.ack(batch.length);
      this.batchSize = BATCH;
      this.syncState = this.outbox.size > 0 ? 'PENDING' : 'OK';
    } else if (res.status === 400) {
      // The server rejected a row (e.g. a type the DB doesn't know yet). Find it by sending one at a time and drop
      // only that row, so one bad row can't block the queue forever.
      if (this.batchSize > 1) {
        this.batchSize = 1;
      } else {
        Logger.error(`dropping row rejected by server: type=${batch[0].type}`);
        this.outbox.ack(1);
      }
      this.syncState = this.outbox.size > 0 ? 'PENDING' : 'OK';
    } else {
      this.syncState = 'ERROR';
      Logger.warn(`sync failed: ${res.message}`);
    }
    this.pending = this.outbox.size;
    this.syncing = false;
  }

  // ---- Monitoring loop -----------------------------------------------------------------------------------------

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
    const now = Date.now();
    this.alarm.reset();
    this.bpm = 0;
    this.irregularRhythm = false;
    this.lastLiveMs = 0;
    this.lastVitalsMs = now;
    this.lastMockMs = 0;
    this.lastSampleMs = now;
    this.windowStartMs = now;
    this.stillSinceMs = -1;
    this.window = new SessionStats();
    this.motion = new MotionAnalyzer();
    this.recovery = new RecoveryTracker();
    this.scenarioFallDone = false;
    this.running = true;
    this.source = this.createSource(this.sourceKind);
    this.source.start((bpm: number, tsMs: number) => {
      this.onSample(bpm, tsMs);
    }, (msg: string) => {
      this.onSourceError(msg);
    });
    const started = this.sensors.start((x: number, y: number, z: number, tsMs: number) => {
      this.onMotion(x, y, z, tsMs);
    }, (worn: boolean) => {
      this.setWorn(worn);
    }, (total: number) => {
      this.onSteps(total);
    }, this.motionPermission);
    this.tickTimer = setInterval(() => {
      this.onTick();
    }, 1000);
    this.motionAvailable = started.indexOf('motion') >= 0;
    Logger.info(`monitoring started, source=${this.sourceKind}, context=[${started.join(',')}]`);
  }

  private stopSource(): void {
    if (!this.running) {
      return;
    }
    this.source?.stop();
    this.source = undefined;
    this.simSource = undefined;
    this.sensors.stop();
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
    const sim = new SimulatedHeartRateSource(SCENARIOS[this.scenarioIdx].id);
    this.simSource = sim;
    return sim;
  }

  /** Sources only update the current reading; all processing runs once per second in onTick(). */
  private onSample(bpm: number, tsMs: number): void {
    this.bpm = bpm;
    this.lastSampleMs = tsMs;
    if (this.statusText === WAITING) {
      this.statusText = '';
    }
  }

  private onMotion(x: number, y: number, z: number, tsMs: number): void {
    if (this.motion.feed(x, y, z, tsMs)) {
      Logger.info('fall detected by accelerometer');
      this.startFall();
    }
  }

  /** The step counter reports a running total since boot; show steps since the app started. */
  private onSteps(total: number): void {
    if (this.sensorStepsBase < 0) {
      this.sensorStepsBase = total;
    }
    this.steps = this.simSteps + total - this.sensorStepsBase;
  }

  /** Priority: Simulate-page override → demo scenario → accelerometer (+ sleep detector). */
  private currentActivity(now: number): Activity {
    if (this.activityOverride !== 'AUTO') {
      return this.activityOverride;
    }
    if (this.simSource !== undefined) {
      return stateAt(SCENARIOS[this.scenarioIdx], this.simSource.elapsedSec);
    }
    const moving = this.motionAvailable ? this.motion.activityAt(now) : 'UNKNOWN';
    if (moving === 'REST') {
      if (this.stillSinceMs < 0) {
        this.stillSinceMs = now;
      }
      const asleep = isAsleep({
        onWrist: this.onWrist,
        stillSec: (now - this.stillSinceMs) / 1000,
        bpm: this.bpm,
        restingBpm: this.restingBpm,
        hour: new Date(now).getHours()
      });
      return asleep ? 'ASLEEP' : 'REST';
    }
    this.stillSinceMs = -1;
    return moving;
  }

  private applyLimits(): void {
    const l: HrLimits = limitsFor(this.activity, this.genotype, this.riskyDrug.length > 0, this.base);
    this.limitHigh = l.high;
    this.limitLow = l.low;
    this.limitReason = l.reason;
  }

  private onTick(): void {
    const now = Date.now();
    this.monitoringSec = Math.round((now - this.monitoringSinceMs) / 1000);
    this.activity = this.currentActivity(now);
    this.applyLimits();
    if (this.simSource !== undefined && this.activity === 'ACTIVE') {
      this.simSteps += SIM_STEPS_PER_SEC;
      this.steps += SIM_STEPS_PER_SEC;
    }
    if (now - this.windowStartMs >= SUMMARY_WINDOW_MS) {
      this.flushWindow(now);
    }
    if (now - this.lastContextMs >= CONTEXT_EVERY_MS) {
      this.refreshContext();
    }
    this.tickFall(now);
    this.tickScenarioFall();
    if (!this.onWrist) {
      this.bpm = 0;
      return;
    }
    if (this.bpm <= 0 || now - this.lastSampleMs > READING_VALID_MS) {
      if (this.sourceKind === 'SENSOR' && now - this.lastSampleMs > 8000) {
        this.statusText = WAITING;
        this.bpm = 0;
      }
      return;
    }
    this.processReading(now);
  }

  private processReading(now: number): void {
    this.window.add(this.bpm, now);
    this.resting.add(this.bpm, now, this.activity);
    this.restingBpm = this.resting.value;
    this.restingMeasured = this.resting.measured;
    if (now - this.lastMockMs >= MOCK_EVERY_MS) {
      this.lastMockMs = now;
      this.updateMockedVitals();
    }
    this.stress = isStressed(this.bpm, this.restingBpm, this.activity, this.hrvMs);
    if (now - this.lastLiveMs >= LIVE_EVERY_MS) {
      this.lastLiveMs = now;
      const live: HrLiveValues = { bpm: this.bpm, activity: this.activity };
      this.record('hr_live', live, now);
    }
    if (now - this.lastVitalsMs >= VITALS_EVERY_MS) {
      this.lastVitalsMs = now;
      this.record('vitals', this.vitalsSnapshot(), now);
    }
    const rec = this.recovery.add(this.bpm, now, this.activity);
    if (rec !== undefined) {
      this.onRecovery(rec, now);
    }
    const alert = this.alarm.evaluate(this.bpm, now,
      { high: this.limitHigh, low: this.limitLow, reason: this.limitReason }, this.activity);
    if (alert !== undefined) {
      this.raiseAlert(alert, now);
    }
  }

  /** Simulated HRV / SpO2 / breathing / rhythm (Huawei measures them; watch apps can't read them yet). */
  private updateMockedVitals(): void {
    const m = mockVitals(this.bpm, this.activity, Math.random);
    this.hrvMs = m.hrvMs;
    this.spo2 = m.spo2;
    this.breathingRate = m.breathingRate;
    if (m.irregularRhythm && !this.irregularRhythm) {
      const v: RhythmAlertValues = { bpm: this.bpm, activity: this.activity, mocked: true };
      this.record('rhythm_alert', v, Date.now());
      this.alertText = `Irregular rhythm at ${this.bpm} bpm (simulated signal). Sit down now.`;
      this.vibrate(1500);
      Logger.info('irregular rhythm (simulated)');
    }
    this.irregularRhythm = m.irregularRhythm;
  }

  private vitalsSnapshot(): VitalsValues {
    const v: VitalsValues = {
      bpm: this.bpm,
      restingBpm: this.restingBpm,
      activity: this.activity,
      stress: this.stress,
      steps: this.steps,
      hrvMs: this.hrvMs,
      spo2: this.spo2,
      breathingRate: this.breathingRate,
      irregularRhythm: this.irregularRhythm,
      highLimitBpm: this.limitHigh,
      lowLimitBpm: this.limitLow,
      genotype: this.genotype,
      riskyDrug: this.riskyDrug,
      mocked: MOCKED_FIELDS
    };
    return v;
  }

  private onRecovery(rec: HrRecoveryValues, now: number): void {
    this.record('hr_recovery', rec, now);
    this.lastRecovery = `${rec.peakBpm}→${rec.bpmAfter60s} (−${rec.dropBpm})${rec.slow ? ' slow' : ''}`;
    if (rec.slow) {
      this.alertText = `Slow heart-rate recovery: −${rec.dropBpm} bpm in 1 min. Rest and tell your doctor.`;
      this.vibrate(800);
    }
    Logger.info(`recovery: ${this.lastRecovery}`);
  }

  private tickScenarioFall(): void {
    const s = SCENARIOS[this.scenarioIdx];
    if (this.simSource !== undefined && !this.scenarioFallDone && s.fallAtSec >= 0 &&
      this.simSource.elapsedSec >= s.fallAtSec) {
      this.scenarioFallDone = true;
      this.startFall();
    }
  }

  private refreshContext(): void {
    this.lastContextMs = Date.now();
    if (this.contextClient === undefined) {
      return;
    }
    this.contextClient.fetch().then((c: PatientContext | undefined) => {
      if (c === undefined) {
        return;
      }
      this.genotype = c.genotype;
      this.riskyDrug = c.riskyDrug;
      this.applyLimits();
    });
  }

  // ---- Fall / faint ------------------------------------------------------------------------------------------

  private startFall(): void {
    if (this.fallCountdown > 0) {
      return;
    }
    this.alertText = '';
    this.emergencyText = '';
    this.fallBpm = this.bpm;
    this.fallStartMs = Date.now();
    this.fallCountdown = FALL_COUNTDOWN_SEC;
    this.vibrate(2000);
    Logger.info('fall countdown started');
  }

  private tickFall(now: number): void {
    if (this.fallCountdown <= 0) {
      return;
    }
    const left = FALL_COUNTDOWN_SEC - Math.floor((now - this.fallStartMs) / 1000);
    if (left <= 0) {
      this.finishFall('no_response');
    } else {
      this.fallCountdown = left;
      if (left % 5 === 0) {
        this.vibrate(600);
      }
    }
  }

  private finishFall(response: FallResponse): void {
    const v: FallValues = {
      bpm: this.fallBpm,
      response: response,
      responseSec: Math.round((Date.now() - this.fallStartMs) / 1000)
    };
    this.record('fall_detected', v, this.fallStartMs);
    this.fallCountdown = 0;
    if (response === 'no_response') {
      // The phone app / agent picks this row up and runs the emergency flow (ICE contacts, 112 prompt).
      this.emergencyText = 'No response. Emergency alert sent to your phone.';
      this.vibrate(3000);
    }
    Logger.info(`fall finished: ${response}`);
  }

  // ---- Wear state --------------------------------------------------------------------------------------------

  private setWorn(worn: boolean): void {
    if (worn === this.onWrist) {
      return;
    }
    this.onWrist = worn;
    this.alarm.reset();
    this.statusText = worn ? '' : NOT_WORN;
    const v: WearStateValues = { onWrist: worn };
    this.record('wear_state', v, Date.now());
    Logger.info(`wear state: ${worn ? 'on wrist' : 'off wrist'}`);
  }

  // ---- Helpers -----------------------------------------------------------------------------------------------

  /** Window summary as an `hr_session` row, then start a new window. */
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
    const kind = alert.direction === 'high' ? 'High' : 'Low';
    this.alertText = `${kind} heart rate ${alert.bpm} (${this.limitReason} limit ${alert.limitBpm})`;
    this.record('hr_alert', alert, tsMs);
    this.vibrate(1200);
    Logger.info(`alert: ${this.alertText}`);
  }

  private record(type: MetricType, payload: MetricPayload, tsMs: number): void {
    this.outbox.enqueue(makeRow(this.cfg.deviceId, type, payload, tsMs, sourceForKind(this.sourceKind)));
    this.pending = this.outbox.size;
    if (this.uploader !== undefined) {
      this.syncState = 'PENDING';
    }
  }

  private vibrate(durationMs: number): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: durationMs };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'alarm' };
    vibrator.startVibration(effect, attr).catch((err: BusinessError) => {
      Logger.warn(`vibrate failed: ${err.code}`);
    });
  }

  /** Heart rate + step counter in one dialog. Either may be denied; the app degrades per signal. */
  private async requestPermissions(): Promise<void> {
    if (this.ctx === undefined) {
      return;
    }
    const perms: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION'];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(this.ctx, perms);
      this.healthPermission = res.authResults.length > 0 && res.authResults[0] === 0;
      this.motionPermission = res.authResults.length > 1 && res.authResults[1] === 0;
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`permission request failed: ${err.code}`);
    }
  }
}
