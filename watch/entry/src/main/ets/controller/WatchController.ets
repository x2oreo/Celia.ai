import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConfig, AppConfigData } from '../common/AppConfig';
import { Logger } from '../common/Logger';
import { NOTIFY_FALL, NOTIFY_HR, NOTIFY_SOS, NOTIFY_VITALS, Notifier } from '../common/Notifier';
import {
  Activity,
  FallResponse,
  Genotype,
  HrSourceKind,
  MedicationTakenValues,
  MetricPayload,
  MetricType,
  SosReason,
  SosValues,
  SymptomKind,
  SymptomValues,
  VitalsValues,
  WearStateValues,
  makeRow,
  sourceForKind
} from '../model/WatchMetric';
import { BaseLimits, HrLimits, limitsFor } from '../vitals/Limits';
import { ANOMALY_RAMP_MS, Anomaly, MOCKED_FIELDS } from '../vitals/MockedVitals';
import { SCENARIOS, Scenario } from '../vitals/Scenarios';
import { stateWord } from '../vitals/WatchStatus';
import { HrBucket, HrTrend, TrendSummary } from '../vitals/HrTrend';
import { MetricOutbox } from '../sync/MetricOutbox';
import { PatientContext, PatientContextClient } from '../sync/PatientContextClient';
import { PreferencesOutboxStore } from '../sync/PreferencesOutboxStore';
import { DemoRpcClient } from '../sync/DemoRpcClient';
import { deviceIdFor, saveWatchSecret, watchSecretFor } from '../sync/DeviceIdStore';
import { PairingClient } from '../sync/PairingClient';
import { DoseStore } from '../sync/DoseStore';
import {
  DoseState,
  NUDGE_SNOOZE_MS,
  canSnooze,
  dayKey,
  doseTakenToday,
  emptyDoseState,
  forToday,
  shouldNudge
} from '../vitals/DoseNudge';
import { Fix, currentFix } from '../sync/SosLocation';
import { FallRecord, FallTick, SosFlow } from './SosFlow';
import { PairScreen, PairState, PairingFlow } from './PairingFlow';
import { OUTBOX_CAPACITY, SyncEngine, SyncState } from './SyncEngine';
import { AlertKind, HeartRules, Reading, RulesHost } from './HeartRules';
import { SensorHub } from './SensorHub';
import { SupabaseUploader } from '../sync/SupabaseUploader';
import { RestClient } from '../sync/RestClient';
import { symptomAfterDrugTitle } from '../vitals/DrugBadge';

/** Simulate-page override for the wearer's state. AUTO = motion sensor / scenario / sleep detector. */
export type ActivityOverride = 'AUTO' | 'REST' | 'ACTIVE' | 'ASLEEP';

/** Refresh rate of simulated vitals while a tapped anomaly ramps, so the drift looks smooth. */
const ANOMALY_FRAME_MS = 250;
/** While an alert / check-in is open, check this often whether the phone answered "I'm fine". */
const PHONE_ACK_POLL_MS = 3000;
const PHONE_ACK_SKEW_MS = 5000;
const SYNC_EVERY_MS = 3000;
const CONTEXT_EVERY_MS = 60000;
/**
 * Heart-rate sensors (and the emulator's virtual one) may report only when the value changes, so the last reading
 * stays valid this long; after that we show "waiting" and stop evaluating.
 */
const READING_VALID_MS = 30000;
/** Demo speeds offered in Settings. */
const DEMO_SPEEDS: number[] = [1, 2, 4, 8];
/** Simulated cadence while active in demo scenarios (steps per second). */
const SIM_STEPS_PER_SEC = 2;
const WAITING = 'Waiting for heart rate…';
const NOT_WORN = 'Watch not worn';

/**
 * The one object the screens read and call: screen state, the 1 s tick and the user's taps. The work is done by
 * SensorHub (sensors), HeartRules (per-reading rules), SosFlow (fall + SOS), SyncEngine (upload) and PairingFlow.
 * Monitoring is always on while the app is visible: the page calls resume() on show and pause() on hide.
 * (HarmonyOS freezes background apps and has no continuous-task type for heart-rate monitoring; on a real watch
 * 24/7 data comes from the system's own HR history via Health Service Kit. See watch/README.md.)
 */
@ObservedV2
export class WatchController implements RulesHost {
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
  @Trace steps: number = 0;
  @Trace alertKind: AlertKind = 'NONE';
  @Trace alertBpm: number = 0;
  @Trace alertActivity: Activity = 'UNKNOWN';
  /** Detail line for the alert screen (limit, recovery numbers). */
  @Trace alertText: string = '';
  /** "How do you feel?" screen. */
  @Trace checkInOpen: boolean = false;
  /** Drug-verdict glance: shown once when a new risky drug arrives. */
  @Trace verdictDrug: string = '';
  @Trace riskyDrugRisk: string = '';
  /** When the risky drug was taken (epoch ms); 0 if none or unknown. Drives the home badge's time left. */
  @Trace riskyDrugAt: number = 0;
  /** "Dizzy after Clarithromycin": a symptom within 24 h of a logged risky drug; '' when not shown. */
  @Trace drugWarning: string = '';
  /** Until when Home shows "Answered on phone" (epoch ms); 0 = not shown. */
  @Trace phoneAckUntil: number = 0;
  @Trace statusText: string = '';
  @Trace monitoringSec: number = 0;
  /** Fast-forward factor for demo scenarios (Settings). */
  @Trace demoSpeed: number = 4;
  /** DEMO_MODE: scripted heart-rate scenarios available in Settings. */
  @Trace demoMode: boolean = false;
  /** Demo: 16 simulated days of resting HR with the last 2 elevated (missed beta-blocker), on the server. */
  @Trace betaBlockerMissed: boolean = false;
  /** "Did you take nadolol?" glance (missed-dose nudge). */
  @Trace doseNudgeOpen: boolean = false;
  @Trace doseNudgeCanSnooze: boolean = true;
  /** When today's dose was logged (ms), 0 = not yet today. */
  @Trace doseTakenAt: number = 0;
  /** Simulator running line: the last event fired ("Fall") and when. */
  @Trace simEvent: string = '';
  @Trace simEventAt: number = 0;
  /** This watch's id (first 8 chars shown in Settings). */
  @Trace deviceId: string = '';
  @Trace deviceIdOverridden: boolean = false;
  /** Trend page: the last minutes of heart rate as range buckets (vitals/HrTrend). */
  @Trace trendSlots: HrBucket[] = [];
  @Trace trendSummary: TrendSummary = { min: 0, max: 0, avg: 0, filled: 0 };

  private ctx: common.UIAbilityContext | undefined = undefined;
  private cfg: AppConfigData = AppConfig.defaults();
  private base: BaseLimits = {
    activeHigh: 140,
    restHigh: 120,
    sleepHigh: 100,
    awakeLow: 45,
    sleepLow: 40
  };
  private hub: SensorHub = new SensorHub();
  private sync: SyncEngine = new SyncEngine();
  private contextClient: PatientContextClient | undefined = undefined;
  private demoRpc: DemoRpcClient | undefined = undefined;
  private pairing: PairingFlow = new PairingFlow();
  /** Last reading from the heart-rate source; `bpm` is this unless the simulator's heart-rate event is running. */
  private sensorBpm: number = 0;
  /** When the current heart-rate alert / check-in opened (0 = none open); a phone "I'm fine" after it closes it. */
  private popupSinceMs: number = 0;
  private lastAckPollMs: number = 0;
  private anomalyTimer: number = -1;
  private lastContextMs: number = 0;
  private lastSampleMs: number = 0;
  private monitoringSinceMs: number = 0;
  private scenarioFallDone: boolean = false;
  private sos: SosFlow = new SosFlow();
  private trend: HrTrend = new HrTrend();
  private rules: HeartRules = new HeartRules(this, Math.random);
  private tickTimer: number = -1;
  private syncTimer: number = -1;
  private visible: boolean = false;
  private healthPermission: boolean = false;
  private motionPermission: boolean = false;
  private locationPermission: boolean = false;
  private ready: Promise<void> = Promise.resolve();
  private notifier: Notifier = new Notifier();
  private doseStore: DoseStore | undefined = undefined;
  private dose: DoseState = emptyDoseState();

  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
    this.cfg = AppConfig.load(ctx);
    this.deviceIdOverridden = this.cfg.deviceId.length >= 3;
    this.cfg.deviceId = deviceIdFor(ctx, this.cfg.deviceId);
    this.deviceId = this.cfg.deviceId;
    this.demoMode = this.cfg.demoMode;
    this.sourceKind = this.demoMode ? this.cfg.defaultSource : 'SENSOR';
    this.demoSpeed = this.cfg.demoSpeed;
    this.scenarioIdx = Math.max(0, SCENARIOS.findIndex((s: Scenario) => s.id === this.cfg.defaultScenario));
    this.genotype = this.cfg.genotype;
    this.base = {
      activeHigh: this.cfg.highBpm,
      restHigh: this.cfg.restHighBpm,
      sleepHigh: this.cfg.sleepHighBpm,
      awakeLow: this.cfg.lowBpm,
      sleepLow: this.cfg.sleepLowBpm
    };
    this.rules.configure(this.cfg.alertSustainSec, this.cfg.restingBpm);
    this.applyLimits();
    let outbox: MetricOutbox | undefined = undefined;
    try {
      outbox = new MetricOutbox(new PreferencesOutboxStore(ctx), OUTBOX_CAPACITY);
    } catch (e) {
      Logger.warn('preferences unavailable, outbox is in-memory only');
    }
    this.doseStore = new DoseStore(ctx);
    this.dose = this.doseStore.load();
    this.doseTakenAt = doseTakenToday(this.dose, Date.now());
    if (AppConfig.canUpload(this.cfg)) {
      // One HTTP session for every Supabase call (energy: shared connections, fewer TLS handshakes).
      const client = new RestClient(this.cfg.supabaseUrl, this.cfg.supabaseAnonKey);
      client.setWatchSecret(watchSecretFor(ctx));   // B9: proves this watch to the server once it has paired
      this.sync.configure(outbox, new SupabaseUploader(client));
      this.contextClient = new PatientContextClient(client, this.cfg.deviceId);
      this.demoRpc = new DemoRpcClient(client);
      this.pairing.configure(new PairingClient(client, (secret: string) => saveWatchSecret(ctx, secret)), () => {
        this.vibrate(400);
      });
    } else {
      this.sync.configure(outbox, undefined);
    }
    this.monitoringSinceMs = Date.now();
    // Ask for permissions once, up front, so the dialog doesn't interrupt a running monitor.
    this.ready = this.requestPermissions().then(() => this.notifier.init(ctx)).then(() => {
      this.notifier.scheduleDailyMedication(this.cfg.medReminderTime, this.cfg.medicationName);
    });
  }

  dispose(): void {
    this.pause();
    this.pairing.stopPolling();
  }

  /** Seconds left to answer "Are you OK?"; 0 = no fall in progress. */
  get fallCountdown(): number {
    return this.sos.fallCountdown;
  }

  get sosCountdown(): number {
    return this.sos.sosCountdown;
  }

  get sosSent(): boolean {
    return this.sos.sosSent;
  }

  /** True once the `sos` row reached the server. Until then the screen says saved, not sent. */
  get sosDelivered(): boolean {
    return this.sos.sosDelivered;
  }

  get pairState(): PairState {
    return this.pairing.pairState;
  }

  get pairingOpen(): boolean {
    return this.pairing.pairingOpen;
  }

  get pairScreen(): PairScreen {
    return this.pairing.pairScreen;
  }

  get pairCode(): string {
    return this.pairing.pairCode;
  }

  get pairSecondsLeft(): number {
    return this.pairing.pairSecondsLeft;
  }

  get pairTotalSeconds(): number {
    return this.pairing.pairTotalSeconds;
  }

  get pairError(): string {
    return this.pairing.pairError;
  }

  get syncState(): SyncState {
    return this.sync.syncState;
  }

  get pending(): number {
    return this.sync.pending;
  }

  get restingBpm(): number {
    return this.rules.restingBpm;
  }

  get restingMeasured(): boolean {
    return this.rules.restingMeasured;
  }

  get stress(): boolean {
    return this.rules.stress;
  }

  get hrvMs(): number {
    return this.rules.hrvMs;
  }

  get spo2(): number {
    return this.rules.spo2;
  }

  get breathingRate(): number {
    return this.rules.breathingRate;
  }

  get irregularRhythm(): boolean {
    return this.rules.irregularRhythm;
  }

  get lastRecovery(): string {
    return this.rules.lastRecovery;
  }

  get recoveryDrop(): number {
    return this.rules.recoveryDrop;
  }

  get recoverySlow(): boolean {
    return this.rules.recoverySlow;
  }

  /** Signal currently forced abnormal from the Simulator page. */
  get anomaly(): Anomaly {
    return this.rules.anomaly;
  }

  get scenarioLabel(): string {
    return SCENARIOS[this.scenarioIdx].label;
  }

  get medicationName(): string {
    return this.cfg.medicationName;
  }

  /** Daily reminder "HH:MM", '' when off. */
  get medReminderTime(): string {
    return this.cfg.medReminderTime;
  }

  /** App became visible: (re)start monitoring and refresh the patient context. */
  async resume(): Promise<void> {
    this.visible = true;
    await this.ready;
    if (this.visible) {
      this.startSource();
      this.refreshContext();
      if (this.syncTimer < 0) {
        this.syncTimer = setInterval(() => {
          this.syncNow();
        }, SYNC_EVERY_MS);
      }
    }
  }

  /** App hidden: the OS will freeze us, so close the summary window and push what we have. */
  pause(): void {
    this.visible = false;
    this.closePairing();
    this.stopSource();
    // No upload timer while hidden: nothing new is recorded, so it would only wake the radio.
    if (this.syncTimer >= 0) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
    }
    this.flushWindow(Date.now());
    this.syncNow();
  }

  /** Toggles watch sensor ↔ demo data. */
  cycleSource(): void {
    if (!this.demoMode) {
      return;
    }
    this.sourceKind = this.sourceKind === 'SENSOR' ? 'SIMULATED' : 'SENSOR';
    this.restart();
  }

  /**
   * Simulator page: an event makes that simulated signal drift abnormal (2.5 s, refreshed every 250 ms), hold, and
   * recover. The alert fires through the threshold rule with a 1 s demo sustain, ~3 s after the tap.
   */
  triggerAnomaly(kind: Anomaly): void {
    this.markSimEvent(kind === 'rhythm' ? 'Irregular rhythm' : kind === 'hrv' ? 'Low HRV' :
      kind === 'hr' ? 'High heart rate' : 'Low oxygen');
    this.rules.startAnomaly(kind, Date.now());
    Logger.info(`anomaly: ${kind}`);
    if (this.anomalyTimer >= 0) {
      clearInterval(this.anomalyTimer);
    }
    this.anomalyTimer = setInterval(() => {
      if (this.running && this.onWrist && this.bpm > 0) {
        if (this.anomaly === 'hr') {
          this.bpm = this.withHrAnomaly(this.sensorBpm, Date.now());
        }
        this.rules.updateMockedVitals(this.bpm, this.activity, Date.now());
      }
      // Frames only during the ramp (+ sustain); the 1 s tick takes over afterwards.
      if (!this.rules.anomalyRamping(Date.now(), ANOMALY_RAMP_MS)) {
        clearInterval(this.anomalyTimer);
        this.anomalyTimer = -1;
      }
    }, ANOMALY_FRAME_MS);
  }

  cycleDemoSpeed(): void {
    const idx = DEMO_SPEEDS.indexOf(this.demoSpeed);
    this.demoSpeed = DEMO_SPEEDS[(idx + 1) % DEMO_SPEEDS.length];
    if (this.sourceKind === 'SIMULATED') {
      this.restart();
    }
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

  /** Demo: system reminder for the medication in 10 s (try closing the app first). */
  async testMedicationReminder(): Promise<boolean> {
    return this.notifier.testReminder(10, this.cfg.medicationName);
  }

  /** Demo: toggles the server-side "missed beta-blocker" resting-HR history. Label flips only on success. */
  async toggleMissedBetaBlocker(): Promise<boolean> {
    if (this.demoRpc === undefined) {
      Logger.warn('missed beta-blocker sim needs Supabase settings in watch/.env');
      return false;
    }
    const next = !this.betaBlockerMissed;
    const ok = await this.demoRpc.simulateMissedBetaBlocker(this.cfg.deviceId, next);
    if (ok) {
      this.betaBlockerMissed = next;
    }
    return ok;
  }

  simulateFall(): void {
    this.markSimEvent('Fall');
    this.startFall();
  }

  toggleWorn(): void {
    this.markSimEvent(this.onWrist ? 'Watch off' : 'Watch on');
    this.setWorn(!this.onWrist);
  }

  /** Demo stand-in for the phone app's drug scan: toggles a recent known-risk drug. */
  toggleRiskyDrug(): void {
    if (this.riskyDrug.length > 0) {
      this.setRiskyDrug('', '', 0);
    } else {
      this.setRiskyDrug('Clarithromycin', 'KNOWN_RISK', Date.now());
    }
  }

  cycleGenotype(): void {
    const order: Genotype[] = ['UNKNOWN', 'LQT1', 'LQT2', 'LQT3'];
    this.genotype = order[(order.indexOf(this.genotype) + 1) % order.length];
    this.applyLimits();
  }

  // Direct setters for the simulator's chip groups (the cycle* methods above step through the same values).

  setSource(kind: HrSourceKind): void {
    if (this.demoMode && kind !== this.sourceKind) {
      this.cycleSource();
    }
  }

  setScenario(idx: number): void {
    if (idx < 0 || idx >= SCENARIOS.length || idx === this.scenarioIdx) {
      return;
    }
    this.scenarioIdx = idx;
    if (this.sourceKind === 'SIMULATED') {
      this.restart();
    }
  }

  setDemoSpeed(speed: number): void {
    if (DEMO_SPEEDS.indexOf(speed) < 0 || speed === this.demoSpeed) {
      return;
    }
    this.demoSpeed = speed;
    if (this.sourceKind === 'SIMULATED') {
      this.restart();
    }
  }

  setActivityOverride(o: ActivityOverride): void {
    this.activityOverride = o;
    this.activity = this.currentActivity(Date.now());
    this.applyLimits();
  }

  setGenotype(g: Genotype): void {
    this.genotype = g;
    this.applyLimits();
  }

  setRiskyDrugOn(on: boolean): void {
    if (on !== this.riskyDrug.length > 0) {
      this.toggleRiskyDrug();
    }
  }

  async setBetaBlockerMissed(missed: boolean): Promise<boolean> {
    return missed === this.betaBlockerMissed ? true : this.toggleMissedBetaBlocker();
  }

  /** Simulator: one event, shown once in the running line. */
  private markSimEvent(label: string): void {
    this.simEvent = label;
    this.simEventAt = Date.now();
  }

  // ---- User responses ------------------------------------------------------------------------------------------

  /** "I'm OK" on an alert or fall screen: close it and ask how they feel. */
  imOk(): void {
    if (this.fallCountdown > 0) {
      this.finishFall('ok');
    }
    this.alertKind = 'NONE';
    this.checkInOpen = true;
  }

  /** "Need help" on an alert or fall screen: start the SOS countdown. */
  needHelp(): void {
    if (this.fallCountdown > 0) {
      this.finishFall('need_help');
      this.startSos('fall');
    } else {
      this.startSos('need_help');
    }
    this.alertKind = 'NONE';
  }

  checkIn(kind: SymptomKind): void {
    this.logSymptom(kind);
    this.checkInOpen = false;
  }

  dismissDrugWarning(): void {
    this.drugWarning = '';
  }

  closeCheckIn(): void {
    this.checkInOpen = false;
  }

  cancelSos(): void {
    this.sos.cancelSos();
    Logger.info('SOS cancelled');
  }

  dismissSosSent(): void {
    this.sos.dismissSent();
  }

  dismissVerdict(): void {
    this.verdictDrug = '';
  }

  logSymptom(kind: SymptomKind): void {
    const v: SymptomValues = { kind: kind, bpm: this.bpm };
    this.record('symptom', v, Date.now());
    // Same rule the phone and watch_insights use: a symptom within 24 h of a QT-risk drug the user took.
    const warning = symptomAfterDrugTitle(kind, this.riskyDrug, this.riskyDrugAt, Date.now());
    if (warning.length > 0) {
      this.drugWarning = warning;
      this.vibrate(800);
      Logger.info(`drug warning: ${warning}`);
    }
  }

  logMedication(): void {
    const now = Date.now();
    const v: MedicationTakenValues = { name: this.cfg.medicationName };
    this.record('medication_taken', v, now);
    this.dose = forToday(this.dose, now);
    this.dose.lastDoseDay = dayKey(now);
    this.dose.lastDoseMs = now;
    this.doseTakenAt = now;
    this.saveDose();
    this.doseNudgeOpen = false;
  }

  /** Dose nudge: "Took it" logs the dose like the Check-in page button. */
  doseTaken(): void {
    this.logMedication();
  }

  /** Dose nudge: "Not yet" snoozes 30 min (the nudge shows at most 3 times a day: first + 2 snoozes). */
  doseNotYet(): void {
    this.dose.snoozeUntilMs = Date.now() + NUDGE_SNOOZE_MS;
    this.saveDose();
    this.doseNudgeOpen = false;
  }

  // ---- Pairing with a phone ----------------------------------------------------------------------------------

  /** Settings opened: one pairing_status call → "Paired with phone" / "Not paired". */
  async refreshPairState(): Promise<void> {
    await this.pairing.refresh(this.deviceId);
  }

  /** "Pair with phone" / "New code": asks the server for a 6-digit code. Returns '' or an error for a toast. */
  async startPairing(): Promise<string> {
    return this.pairing.start(this.deviceId);
  }

  /** Leaving the pairing screen stops polling. */
  closePairing(): void {
    this.pairing.close();
  }

  /** Simulate page: show the nudge now, without touching today's counters. */
  showDoseNudgeNow(): void {
    this.doseNudgeCanSnooze = true;
    this.doseNudgeOpen = true;
    this.vibrate(600);
  }

  async syncNow(): Promise<void> {
    if (await this.sync.syncNow()) {
      this.confirmSosDelivery();
    }
  }

  // ---- Monitoring loop -----------------------------------------------------------------------------------------

  private restart(): void {
    this.statusText = '';
    // A new source or scenario is a new story: the trend page starts empty instead of mixing the two.
    this.trend.clear();
    this.trendSlots = [];
    this.trendSummary = { min: 0, max: 0, avg: 0, filled: 0 };
    if (this.running) {
      this.stopSource();
      this.startSource();
    }
  }

  private startSource(): void {
    if (this.running) {
      return;
    }
    // Without DEMO_MODE the watch never switches to scripted data: it shows why there is no reading instead.
    if (this.sourceKind === 'SENSOR' && !this.sensorUsable() && this.demoMode) {
      this.sourceKind = 'SIMULATED';
    }
    const now = Date.now();
    this.rules.start(now);
    this.bpm = 0;
    this.lastSampleMs = now;
    this.scenarioFallDone = false;
    this.running = true;
    const started = this.hub.start(this.sourceKind, this.scenarioIdx, this.demoSpeed, this.motionPermission,
      (bpm: number, tsMs: number) => {
        this.onSample(bpm, tsMs);
      }, (msg: string) => {
        this.onSourceError(msg);
      }, () => {
        Logger.info('fall detected by accelerometer');
        this.startFall();
      }, (worn: boolean) => {
        this.setWorn(worn);
      }, (steps: number) => {
        this.steps = steps;
      });
    this.tickTimer = setInterval(() => {
      this.onTick();
    }, 1000);
    Logger.info(`monitoring started, source=${this.sourceKind}, context=[${started.join(',')}]`);
  }

  private stopSource(): void {
    if (!this.running) {
      return;
    }
    this.hub.stop();
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
    if (!SensorHub.heartRateSensorPresent()) {
      this.statusText = 'No heart-rate sensor, demo data';
      return false;
    }
    return true;
  }

  /** Sources only update the current reading; all processing runs once per second in onTick(). */
  private onSample(bpm: number, tsMs: number): void {
    this.sensorBpm = bpm;
    this.bpm = this.withHrAnomaly(bpm, Date.now());
    this.lastSampleMs = tsMs;
    if (this.statusText === WAITING) {
      this.statusText = '';
    }
  }

  /** Priority: Simulate-page override → demo scenario → accelerometer (+ sleep detector). */
  private currentActivity(now: number): Activity {
    if (this.activityOverride !== 'AUTO') {
      return this.activityOverride;
    }
    return this.hub.activity({
      nowMs: now,
      onWrist: this.onWrist,
      bpm: this.bpm,
      restingBpm: this.restingBpm
    });
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
    this.hub.adaptAccelRate(this.activity, now);
    if (this.hub.simulated && this.activity === 'ACTIVE') {
      this.steps += this.hub.addSimSteps(SIM_STEPS_PER_SEC);
    }
    if (this.rules.windowDue(now)) {
      this.flushWindow(now);
    }
    if (now - this.lastContextMs >= CONTEXT_EVERY_MS) {
      this.refreshContext();
    }
    this.tickFall(now);
    this.tickSos(now);
    this.tickPhoneAck(now);
    if (this.phoneAckUntil > 0 && now >= this.phoneAckUntil) {
      this.phoneAckUntil = 0;
    }
    this.tickDoseNudge(now);
    this.tickScenarioFall();
    if (!this.onWrist) {
      this.bpm = 0;
      return;
    }
    if (this.anomaly === 'hr' && this.sensorBpm > 0) {
      this.bpm = this.withHrAnomaly(this.sensorBpm, now);
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

  /**
   * "I'm fine" answered on the phone closes a heart-rate alert or the check-in here too. Polls every 3 s only while
   * one is open. Falls and the SOS countdown are never closed from the phone: those must be answered on the wrist.
   */
  private tickPhoneAck(now: number): void {
    const open = (this.alertKind !== 'NONE' && this.fallCountdown <= 0 && this.sosCountdown <= 0) || this.checkInOpen;
    if (!open) {
      this.popupSinceMs = 0;
      return;
    }
    if (this.popupSinceMs === 0) {
      this.popupSinceMs = now;
    }
    if (this.contextClient === undefined || now - this.lastAckPollMs < PHONE_ACK_POLL_MS) {
      return;
    }
    this.lastAckPollMs = now;
    const since = this.popupSinceMs;
    this.contextClient.fetchAlertAck().then((ackAt: number | undefined) => {
      // Small allowance for clock skew; an answer to an older alert never closes a newer one.
      if (ackAt === undefined || ackAt < since - PHONE_ACK_SKEW_MS || this.popupSinceMs !== since) {
        return;
      }
      this.alertKind = 'NONE';
      this.checkInOpen = false;
      this.popupSinceMs = 0;
      this.phoneAckUntil = Date.now() + 5000;
      this.vibrate(200);
      Logger.info('alert answered on the phone');
    });
  }

  /** Simulator "High heart rate": the sensor reading, or the drifting demo value while that event runs. */
  private withHrAnomaly(sensor: number, now: number): number {
    return this.rules.hrWithAnomaly(sensor, this.limitHigh, now);
  }

  private processReading(now: number): void {
    const r: Reading = {
      nowMs: now,
      logicMs: this.hub.logicNow(now),
      bpm: this.bpm,
      activity: this.activity,
      limits: { high: this.limitHigh, low: this.limitLow, reason: this.limitReason },
      riskyDrug: this.riskyDrug
    };
    this.rules.process(r);
    this.trend.add(this.bpm, r.logicMs);
    this.trendSlots = this.trend.slots();
    this.trendSummary = this.trend.summary();
  }

  /** RulesHost: the `vitals` row, every input in one snapshot. */
  vitalsSnapshot(): VitalsValues {
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

  private tickScenarioFall(): void {
    const s = SCENARIOS[this.scenarioIdx];
    if (this.hub.simulated && !this.scenarioFallDone && s.fallAtSec >= 0 && this.hub.scenarioSec >= s.fallAtSec) {
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
      this.setRiskyDrug(c.riskyDrug, c.riskyDrugRisk, c.riskyDrugAt);
    });
  }

  // ---- Fall / faint ------------------------------------------------------------------------------------------

  private startFall(): void {
    if (!this.sos.startFall(this.bpm, Date.now())) {
      return;
    }
    this.alertKind = 'NONE';
    this.checkInOpen = false;
    this.notifier.alert(NOTIFY_FALL, '▲ Fall detected', 'Are you OK? Answer within 30 s, or an SOS is sent.');
    this.vibrate(2000);
    Logger.info('fall countdown started');
  }

  private tickFall(now: number): void {
    const t: FallTick = this.sos.tickFall(now);
    if (t === 'TIMED_OUT') {
      this.finishFall('no_response');
      this.startSos('fall');
      this.notifier.alert(NOTIFY_FALL, '▲ Fall detected', 'No answer. Sending an SOS.');
    } else if (t === 'VIBRATE') {
      this.vibrate(600);
    }
  }

  private finishFall(response: FallResponse): void {
    const r: FallRecord = this.sos.finishFall(response, Date.now());
    this.record('fall_detected', r.values, r.atMs);
    Logger.info(`fall finished: ${response}`);
  }

  // ---- Missed-dose nudge -------------------------------------------------------------------------------------

  private tickDoseNudge(now: number): void {
    // Never over an alert, fall or SOS screen, and not while the check-in is open; try again next tick.
    if (this.doseNudgeOpen || this.alertKind !== 'NONE' || this.fallCountdown > 0 || this.sosCountdown > 0 ||
      this.sosSent || this.checkInOpen) {
      return;
    }
    if (!shouldNudge(this.dose, now, this.cfg.medReminderTime)) {
      return;
    }
    this.dose = forToday(this.dose, now);
    this.dose.timesShown += 1;
    this.doseNudgeCanSnooze = canSnooze(this.dose);
    this.saveDose();
    this.doseNudgeOpen = true;
    this.vibrate(600);
    Logger.info(`dose nudge shown (${this.dose.timesShown}/3)`);
  }

  private saveDose(): void {
    this.doseStore?.save(this.dose);
  }

  // ---- SOS -----------------------------------------------------------------------------------------------------

  private startSos(reason: SosReason): void {
    if (!this.sos.startSos(reason, Date.now())) {
      return;
    }
    if (this.locationPermission) {
      currentFix().then((f: Fix | undefined) => {
        this.sos.setFix(f);
        Logger.info(f !== undefined ? `SOS location fix, accuracy ${f.accuracyM} m` : 'SOS without location');
      });
    }
    this.vibrate(1000);
    Logger.info(`SOS countdown started: ${reason}`);
  }

  private tickSos(now: number): void {
    // The phone app / agent picks the row up and runs the emergency flow (ICE contacts, 112 prompt).
    const v: SosValues | undefined = this.sos.tickSos(now, this.bpm, this.activity);
    if (v === undefined) {
      return;
    }
    this.record('sos', v, now);
    this.vibrate(3000);
    Logger.info('SOS queued');
    this.syncNow();
  }

  // Runs after each successful upload.
  private confirmSosDelivery(): void {
    if (!this.sos.confirmDelivery(this.sync.has('sos'))) {
      return;
    }
    this.notifier.alert(NOTIFY_SOS, '✓ SOS sent', 'Your phone is alerting your contacts.');
    Logger.info('SOS delivered');
  }

  // ---- Alerts & drug verdict -----------------------------------------------------------------------------------

  /** RulesHost: show an alert screen (and its notification). */
  showAlert(kind: AlertKind, bpm: number, detail: string): void {
    // Never cover an active fall or SOS flow with a heart-rate alert.
    if (this.fallCountdown > 0 || this.sosCountdown > 0) {
      return;
    }
    this.alertKind = kind;
    this.alertBpm = bpm;
    this.alertActivity = this.activity;
    this.alertText = detail;
    this.checkInOpen = false;
    this.notifyAlert(kind, bpm);
  }

  /**
   * Mirrors an alert screen as a watch notification, so it stays in the list after the screen is dismissed. Copy
   * pattern (DESIGN.md §7): shape + title, then value + state + limit; simulated signals say SIM.
   */
  private notifyAlert(kind: AlertKind, value: number): void {
    const state = stateWord(this.activity).toLowerCase();
    const at = state.length > 0 ? ` ${state}` : '';
    switch (kind) {
      case 'HIGH':
        this.notifier.alert(NOTIFY_HR, '▲ Heart rate high',
          `${value} bpm${at}. Limit ${this.limitHigh}. Tap to open.`);
        break;
      case 'LOW':
        this.notifier.alert(NOTIFY_HR, '▼ Heart rate low', `${value} bpm${at}. Limit ${this.limitLow}. Tap to open.`);
        break;
      case 'RHYTHM':
        this.notifier.alert(NOTIFY_HR, '▲ Irregular rhythm', `SIM${at.length > 0 ? ` ·${at}` : ''}. Sit down now.`);
        break;
      case 'RECOVERY':
        this.notifier.alert(NOTIFY_HR, '▲ Slow recovery', `-${this.recoveryDrop} bpm in 1 min. Take it easy.`);
        break;
      case 'HRV':
        this.notifier.alert(NOTIFY_VITALS, '▲ Low HRV', `${value} ms · SIM. Rest for a few minutes.`);
        break;
      case 'SPO2':
        this.notifier.alert(NOTIFY_VITALS, '▲ Low oxygen', `${value}% · SIM. Sit up and breathe deeply.`);
        break;
      default:
        break;
    }
  }

  /** New risky drug from the phone (or Simulate) → limits change and the verdict glance pops up once. */
  private setRiskyDrug(name: string, risk: string, takenAtMs: number): void {
    if (name.length > 0 && name !== this.riskyDrug) {
      this.verdictDrug = name;
    }
    this.riskyDrug = name;
    this.riskyDrugRisk = risk;
    this.riskyDrugAt = name.length > 0 ? takenAtMs : 0;
    this.applyLimits();
  }

  // ---- Wear state --------------------------------------------------------------------------------------------

  private setWorn(worn: boolean): void {
    if (worn === this.onWrist) {
      return;
    }
    this.onWrist = worn;
    this.rules.resetAlarm();
    this.statusText = worn ? '' : NOT_WORN;
    const v: WearStateValues = { onWrist: worn };
    this.record('wear_state', v, Date.now());
    Logger.info(`wear state: ${worn ? 'on wrist' : 'off wrist'}`);
  }

  // ---- Helpers -----------------------------------------------------------------------------------------------

  /** Window summary as an `hr_session` row, then start a new window. */
  private flushWindow(nowMs: number): void {
    this.rules.flushWindow(nowMs);
  }

  private onSourceError(msg: string): void {
    this.statusText = msg;
    if (this.sourceKind === 'SENSOR' && this.demoMode) {
      // Sensor failed at runtime: keep monitoring on scripted data, clearly labelled.
      this.stopSource();
      this.sourceKind = 'SIMULATED';
      this.statusText = 'Sensor failed, demo data';
      this.startSource();
    }
  }

  /** RulesHost: queue a row for upload. */
  record(type: MetricType, payload: MetricPayload, tsMs: number): void {
    // A demo heart-rate drift must never be stored as a real reading.
    const source = this.anomaly === 'hr' ? 'simulated' : sourceForKind(this.sourceKind);
    this.sync.record(makeRow(this.cfg.deviceId, type, payload, tsMs, source));
  }

  /** RulesHost: vibrate with the alarm usage. */
  vibrate(durationMs: number): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: durationMs };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'alarm' };
    vibrator.startVibration(effect, attr).catch((err: BusinessError) => {
      Logger.warn(`vibrate failed: ${err.code}`);
    });
  }

  /** Heart rate, steps and SOS location in one flow. Each may be denied; the app degrades per signal. */
  private async requestPermissions(): Promise<void> {
    if (this.ctx === undefined) {
      return;
    }
    // Location is only used for SOS rows. LOCATION must be requested together with APPROXIMATELY_LOCATION.
    const perms: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION',
      'ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(this.ctx, perms);
      this.healthPermission = res.authResults.length > 0 && res.authResults[0] === 0;
      this.motionPermission = res.authResults.length > 1 && res.authResults[1] === 0;
      this.locationPermission = res.authResults.length > 2 && res.authResults[2] === 0;
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`permission request failed: ${err.code}`);
    }
  }
}
