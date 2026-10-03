import { Logger } from '../common/Logger';
import { RestClient } from './RestClient';

interface MissedBetaBlockerArgs {
  p_device_id: string;
  p_on: boolean;
}

/**
 * Demo-only Supabase RPCs. `simulate_missed_beta_blocker` writes (or clears) 16 labelled simulated days of resting
 * HR (14 at ~58 bpm, the last 2 at ~70); the phone app reads `watch_resting_daily` and asks about missed doses.
 */
export class DemoRpcClient {
  private client: RestClient;

  constructor(client: RestClient) {
    this.client = client;
  }

  /** True on 2xx. 404 means the migration (20261003230000_resting_day_sim.sql) isn't applied yet. */
  async simulateMissedBetaBlocker(deviceId: string, on: boolean): Promise<boolean> {
    const body: MissedBetaBlockerArgs = { p_device_id: deviceId, p_on: on };
    const resp = await this.client.post('/rest/v1/rpc/simulate_missed_beta_blocker', JSON.stringify(body), '');
    if (resp.status === 0) {
      Logger.warn(`missed beta-blocker sim failed: ${resp.body}`);
      return false;
    }
    if (resp.status >= 200 && resp.status < 300) {
      Logger.info(`missed beta-blocker sim ${on ? 'on' : 'off'}: ${resp.body} simulated days`);
      return true;
    }
    const hint = resp.status === 404 ? ' (migration resting_day_sim not applied?)' : '';
    Logger.warn(`missed beta-blocker sim HTTP ${resp.status}${hint}: ${resp.body.slice(0, 200)}`);
    return false;
  }
}
