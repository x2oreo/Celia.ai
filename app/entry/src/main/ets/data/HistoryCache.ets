// The watch's daily history, kept on the phone. Every successful fetch of a daily view is saved here (real days
// only, never simulated ones), per account, and merged back into later fetches. So the Health tab, Trends, the agent
// and the doctor report keep the days already seen when the server returns fewer: offline, a new watch (new device
// id), or a watch that was unpaired. The server still wins for any day it returns.
// The merge is pure and unit-tested; storage is the encrypted LocalStore.

import { LocalStore } from './LocalStore';
import { WatchPairing } from './WatchPairing';
import { Session } from '../account/Session';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('HistoryCache');

const DAY_RE: RegExp = new RegExp('^\\d{4}-\\d{2}-\\d{2}$');
// Longest span any screen asks for is 90 days; keep a little more.
export const MAX_CACHED_DAYS: number = 120;

/** What every cached daily row has in common. */
export interface DayRow {
  day: string;          // YYYY-MM-DD
  simulated: boolean;
}

export type HistoryKind = 'summary' | 'vitals';

/**
 * Server rows + cached days the server did not return, newest first, at most `limit`. Only real (not simulated)
 * cached days are added back: simulated history is the server's to show or hide.
 */
export function mergeDays<T extends DayRow>(fresh: T[], cached: T[], limit: number): T[] {
  const seen: Set<string> = new Set<string>(fresh.map((r: T) => r.day));
  const out: T[] = fresh.slice();
  for (const c of cached) {
    if (!c.simulated && !seen.has(c.day)) {
      out.push(c);
      seen.add(c.day);
    }
  }
  out.sort((a: T, b: T) => a.day < b.day ? 1 : a.day > b.day ? -1 : 0);
  return out.slice(0, Math.max(0, limit));
}

/** What gets stored: the real days of `merged`, newest first, capped. */
export function daysToKeep<T extends DayRow>(merged: T[]): T[] {
  return merged.filter((r: T) => !r.simulated && DAY_RE.test(r.day)).slice(0, MAX_CACHED_DAYS);
}

/** Stored JSON → rows with a valid day; anything else is dropped. Pure. */
export function parseCached<T extends DayRow>(raw: string): T[] {
  try {
    const rows: T[] = JSON.parse(raw) as T[];
    if (!Array.isArray(rows)) {
      return [];
    }
    return rows.filter((r: T) => r !== null && typeof r === 'object' && typeof r.day === 'string' &&
      DAY_RE.test(r.day) && r.simulated === false);
  } catch (e) {
    return [];
  }
}

export class HistoryCache {
  // One history per account; signed out it belongs to this phone.
  private static key(kind: HistoryKind): string {
    const owner: string = Session.userId();
    return `watchHistory.${kind}.${owner !== '' ? owner : 'local'}`;
  }

  /**
   * Merges a fetch with the saved days and saves the result. `fresh` undefined = the fetch failed: the saved days
   * are returned instead (undefined when there are none, so callers still see "offline").
   * The shared demo watch (not paired) is never cached: its rows are not this user's.
   */
  static async merge<T extends DayRow>(kind: HistoryKind, fresh: T[] | undefined, limit: number): Promise<T[] | undefined> {
    if (!WatchPairing.isPaired()) {
      return fresh;
    }
    const key: string = HistoryCache.key(kind);
    const cached: T[] = parseCached<T>(await LocalStore.get().getSetting(key, '[]'));
    if (fresh === undefined) {
      return cached.length > 0 ? cached.slice(0, Math.max(0, limit)) : undefined;
    }
    const merged: T[] = mergeDays<T>(fresh, cached, limit);
    const keep: T[] = daysToKeep<T>(mergeDays<T>(fresh, cached, MAX_CACHED_DAYS));
    try {
      await LocalStore.get().setSettingQuiet(key, JSON.stringify(keep));
    } catch (e) {
      log.warn(`history not saved: ${JSON.stringify(e)}`);
    }
    return merged;
  }
}
