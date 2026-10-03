// On-device store. Personal data (profile, meds, contacts, events, checks, agent chats) lives only here — never on a
// server.
//
// Reads are served from an in-memory cache; every write updates the cache and is persisted to ArkData RDB
// (celia.db, encrypted). Before `init(context)` — and in local unit tests — the store is memory-only.

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Contact, ExtraField, Genotype, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { AppEvent, AppEventKind } from '../model/AppEvent';
import { ScanRecord, ScanVia } from '../model/ScanRecord';
import { ComboKind, RiskLevel } from '../model/DrugVerdict';
import { ChatRole, UiAction } from '../model/AgentTypes';
import {
  ChatSummary, MAX_CHAT_MESSAGES, MAX_CHATS, StoredChatMessage, chatTitle, keepOnRestore
} from '../model/Chat';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('LocalStore');

const DB_NAME: string = 'celia.db';
const SCHEMA_VERSION: number = 2;   // 2: agent chats
const MAX_EVENTS: number = 500;
const MAX_SCANS: number = 300;

const CREATE_TABLES: string[] = [
  'CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS meds (id INTEGER PRIMARY KEY, name TEXT NOT NULL, ingredient TEXT NOT NULL, ' +
    'dose TEXT NOT NULL, added_at INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, kind TEXT NOT NULL, ' +
    'detail TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS scans (id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, via TEXT NOT NULL, ' +
    'query TEXT NOT NULL, ingredient TEXT NOT NULL, risk TEXT NOT NULL, combo TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS chats (id INTEGER PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, ' +
    'updated_at INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS chat_messages (id INTEGER PRIMARY KEY, chat_id INTEGER NOT NULL, ts INTEGER NOT NULL, ' +
    'role TEXT NOT NULL, text TEXT NOT NULL, actions TEXT NOT NULL)',
  'CREATE INDEX IF NOT EXISTS chat_messages_chat ON chat_messages (chat_id, id)'
];

// What changed — screens subscribe with onChange() and reload only what they show.
export type StoreTopic = 'profile' | 'meds' | 'events' | 'scans' | 'settings' | 'chats';

// Stored card list of a chat message; a corrupt value drops the cards, never the message. Exported for tests.
export function parseStoredActions(raw: string): UiAction[] {
  try {
    const a: UiAction[] = JSON.parse(raw) as UiAction[];
    return Array.isArray(a) ? a : [];
  } catch (e) {
    return [];
  }
}

function optString(v: string | undefined): string | undefined {
  return typeof v === 'string' ? v : undefined;
}

function stringList(v: string[] | undefined): string[] {
  return Array.isArray(v) ? v.filter((s: string) => typeof s === 'string') : [];
}

// Stored profile JSON → a Profile with every field the current code expects (Workstream B4). Profiles saved by
// older versions lack the emergency details; lists default to [] and missing text stays undefined, so the card
// simply hides them. Corrupt JSON → undefined (the app then treats it as no profile). Exported for tests.
export function parseStoredProfile(json: string): Profile | undefined {
  let raw: Profile;
  try {
    raw = JSON.parse(json) as Profile;
  } catch (e) {
    return undefined;
  }
  if (raw === null || typeof raw !== 'object') {
    return undefined;
  }
  const genotype: Genotype = raw.genotype === 'LQT1' || raw.genotype === 'LQT2' || raw.genotype === 'LQT3' ?
    raw.genotype : 'UNKNOWN';
  const contacts: Contact[] = Array.isArray(raw.contacts) ? raw.contacts.filter((c: Contact) =>
    c !== null && typeof c === 'object' && typeof c.name === 'string' && typeof c.phone === 'string') : [];
  contacts.forEach((c: Contact) => {
    c.relation = typeof c.relation === 'string' ? c.relation : '';
  });
  const extra: ExtraField[] = Array.isArray(raw.extra) ? raw.extra.filter((x: ExtraField) =>
    x !== null && typeof x === 'object' && typeof x.label === 'string' && typeof x.value === 'string') : [];
  const p: Profile = {
    condition: 'LQTS',
    genotype: genotype,
    hasIcd: raw.hasIcd === true,
    notes: typeof raw.notes === 'string' ? raw.notes : '',
    contacts: contacts,
    name: optString(raw.name),
    country: optString(raw.country),
    cardLanguage: optString(raw.cardLanguage),
    dateOfBirth: optString(raw.dateOfBirth),
    sex: raw.sex === 'FEMALE' || raw.sex === 'MALE' || raw.sex === 'OTHER' ? raw.sex : undefined,
    bloodType: optString(raw.bloodType),
    allergies: stringList(raw.allergies),
    icdModel: optString(raw.icdModel),
    cardiologistName: optString(raw.cardiologistName),
    cardiologistPhone: optString(raw.cardiologistPhone),
    hospital: optString(raw.hospital),
    extra: extra,
    hiddenOnCard: stringList(raw.hiddenOnCard),
    updatedAt: typeof raw.updatedAt === 'number' ? raw.updatedAt : undefined
  };
  return p;
}

export class LocalStore {
  private static instance: LocalStore | undefined = undefined;

  private profile: Profile | undefined = undefined;
  private meds: Medication[] = [];
  private events: AppEvent[] = [];
  private scans: ScanRecord[] = [];
  private settings: Map<string, string> = new Map<string, string>();
  private chats: ChatSummary[] = [];
  private chatMessages: Map<number, StoredChatMessage[]> = new Map<number, StoredChatMessage[]>();
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

  // Stamps updatedAt (the time of this local edit; profile sync is last-write-wins on it). Pass stamp=false only when
  // storing a copy that already carries its own time, e.g. a profile restored from the account.
  async saveProfile(profile: Profile, stamp: boolean = true): Promise<void> {
    await this.ready;
    if (stamp) {
      profile.updatedAt = Date.now();
    }
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

  // ── Agent chats ──────────────────────────────────────────────────────────────────────────────
  // Most recently used first.
  async listChats(): Promise<ChatSummary[]> {
    await this.ready;
    return this.chats.slice().sort((a: ChatSummary, b: ChatSummary) => b.updatedAt - a.updatedAt);
  }

  async getChat(id: number): Promise<ChatSummary | undefined> {
    await this.ready;
    return this.chats.find((c: ChatSummary) => c.id === id);
  }

  async createChat(): Promise<ChatSummary> {
    await this.ready;
    const now: number = Date.now();
    const chat: ChatSummary = { id: this.nextId++, title: '', createdAt: now, updatedAt: now, messageCount: 0 };
    this.chats.push(chat);
    this.chatMessages.set(chat.id, []);
    const row: relationalStore.ValuesBucket = {
      id: chat.id, title: chat.title, created_at: chat.createdAt, updated_at: chat.updatedAt
    };
    await this.safeInsert('chats', row);
    await this.trimChats(chat.id);
    this.changes.emit('chats');
    return chat;
  }

  async listChatMessages(chatId: number): Promise<StoredChatMessage[]> {
    await this.ready;
    return (this.chatMessages.get(chatId) ?? []).slice();
  }

  // Appends a message. The first user message names the chat; only display cards are kept (keepOnRestore).
  async addChatMessage(chatId: number, role: ChatRole, text: string, actions: UiAction[]): Promise<void> {
    await this.ready;
    const chat: ChatSummary | undefined = this.chats.find((c: ChatSummary) => c.id === chatId);
    if (chat === undefined) {
      return;
    }
    const msg: StoredChatMessage = {
      id: this.nextId++, chatId: chatId, role: role, text: text, ts: Date.now(),
      actions: actions.filter((a: UiAction) => keepOnRestore(a))
    };
    let list: StoredChatMessage[] = this.chatMessages.get(chatId) ?? [];
    list.push(msg);
    if (list.length > MAX_CHAT_MESSAGES) {
      const drop: StoredChatMessage[] = list.slice(0, list.length - MAX_CHAT_MESSAGES);
      list = list.slice(list.length - MAX_CHAT_MESSAGES);
      for (const d of drop) {
        await this.safeExec('DELETE FROM chat_messages WHERE id = ?', [d.id]);
      }
    }
    this.chatMessages.set(chatId, list);
    chat.updatedAt = msg.ts;
    chat.messageCount = list.length;
    if (chat.title === '' && role === 'user' && text.trim().length > 0) {
      chat.title = chatTitle(text);
    }
    const row: relationalStore.ValuesBucket = {
      id: msg.id, chat_id: chatId, ts: msg.ts, role: role, text: text, actions: JSON.stringify(msg.actions)
    };
    await this.safeInsert('chat_messages', row);
    await this.safeExec('UPDATE chats SET title = ?, updated_at = ? WHERE id = ?', [chat.title, chat.updatedAt, chatId]);
    this.changes.emit('chats');
  }

  async renameChat(chatId: number, title: string): Promise<void> {
    await this.ready;
    const chat: ChatSummary | undefined = this.chats.find((c: ChatSummary) => c.id === chatId);
    const t: string = chatTitle(title);
    if (chat === undefined || t.length === 0) {
      return;
    }
    chat.title = t;
    await this.safeExec('UPDATE chats SET title = ? WHERE id = ?', [t, chatId]);
    this.changes.emit('chats');
  }

  async deleteChat(chatId: number): Promise<void> {
    await this.ready;
    this.chats = this.chats.filter((c: ChatSummary) => c.id !== chatId);
    this.chatMessages.delete(chatId);
    await this.safeExec('DELETE FROM chat_messages WHERE chat_id = ?', [chatId]);
    await this.safeExec('DELETE FROM chats WHERE id = ?', [chatId]);
    this.changes.emit('chats');
  }

  // Keeps at most MAX_CHATS: the least recently used go first (never `keep`, the chat just opened).
  private async trimChats(keep: number): Promise<void> {
    while (this.chats.length > MAX_CHATS) {
      const oldest: ChatSummary[] = this.chats.filter((c: ChatSummary) => c.id !== keep)
        .sort((a: ChatSummary, b: ChatSummary) => a.updatedAt - b.updatedAt);
      if (oldest.length === 0) {
        return;
      }
      const id: number = oldest[0].id;
      this.chats = this.chats.filter((c: ChatSummary) => c.id !== id);
      this.chatMessages.delete(id);
      await this.safeExec('DELETE FROM chat_messages WHERE chat_id = ?', [id]);
      await this.safeExec('DELETE FROM chats WHERE id = ?', [id]);
    }
  }

  // Wipes every table (Settings → Clear all data).
  async clearAll(): Promise<void> {
    await this.ready;
    this.profile = undefined;
    this.meds = [];
    this.events = [];
    this.scans = [];
    this.settings.clear();
    this.chats = [];
    this.chatMessages.clear();
    for (const table of ['kv', 'meds', 'events', 'scans', 'chat_messages', 'chats']) {
      await this.safeExec(`DELETE FROM ${table}`, []);
    }
    this.changes.emit('profile');
    this.changes.emit('meds');
    this.changes.emit('events');
    this.changes.emit('scans');
    this.changes.emit('settings');
    this.changes.emit('chats');
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
      log.info(`opened ${DB_NAME} v${store.version}: ${this.meds.length} meds, ${this.scans.length} checks, ` +
        `${this.chats.length} chats`);
    } catch (e) {
      // Keep the app usable: memory-only store for this session.
      log.error(`RDB open failed, memory-only: ${JSON.stringify(e)}`);
      this.rdb = undefined;
    }
  }

  private async loadAll(store: relationalStore.RdbStore): Promise<void> {
    let maxId: number = 0;
    try {

      const kv: relationalStore.ResultSet = await store.querySql('SELECT k, v FROM kv', []);
      while (kv.goToNextRow()) {
        const k: string = kv.getString(kv.getColumnIndex('k'));
        const v: string = kv.getString(kv.getColumnIndex('v'));
        if (k === 'profile') {
          this.profile = parseStoredProfile(v);   // older profiles get the newer fields' defaults
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

      const chats: relationalStore.ResultSet = await store.querySql('SELECT * FROM chats ORDER BY id', []);
      while (chats.goToNextRow()) {
        const c: ChatSummary = {
          id: chats.getLong(chats.getColumnIndex('id')),
          title: chats.getString(chats.getColumnIndex('title')),
          createdAt: chats.getLong(chats.getColumnIndex('created_at')),
          updatedAt: chats.getLong(chats.getColumnIndex('updated_at')),
          messageCount: 0
        };
        maxId = Math.max(maxId, c.id);
        this.chats.push(c);
        this.chatMessages.set(c.id, []);
      }
      chats.close();

      const msgs: relationalStore.ResultSet = await store.querySql('SELECT * FROM chat_messages ORDER BY id', []);
      while (msgs.goToNextRow()) {
        const id: number = msgs.getLong(msgs.getColumnIndex('id'));
        maxId = Math.max(maxId, id);
        const role: string = msgs.getString(msgs.getColumnIndex('role'));
        if (role !== 'user' && role !== 'assistant') {
          continue;   // one bad row never loses the rest of the history
        }
        const m: StoredChatMessage = {
          id: id,
          chatId: msgs.getLong(msgs.getColumnIndex('chat_id')),
          role: role as ChatRole,
          text: msgs.getString(msgs.getColumnIndex('text')),
          ts: msgs.getLong(msgs.getColumnIndex('ts')),
          actions: parseStoredActions(msgs.getString(msgs.getColumnIndex('actions')))
        };
        const list: StoredChatMessage[] | undefined = this.chatMessages.get(m.chatId);
        if (list !== undefined) {
          list.push(m);
        }
      }
      msgs.close();
      for (const c of this.chats) {
        c.messageCount = (this.chatMessages.get(c.id) ?? []).length;
      }

    } catch (e) {
      log.error(`load failed: ${JSON.stringify(e)}`);
    } finally {
      // Always past every id seen, so a partial load can never reuse a primary key.
      this.nextId = Math.max(this.nextId, maxId + 1);
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
