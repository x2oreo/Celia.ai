// Where the Health numbers come from: the Celia watch (through Supabase) or the phone's own labelled simulation.
// The user picks it on the Health tab (Demo controls); the choice is kept in settings. Watch is the default and
// falls back to the simulation when no Supabase project can be reached with the configured keys.

import { Config } from '../common/Config';
import { NetTarget, shareTarget } from '../common/Net';
import { LocalStore } from '../data/LocalStore';
import { VitalsSourceKind } from '../model/Vitals';

const KEY_SOURCE: string = 'vitalsSource';

// Which project the watch data is read from.
//   BACKEND  the app backend is the Supabase project (release build): same URL and key as everything else.
//   SHARE    the AI backend is a local dev server (127.0.0.1) that has no watch tables: read the deployed project
//            (Config.SHARE_BACKEND_URL) with its own public client key (LocalConfig.SHARE_ANON_KEY).
//   DEMO     no backend, or no key for the deployed project: built-in demo history, labelled SIMULATED.
export type TrendsRoute = 'BACKEND' | 'SHARE' | 'DEMO';

export function trendsRoute(hasWatchCloud: boolean, hasBackend: boolean, shareUrl: string, shareKey: string,
  backendKey: string): TrendsRoute {
  if (hasWatchCloud) {
    return 'BACKEND';
  }
  // Without its own key the share key falls back to the local backend's key, which the project rejects.
  return hasBackend && shareUrl !== '' && shareKey !== '' && shareKey !== backendKey ? 'SHARE' : 'DEMO';
}

export class WatchSource {
  private static pref: VitalsSourceKind = 'WATCH';

  /** Call once at launch, before the vitals source starts. */
  static async load(): Promise<void> {
    const saved: string = await LocalStore.get().getSetting(KEY_SOURCE, 'WATCH');
    WatchSource.pref = saved === 'SIMULATED' ? 'SIMULATED' : 'WATCH';
  }

  /** What the user picked. */
  static preferred(): VitalsSourceKind {
    return WatchSource.pref;
  }

  static async set(kind: VitalsSourceKind): Promise<void> {
    WatchSource.pref = kind;
    await LocalStore.get().setSetting(KEY_SOURCE, kind);
  }

  /** The Supabase project holding the watch tables, or undefined when none can be reached. */
  static target(): NetTarget | undefined {
    const route: TrendsRoute = trendsRoute(Config.hasWatchCloud(), Config.hasBackend(), Config.SHARE_BACKEND_URL,
      Config.SHARE_ANON_KEY, Config.SUPABASE_ANON_KEY);
    if (route === 'DEMO') {
      return undefined;
    }
    return route === 'SHARE' ? shareTarget() : new NetTarget(Config.BACKEND_URL, Config.SUPABASE_ANON_KEY);
  }

  static available(): boolean {
    return WatchSource.target() !== undefined;
  }

  /** The watch data to show, or undefined when the app shows its simulation (picked, or nothing to read from). */
  static activeTarget(): NetTarget | undefined {
    return WatchSource.pref === 'WATCH' ? WatchSource.target() : undefined;
  }

  /** What the app actually shows right now. */
  static active(): VitalsSourceKind {
    return WatchSource.activeTarget() !== undefined ? 'WATCH' : 'SIMULATED';
  }
}
