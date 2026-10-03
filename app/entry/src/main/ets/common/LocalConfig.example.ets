// Template for LocalConfig.ets (gitignored). entry/hvigorfile.ts copies this file to LocalConfig.ets on the
// first build if it is missing. Put your real values in LocalConfig.ets only — never in this template.

export class LocalConfig {
  static readonly BACKEND_URL: string = '';
  static readonly SUPABASE_ANON_KEY: string = '';
  // Emergency-card viewer override, e.g. 'http://192.168.1.20:8080/card/' (set by app/scripts/serve-card.sh).
  // Empty → the public GitHub Pages viewer.
  static readonly CARD_VIEWER_URL: string = '';
}
