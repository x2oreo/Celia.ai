import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Turns watch/.env (git-ignored) into resources/rawfile/config.json (git-ignored) on every build,
 * because the app can only read files bundled into the HAP. Without .env the app runs offline (no upload).
 */
function writeConfigFromEnv(): void {
  const envPath = path.resolve(__dirname, '../.env');
  const outPath = path.resolve(__dirname, 'src/main/resources/rawfile/config.json');
  if (!fs.existsSync(envPath)) {
    if (fs.existsSync(outPath)) {
      fs.unlinkSync(outPath);
    }
    console.warn('[celia] watch/.env not found: building without Supabase config (upload disabled)');
    return;
  }
  const env = new Map<string, string>();
  for (const raw of fs.readFileSync(envPath, 'utf-8').split(/\r?\n/)) {
    const line = raw.trim();
    const eq = line.indexOf('=');
    if (line.length === 0 || line.startsWith('#') || eq < 0) {
      continue;
    }
    env.set(line.slice(0, eq).trim(), line.slice(eq + 1).trim().replace(/^["']|["']$/g, ''));
  }
  const str = (key: string, fallback: string): string => env.get(key) || fallback;
  const num = (key: string, fallback: number): number => {
    const n = Number(env.get(key));
    return Number.isFinite(n) && n > 0 ? n : fallback;
  };
  const config = {
    supabaseUrl: str('SUPABASE_URL', ''),
    supabaseAnonKey: str('SUPABASE_ANON_KEY', ''),
    deviceId: str('WATCH_DEVICE_ID', 'demo-watch-1'),
    defaultSource: str('DEFAULT_SOURCE', 'SENSOR'),
    medicationName: str('MEDICATION_NAME', 'nadolol'),
    highBpm: num('HIGH_BPM', 140),
    restHighBpm: num('REST_HIGH_BPM', 120),
    lowBpm: num('LOW_BPM', 45)
  };
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(config, null, 2));
  const ready = config.supabaseUrl.startsWith('https://') && !config.supabaseAnonKey.startsWith('YOUR-');
  console.log(`[celia] config.json written from .env (upload ${ready ? 'enabled' : 'disabled: fill in watch/.env'})`);
}

writeConfigFromEnv();

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
