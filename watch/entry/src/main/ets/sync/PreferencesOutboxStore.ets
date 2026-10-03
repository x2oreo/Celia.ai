import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { OutboxStore } from './MetricOutbox';

const KEY = 'outbox';

export class PreferencesOutboxStore implements OutboxStore {
  private prefs: preferences.Preferences;

  constructor(ctx: common.Context) {
    const opts: preferences.Options = { name: 'celia_watch' };
    this.prefs = preferences.getPreferencesSync(ctx, opts);
  }

  load(): string {
    try {
      return this.prefs.getSync(KEY, '') as string;
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`outbox load failed: ${err.code}`);
      return '';
    }
  }

  save(json: string): void {
    try {
      this.prefs.putSync(KEY, json);
      this.prefs.flush().catch((err: BusinessError) => {
        Logger.warn(`outbox flush failed: ${err.code}`);
      });
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(`outbox save failed: ${err.code}`);
    }
  }
}
