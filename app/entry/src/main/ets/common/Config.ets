// App configuration. Only public values belong here.
// The Supabase anon key is public by design (RLS protects data); the LLM API key never ships in the app —
// it lives in Supabase Edge Function secrets. Per-developer values live in the gitignored LocalConfig.ets.

import { LocalConfig } from './LocalConfig';

export class Config {
  static readonly BACKEND_URL: string = LocalConfig.BACKEND_URL;
  static readonly SUPABASE_ANON_KEY: string = LocalConfig.SUPABASE_ANON_KEY;
  static readonly AGENT_TIMEOUT_MS: number = 20000;
  static readonly DRUG_CHECK_TIMEOUT_MS: number = 5000;

  static hasBackend(): boolean {
    return Config.BACKEND_URL.length > 0 && Config.SUPABASE_ANON_KEY.length > 0;
  }
}
