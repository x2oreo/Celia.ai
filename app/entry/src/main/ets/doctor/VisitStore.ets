// Saved doctor visits: one JSON list under the LocalStore setting `doctor_visits` (encrypted RDB, no schema change).

import { LocalStore } from '../data/LocalStore';
import { DoctorVisit, parseVisits, removeVisit, upsertVisit } from './Visit';

const KEY: string = 'doctor_visits';

export class VisitStore {
  static async list(): Promise<DoctorVisit[]> {
    return parseVisits(await LocalStore.get().getSetting(KEY, '[]'));
  }

  static async get(id: number): Promise<DoctorVisit | undefined> {
    return (await VisitStore.list()).find((v: DoctorVisit) => v.id === id);
  }

  static async save(v: DoctorVisit): Promise<void> {
    await LocalStore.get().setSetting(KEY, JSON.stringify(upsertVisit(await VisitStore.list(), v)));
  }

  static async remove(id: number): Promise<void> {
    await LocalStore.get().setSetting(KEY, JSON.stringify(removeVisit(await VisitStore.list(), id)));
  }
}
