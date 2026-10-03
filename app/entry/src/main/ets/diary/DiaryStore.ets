// Reads and writes the feeling diary through LocalStore's event log (kind FEELING, no schema change).

import { LocalStore } from '../data/LocalStore';
import { AppEvent } from '../model/AppEvent';
import { buildFeeling, Mood } from './Diary';
import { dailyCounts, DiaryDay } from './DailyCounts';

export class DiaryStore {
  static async add(mood: Mood, note: string): Promise<void> {
    await LocalStore.get().logEvent('FEELING', JSON.stringify(buildFeeling(mood, note)));
  }

  // Newest first.
  static async recent(limit: number): Promise<AppEvent[]> {
    const all: AppEvent[] = await LocalStore.get().listEvents();
    return all.filter((e: AppEvent) => e.kind === 'FEELING').reverse().slice(0, limit);
  }

  // For Trends (Workstream A): diary and symptom counts for the last `days` calendar days, oldest first.
  static async dailyCounts(days: number): Promise<DiaryDay[]> {
    return dailyCounts(await LocalStore.get().listEvents(), Date.now(), days);
  }
}
