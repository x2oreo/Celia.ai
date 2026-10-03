// App configuration. Only public values belong here.
// The Supabase anon key is public by design (RLS protects data); the LLM API key never ships in the app —
// it lives in Supabase Edge Function secrets. Per-developer values live in the gitignored LocalConfig.ets.

import { LocalConfig } from './LocalConfig';

export class Config {
  static readonly BACKEND_URL: string = LocalConfig.BACKEND_URL;
  static readonly SUPABASE_ANON_KEY: string = LocalConfig.SUPABASE_ANON_KEY;
  static readonly AGENT_TIMEOUT_MS: number = 20000;
  static readonly DRUG_CHECK_TIMEOUT_MS: number = 5000;
  // Shared demo watch, used until this phone is paired with a watch (data/WatchPairing.ets sets WATCH_DEVICE_ID at
  // launch and after pairing). Every watch query reads WATCH_DEVICE_ID at call time.
  static readonly DEFAULT_WATCH_DEVICE_ID: string = 'demo-watch-1';
  static WATCH_DEVICE_ID: string = Config.DEFAULT_WATCH_DEVICE_ID;

  static hasBackend(): boolean {
    return Config.BACKEND_URL.length > 0 && Config.SUPABASE_ANON_KEY.length > 0;
  }
}
