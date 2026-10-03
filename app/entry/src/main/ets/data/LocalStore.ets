// On-device store. Personal data (profile, meds, contacts, events, checks) lives only here — never on a server.
//
// Reads are served from an in-memory cache; every write updates the cache and is persisted to ArkData RDB
// (celia.db, encrypted). Before `init(context)` — and in local unit tests — the store is memory-only.

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { AppEvent, AppEventKind } from '../model/AppEvent';
import { ScanRecord, ScanVia } from '../model/ScanRecord';
import { ComboKind, RiskLevel } from '../model/DrugVerdict';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('LocalStore');

const DB_NAME: string = 'celia.db';
const SCHEMA_VERSION: number = 1;
const MAX_EVENTS: number = 500;
const MAX_SCANS: number = 300;

const CREATE_TABLES: string[] = [
  'CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS meds (id INTEGER PRIMARY KEY, name TEXT NOT NULL, ingredient TEXT NOT NULL, ' +
    'dose TEXT NOT NULL, added_at INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, kind TEXT NOT NULL, ' +
    'detail TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS scans (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, via TEXT NOT NULL, ' +
    'query TEXT NOT NULL, ingredient TEXT NOT NULL, risk TEXT NOT NULL, combo TEXT NOT NULL)'
];

// What changed — screens subscribe with onChange() and reload only what they show.
export type StoreTopic = 'profile' | 'meds' | 'events' | 'scans' | 'settings';

export class LocalStore {
  private static instance: LocalStore | undefined = undefined;

  private profile: Profile | undefined = undefined;
  private meds: Medication[] = [];
  private events: AppEvent[] = [];
  private scans: ScanRecord[] = [];
  private settings: Map<string, string> = new Map<string, string>();
  private nextId: number = 1;
  private rdb: relationalStore.RdbStore | undefined = undefined;
  private ready: Promise<void> = Promise.resolve();
  private changes: Listeners<StoreTopic> = new Listeners<StoreTopic>();

  static get(): LocalStore {
    if (LocalStore.instance === undefined) {
      LocalStore.instance = new LocalStore();
    }
    return LocalStore.instance;
  }

  // Called once from EntryAbility.onCreate. Every read/write waits for it, so callers never race the load.
  init(context: common.Context): Promise<void> {
    this.ready = this.open(context);
    return this.ready;
  }

  onChange(cb: Listener<StoreTopic>): () => void {
    return this.changes.add(cb);
  }

  // ── Profile ──────────────────────────────────────────────────────────────────────────────────
  async getProfile(): Promise<Profile | undefined> {
    await this.ready;
    return this.profile;
  }

  async saveProfile(profile: Profile): Promise<void> {
    await this.ready;
    this.profile = profile;
    await this.putKv('profile', JSON.stringify(profile));
    this.changes.emit('profile');
  }

  // ── Medicines ────────────────────────────────────────────────────────────────────────────────
  async listMeds(): Promise<Medication[]> {
    await this.ready;
    return this.meds.slice();
  }

  async addMed(name: string, ingredient: string, dose: string): Promise<Medication> {
    await this.ready;
    const med: Medication = {
      id: this.nextId++,
      name: name,
      ingredient: ingredient,
      dose: dose,
      addedAt: Date.now()
    };
    this.meds.push(med);
    if (this.rdb !== undefined) {
      const row: relationalStore.ValuesBucket = {
        id: med.id, name: med.name, ingredient: med.ingredient, dose: med.dose, added_at: med.addedAt
      };
      await this.safeInsert('meds', row);
    }
    this.changes.emit('meds');
    return med;
  }

  async removeMed(id: number): Promise<void> {
    await this.ready;
    this.meds = this.meds.filter((m: Medication) => m.id !== id);
    await this.safeExec('DELETE FROM meds WHERE id = ?', [id]);
    this.changes.emit('meds');
  }

  // ── Event log ────────────────────────────────────────────────────────────────────────────────
  async logEvent(kind: AppEventKind, detail: string): Promise<void> {
    await this.ready;
    const event: AppEvent = {
      id: this.nextId++,
      ts: Date.now(),
      kind: kind,
      detail: detail
    };
    this.events.push(event);
    if (this.events.length > MAX_EVENTS) {
      this.events = this.events.slice(this.events.length - MAX_EVENTS);
    }
    if (this.rdb !== undefined) {
      const row: relationalStore.ValuesBucket = { id: event.id, ts: event.ts, kind: event.kind, detail: event.detail };
      await this.safeInsert('events', row);
    }
    this.changes.emit('events');
  }

  async listEvents(): Promise<AppEvent[]> {
    await this.ready;
    return this.events.slice();
  }

  // ── Medicine checks (history) ────────────────────────────────────────────────────────────────
  async logScan(scan: ScanRecord): Promise<ScanRecord> {
    await this.ready;
    const saved: ScanRecord = {
      id: this.nextId++,
      ts: scan.ts,
      via: scan.via,
      query: scan.query,
      ingredient: scan.ingredient,
      risk: scan.risk,
      combo: scan.combo
    };
    this.scans.push(saved);
    if (this.scans.length > MAX_SCANS) {
      this.scans = this.scans.slice(this.scans.length - MAX_SCANS);
    }
    if (this.rdb !== undefined) {
      const row: relationalStore.ValuesBucket = {
        id: saved.id, ts: saved.ts, via: saved.via, query: saved.query, ingredient: saved.ingredient,
        risk: saved.risk, combo: saved.combo
      };
      await this.safeInsert('scans', row);
    }
    this.changes.emit('scans');
    return saved;
  }

  // Newest first.
  async listScans(): Promise<ScanRecord[]> {
    await this.ready;
    return this.scans.slice().reverse();
  }

  // ── Small settings (key → string) ────────────────────────────────────────────────────────────
  async getSetting(key: string, fallback: string): Promise<string> {
    await this.ready;
    return this.settings.get(key) ?? fallback;
  }

  async setSetting(key: string, value: string): Promise<void> {
    await this.ready;
    this.settings.set(key, value);
    await this.putKv(`setting.${key}`, value);
    this.changes.emit('settings');
  }

  // Wipes every table (Settings → Clear all data).
  async clearAll(): Promise<void> {
    await this.ready;
    this.profile = undefined;
    this.meds = [];
    this.events = [];
    this.scans = [];
    this.settings.clear();
    for (const table of ['kv', 'meds', 'events', 'scans']) {
      await this.safeExec(`DELETE FROM ${table}`, []);
    }
    this.changes.emit('profile');
    this.changes.emit('meds');
    this.changes.emit('events');
    this.changes.emit('scans');
    this.changes.emit('settings');
  }

  // ── Persistence ──────────────────────────────────────────────────────────────────────────────
  private async open(context: common.Context): Promise<void> {
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S3,
        encrypt: true
      };
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
      if (store.version < SCHEMA_VERSION) {
        for (const sql of CREATE_TABLES) {
          await store.executeSql(sql);
        }
        store.version = SCHEMA_VERSION;
      }
      this.rdb = store;
      await this.loadAll(store);
      log.info(`opened ${DB_NAME} v${store.version}: ${this.meds.length} meds, ${this.scans.length} checks`);
    } catch (e) {
      // Keep the app usable: memory-only store for this session.
      log.error(`RDB open failed, memory-only: ${JSON.stringify(e)}`);
      this.rdb = undefined;
    }
  }

  private async loadAll(store: relationalStore.RdbStore): Promise<void> {
    try {
      let maxId: number = 0;

      const kv: relationalStore.ResultSet = await store.querySql('SELECT k, v FROM kv', []);
      while (kv.goToNextRow()) {
        const k: string = kv.getString(kv.getColumnIndex('k'));
        const v: string = kv.getString(kv.getColumnIndex('v'));
        if (k === 'profile') {
          this.profile = JSON.parse(v) as Profile;
        } else if (k.startsWith('setting.')) {
          this.settings.set(k.substring('setting.'.length), v);
        }
      }
      kv.close();

      const meds: relationalStore.ResultSet = await store.querySql('SELECT * FROM meds ORDER BY id', []);
      while (meds.goToNextRow()) {
        const m: Medication = {
          id: meds.getLong(meds.getColumnIndex('id')),
          name: meds.getString(meds.getColumnIndex('name')),
          ingredient: meds.getString(meds.getColumnIndex('ingredient')),
          dose: meds.getString(meds.getColumnIndex('dose')),
          addedAt: meds.getLong(meds.getColumnIndex('added_at'))
        };
        maxId = Math.max(maxId, m.id);
        this.meds.push(m);
      }
      meds.close();

      const events: relationalStore.ResultSet =
        await store.querySql(`SELECT * FROM events ORDER BY id DESC LIMIT ${MAX_EVENTS}`, []);
      while (events.goToNextRow()) {
        const ev: AppEvent = {
          id: events.getLong(events.getColumnIndex('id')),
          ts: events.getLong(events.getColumnIndex('ts')),
          kind: events.getString(events.getColumnIndex('kind')) as AppEventKind,
          detail: events.getString(events.getColumnIndex('detail'))
        };
        maxId = Math.max(maxId, ev.id);
        this.events.unshift(ev);
      }
      events.close();

      const scans: relationalStore.ResultSet =
        await store.querySql(`SELECT * FROM scans ORDER BY id DESC LIMIT ${MAX_SCANS}`, []);
      while (scans.goToNextRow()) {
        const s: ScanRecord = {
          id: scans.getLong(scans.getColumnIndex('id')),
          ts: scans.getLong(scans.getColumnIndex('ts')),
          via: scans.getString(scans.getColumnIndex('via')) as ScanVia,
          query: scans.getString(scans.getColumnIndex('query')),
          ingredient: scans.getString(scans.getColumnIndex('ingredient')),
          risk: scans.getString(scans.getColumnIndex('risk')) as RiskLevel,
          combo: scans.getString(scans.getColumnIndex('combo')) as ComboKind
        };
        maxId = Math.max(maxId, s.id);
        this.scans.unshift(s);
      }
      scans.close();

      this.nextId = maxId + 1;
    } catch (e) {
      log.error(`load failed: ${JSON.stringify(e)}`);
    }
  }

  private async putKv(key: string, value: string): Promise<void> {
    await this.safeExec('INSERT OR REPLACE INTO kv (k, v) VALUES (?, ?)', [key, value]);
  }

  private async safeInsert(table: string, row: relationalStore.ValuesBucket): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    try {
      await this.rdb.insert(table, row);
    } catch (e) {
      log.error(`insert into ${table} failed: ${JSON.stringify(e)}`);
    }
  }

  private async safeExec(sql: string, args: relationalStore.ValueType[]): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    try {
      await this.rdb.executeSql(sql, args);
    } catch (e) {
      log.error(`sql failed (${sql.substring(0, 40)}): ${JSON.stringify(e)}`);
    }
  }
}
