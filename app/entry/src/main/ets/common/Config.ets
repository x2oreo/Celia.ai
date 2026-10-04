// App configuration. Only public values belong here.
// The Supabase anon key is public by design (RLS protects data); the LLM API key never ships in the app -
// it lives in Supabase Edge Function secrets. Per-developer values live in the gitignored LocalConfig.ets.

import { LocalConfig } from './LocalConfig';

export class Config {
  static readonly BACKEND_URL: string = LocalConfig.BACKEND_URL;
  static readonly SUPABASE_ANON_KEY: string = LocalConfig.SUPABASE_ANON_KEY;
  // Encrypted share links always go to the deployed Supabase project, even when the AI backend is a local dev server.
  // The key is the project's public client key (from LocalConfig; falls back to SUPABASE_ANON_KEY).
  static readonly SHARE_BACKEND_URL: string =
    LocalConfig.SHARE_BACKEND_URL.length > 0 ? LocalConfig.SHARE_BACKEND_URL : 'https://jxiggumhircfuhianmel.supabase.co';
  static readonly SHARE_ANON_KEY: string =
    LocalConfig.SHARE_ANON_KEY.length > 0 ? LocalConfig.SHARE_ANON_KEY : LocalConfig.SUPABASE_ANON_KEY;
  // Static viewer pages for encrypted share links (Vercel; Supabase cannot serve HTML). Ends with '/'.
  static readonly SHARE_VIEWER_URL: string =
    LocalConfig.SHARE_VIEWER_URL.length > 0 ? LocalConfig.SHARE_VIEWER_URL : 'https://celia-share.vercel.app/';
  // Live voice fed from bundled clips instead of the microphone (voice/DemoVoice.ets). Off unless LocalConfig says 'on'.
  static readonly DEMO_VOICE_INPUT: boolean = LocalConfig.DEMO_VOICE_INPUT === 'on';
  static readonly AGENT_TIMEOUT_MS: number = 20000;
  static readonly DRUG_CHECK_TIMEOUT_MS: number = 5000;   // FDA-label path measured 0.3-3.1 s; on timeout the offline verdict stands
  // Shared demo watch, used until this phone is paired with a watch (data/WatchPairing.ets sets WATCH_DEVICE_ID at
  // launch and after pairing). Every watch query reads WATCH_DEVICE_ID at call time.
  static readonly DEFAULT_WATCH_DEVICE_ID: string = 'demo-watch-1';
  static WATCH_DEVICE_ID: string = Config.DEFAULT_WATCH_DEVICE_ID;

  // Test seam: unit tests run the deterministic offline paths whatever the developer's LocalConfig says.
  private static offline: boolean = false;

  static forceOffline(on: boolean): void {
    Config.offline = on;
  }

  static hasBackend(): boolean {
    return !Config.offline && Config.BACKEND_URL.length > 0 && Config.SUPABASE_ANON_KEY.length > 0;
  }

  // Accounts (Supabase Auth + the profiles table) always use the deployed project, like share links.
  static hasAccountBackend(): boolean {
    return !Config.offline && Config.SHARE_BACKEND_URL.length > 0 && Config.SHARE_ANON_KEY.length > 0;
  }

  // Watch data lives in the Supabase database. The local dev backend (backend/eval/dev-backend.ts on 127.0.0.1)
  // only serves the AI functions, so with it the phone keeps its labelled simulated vitals.
  static hasWatchCloud(): boolean {
    return Config.hasBackend() && !/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/|$)/.test(Config.BACKEND_URL);
  }
}
