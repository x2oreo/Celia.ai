import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { DoseState, emptyDoseState } from '../vitals/DoseNudge';

const KEY = 'dose_state';

/** Persists the dose-nudge state next to the outbox, so a restart doesn't re-nudge or forget today's dose. */
export class DoseStore {
  private prefs: preferences.Preferences | undefined = undefined;

  constructor(ctx: common.Context) {
    try {
      const opts: preferences.Options = { name: 'celia_watch' };
      this.prefs = preferences.getPreferencesSync(ctx, opts);
    } catch (e) {
      Logger.warn(`dose store unavailable: ${(e as BusinessError).code}`);
    }
  }

  load(): DoseState {
    try {
      const raw = this.prefs !== undefined ? this.prefs.getSync(KEY, '') as string : '';
      if (raw.length > 0) {
        const s = JSON.parse(raw) as DoseState;
        if (typeof s.lastDoseDay === 'string' && typeof s.timesShown === 'number') {
          return s;
        }
      }
    } catch (e) {
      Logger.warn('dose state unreadable, starting fresh');
    }
    return emptyDoseState();
  }

  save(s: DoseState): void {
    if (this.prefs === undefined) {
      return;
    }
    try {
      this.prefs.putSync(KEY, JSON.stringify(s));
      this.prefs.flush().catch((err: BusinessError) => {
        Logger.warn(`dose state flush failed: ${err.code}`);
      });
    } catch (e) {
      Logger.warn(`dose state save failed: ${(e as BusinessError).code}`);
    }
  }
}
