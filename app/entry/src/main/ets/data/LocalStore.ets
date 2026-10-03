// OWNER: Mark — STUB (in-memory). Replace with ArkData RDB. Personal data stays on-device only.

import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { AppEvent, AppEventKind } from '../model/AppEvent';

export class LocalStore {
  private static instance: LocalStore | undefined = undefined;

  private profile: Profile | undefined = undefined;
  private meds: Medication[] = [];
  private events: AppEvent[] = [];
  private nextId: number = 1;

  static get(): LocalStore {
    if (LocalStore.instance === undefined) {
      LocalStore.instance = new LocalStore();
    }
    return LocalStore.instance;
  }

  async getProfile(): Promise<Profile | undefined> {
    return this.profile;
  }

  async saveProfile(profile: Profile): Promise<void> {
    this.profile = profile;
  }

  async listMeds(): Promise<Medication[]> {
    return this.meds.slice();
  }

  async addMed(name: string, ingredient: string, dose: string): Promise<Medication> {
    const med: Medication = {
      id: this.nextId++,
      name: name,
      ingredient: ingredient,
      dose: dose,
      addedAt: Date.now()
    };
    this.meds.push(med);
    return med;
  }

  async removeMed(id: number): Promise<void> {
    this.meds = this.meds.filter((m: Medication) => m.id !== id);
  }

  async logEvent(kind: AppEventKind, detail: string): Promise<void> {
    const event: AppEvent = {
      id: this.nextId++,
      ts: Date.now(),
      kind: kind,
      detail: detail
    };
    this.events.push(event);
  }

  async listEvents(): Promise<AppEvent[]> {
    return this.events.slice();
  }
}
