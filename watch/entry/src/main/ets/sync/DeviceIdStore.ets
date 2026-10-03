import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

const KEY = 'device_id';

/**
 * This watch's id for every upload, RPC and watch_context read: a random UUID created on first launch and kept in
 * Preferences, so teammates' emulators never share an id. WATCH_DEVICE_ID in watch/.env overrides it when set.
 */
export function deviceIdFor(ctx: common.Context, override: string): string {
  if (override.length >= 3) {
    return override;
  }
  try {
    const opts: preferences.Options = { name: 'celia_watch' };
    const prefs = preferences.getPreferencesSync(ctx, opts);
    const saved = prefs.getSync(KEY, '') as string;
    if (saved.length >= 3) {
      return saved;
    }
    const id = util.generateRandomUUID(false);
    prefs.putSync(KEY, id);
    prefs.flush().catch((err: BusinessError) => {
      Logger.warn(`device id flush failed: ${err.code}`);
    });
    Logger.info('generated a new watch device id');
    return id;
  } catch (e) {
    // Without storage, still unique for this run; pairing must then be redone after a restart.
    Logger.warn(`device id storage unavailable: ${(e as BusinessError).code}`);
    return util.generateRandomUUID(false);
  }
}
