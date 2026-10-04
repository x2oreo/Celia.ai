import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Genotype, HrSourceKind } from '../model/WatchMetric';
import { Logger } from './Logger';

/**
 * Runtime config, read from `resources/rawfile/config.json` (git-ignored).
 * Generated from watch/.env at build time (see entry/hvigorfile.ts). Without it the app still runs: metrics stay in
 * the on-watch outbox and nothing is uploaded.
 */
export interface AppConfigData {
  supabaseUrl: string;
  /** Supabase anon key. Public by design; RLS limits it to inserting/reading watch_metrics. */
  supabaseAnonKey: string;
  /** Override for the watch id (watch/.env WATCH_DEVICE_ID). Empty = generated per-watch id + pairing. */
  deviceId: string;
  defaultSource: HrSourceKind;
  medicationName: string;
  /** High limit while active. */
  highBpm: number;
  /** Stricter high limit while at rest. */
  restHighBpm: number;
  sleepHighBpm: number;
  lowBpm: number;
  sleepLowBpm: number;
  /** Used until the phone app has written a genotype to watch_context. */
  genotype: Genotype;
  /** Resting-HR estimate until the watch has measured a resting minute. */
  restingBpm: number;
  /** Fast-forward factor for demo scenarios. */
  demoSpeed: number;
  /** Scenario id selected at start (vitals/Scenarios.ets), e.g. 'tour' or 'rest'. */
  defaultScenario: string;
  /** HR must stay out of range this long before the alert screen. */
  alertSustainSec: number;
  /** Daily medication reminder "HH:MM"; empty = off. */
  medReminderTime: string;
  /** Scripted demo heart rate (Settings: source, scenarios, speed). Off = real sensor only. */
  demoMode: boolean;
}

export class AppConfig {
  static defaults(): AppConfigData {
    const cfg: AppConfigData = {
      supabaseUrl: '',
      supabaseAnonKey: '',
      deviceId: '',
      defaultSource: 'SENSOR',
      medicationName: 'nadolol',
      highBpm: 140,
      restHighBpm: 120,
      sleepHighBpm: 100,
      lowBpm: 45,
      sleepLowBpm: 40,
      genotype: 'UNKNOWN',
      restingBpm: 65,
      demoSpeed: 4,
      defaultScenario: 'tour',
      alertSustainSec: 5,
      medReminderTime: '08:00',
      demoMode: false
    };
    return cfg;
  }

  static load(ctx: common.Context): AppConfigData {
    const cfg = AppConfig.defaults();
    try {
      const bytes = ctx.resourceManager.getRawFileContentSync('config.json');
      const text = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const loaded = JSON.parse(text) as AppConfigData;
      AppConfig.merge(cfg, loaded);
      Logger.info(`config loaded, upload ${AppConfig.canUpload(cfg) ? 'enabled' : 'disabled'}`);
    } catch (e) {
      Logger.warn('rawfile/config.json missing or invalid, using defaults (upload disabled)');
    }
    return cfg;
  }

  static canUpload(cfg: AppConfigData): boolean {
    return cfg.supabaseUrl.startsWith('https://') && cfg.supabaseAnonKey.length > 20;
  }

  /** Copies only well-typed fields, so a broken config.json can't put bad values in. */
  private static merge(target: AppConfigData, src: AppConfigData): void {
    if (typeof src.supabaseUrl === 'string') {
      target.supabaseUrl = src.supabaseUrl.replace(new RegExp('/+$'), '');
    }
    if (typeof src.supabaseAnonKey === 'string') {
      target.supabaseAnonKey = src.supabaseAnonKey;
    }
    // Empty = use this watch's generated id (DeviceIdStore) and pair with a phone.
    if (typeof src.deviceId === 'string' && (src.deviceId.length === 0 || src.deviceId.length >= 3)) {
      target.deviceId = src.deviceId;
    }
    if (src.defaultSource === 'SENSOR' || src.defaultSource === 'SIMULATED') {
      target.defaultSource = src.defaultSource;
    }
    if (typeof src.medicationName === 'string' && src.medicationName.length > 0) {
      target.medicationName = src.medicationName;
    }
    if (typeof src.highBpm === 'number' && src.highBpm > 60 && src.highBpm < 250) {
      target.highBpm = src.highBpm;
    }
    if (typeof src.restHighBpm === 'number' && src.restHighBpm > 60 && src.restHighBpm < 250) {
      target.restHighBpm = src.restHighBpm;
    }
    if (typeof src.sleepHighBpm === 'number' && src.sleepHighBpm > 50 && src.sleepHighBpm < 200) {
      target.sleepHighBpm = src.sleepHighBpm;
    }
    if (typeof src.sleepLowBpm === 'number' && src.sleepLowBpm > 20 && src.sleepLowBpm < 80) {
      target.sleepLowBpm = src.sleepLowBpm;
    }
    if (src.genotype === 'LQT1' || src.genotype === 'LQT2' || src.genotype === 'LQT3') {
      target.genotype = src.genotype;
    }
    if (typeof src.restingBpm === 'number' && src.restingBpm > 30 && src.restingBpm < 120) {
      target.restingBpm = src.restingBpm;
    }
    if (src.demoSpeed === 1 || src.demoSpeed === 2 || src.demoSpeed === 4 || src.demoSpeed === 8) {
      target.demoSpeed = src.demoSpeed;
    }
    if (typeof src.defaultScenario === 'string' && src.defaultScenario.length > 0) {
      target.defaultScenario = src.defaultScenario;
    }
    if (typeof src.alertSustainSec === 'number' && src.alertSustainSec >= 1 && src.alertSustainSec <= 60) {
      target.alertSustainSec = src.alertSustainSec;
    }
    if (typeof src.demoMode === 'boolean') {
      target.demoMode = src.demoMode;
    }
    if (typeof src.medReminderTime === 'string') {
      target.medReminderTime = src.medReminderTime;
    }
    if (typeof src.lowBpm === 'number' && src.lowBpm > 20 && src.lowBpm < 80) {
      target.lowBpm = src.lowBpm;
    }
  }
}
