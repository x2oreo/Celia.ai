// Tells the Celia watch app (watch/) about the user's genotype and a risky medicine just taken, through the
// `watch_context` row it polls every 60 s (T15 cloud path — no Wear Engine approval needed). Only with the cloud
// backend (Config.hasWatchCloud). Sends no personal data: device id, genotype, ingredient, risk level, time.

import { Config } from '../common/Config';
import { NetResult, upsertJson } from '../common/Net';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('WatchContext');

// Pure: the row written to watch_context. Exported for tests.
export function watchContextRow(deviceId: string, genotype: string, drug: string, risk: string,
  at: number): Record<string, string> {
  const row: Record<string, string> = {
    'device_id': deviceId,
    'genotype': ['LQT1', 'LQT2', 'LQT3'].includes(genotype) ? genotype : 'UNKNOWN',
    'risky_drug': drug.slice(0, 80),
    'risky_drug_risk': risk,
    'risky_drug_at': new Date(at).toISOString()
  };
  return row;
}

export class WatchContextSync {
  // `at` = when it was taken (drugs/DrugIntake.ets); the watch's 72 h window starts there.
  static async riskyDrug(genotype: string, drug: string, risk: string, at: number = Date.now()): Promise<boolean> {
    if (!Config.hasWatchCloud() || !['KNOWN_RISK', 'POSSIBLE_RISK', 'CONDITIONAL_RISK'].includes(risk)) {
      return false;
    }
    const res: NetResult = await upsertJson('/rest/v1/watch_context',
      watchContextRow(Config.WATCH_DEVICE_ID, genotype, drug, risk, at), 8000);
    if (!res.ok) {
      log.warn(`watch_context upsert failed: HTTP ${res.status}`);
    }
    return res.ok;
  }
}
