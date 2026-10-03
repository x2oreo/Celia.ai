import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

interface MissedBetaBlockerArgs {
  p_device_id: string;
  p_on: boolean;
}

/**
 * Demo-only Supabase RPCs. `simulate_missed_beta_blocker` writes (or clears) 16 labelled simulated days of resting
 * HR (14 at ~58 bpm, the last 2 at ~70); the phone app reads `watch_resting_daily` and asks about missed doses.
 */
export class DemoRpcClient {
  private baseUrl: string;
  private anonKey: string;

  constructor(supabaseUrl: string, anonKey: string) {
    this.baseUrl = `${supabaseUrl}/rest/v1/rpc`;
    this.anonKey = anonKey;
  }

  /** True on 2xx. 404 means the migration (20261003230000_resting_day_sim.sql) isn't applied yet. */
  async simulateMissedBetaBlocker(deviceId: string, on: boolean): Promise<boolean> {
    const req = http.createHttp();
    const body: MissedBetaBlockerArgs = { p_device_id: deviceId, p_on: on };
    try {
      const resp = await req.request(`${this.baseUrl}/simulate_missed_beta_blocker`, {
        method: http.RequestMethod.POST,
        header: {
          'apikey': this.anonKey,
          'Authorization': `Bearer ${this.anonKey}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 5000,
        readTimeout: 5000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        Logger.info(`missed beta-blocker sim ${on ? 'on' : 'off'}: ${String(resp.result)} simulated days`);
        return true;
      }
      const hint = resp.responseCode === 404 ? ' (migration resting_day_sim not applied?)' : '';
      Logger.warn(`missed beta-blocker sim HTTP ${resp.responseCode}${hint}: ${String(resp.result).slice(0, 200)}`);
      return false;
    } catch (e) {
      Logger.warn(`missed beta-blocker sim failed: ${(e as BusinessError).code}`);
      return false;
    } finally {
      req.destroy();
    }
  }
}
