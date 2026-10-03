import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { HrSourceKind } from '../model/WatchMetric';
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
  /** Identifies this watch in watch_metrics.device_id. The phone app filters by it. */
  deviceId: string;
  defaultSource: HrSourceKind;
  medicationName: string;
  highBpm: number;
  lowBpm: number;
}

export class AppConfig {
  static defaults(): AppConfigData {
    const cfg: AppConfigData = {
      supabaseUrl: '',
      supabaseAnonKey: '',
      deviceId: 'demo-watch-1',
      defaultSource: 'SENSOR',
      medicationName: 'nadolol',
      highBpm: 140,
      lowBpm: 45
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
    if (typeof src.deviceId === 'string' && src.deviceId.length >= 3) {
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
    if (typeof src.lowBpm === 'number' && src.lowBpm > 20 && src.lowBpm < 80) {
      target.lowBpm = src.lowBpm;
    }
  }
}
