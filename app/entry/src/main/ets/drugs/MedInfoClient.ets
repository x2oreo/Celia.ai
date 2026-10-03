// Optional AI explanation of a medicine (backend /med-info → OpenAI). Explanation only: it is shown as an
// "AI summary" next to the curated facts and never changes a risk badge or verdict. Every reply is validated
// here again (types, lengths, banned safety words); anything off is dropped and the screen keeps the curated data.
// Cached on the device per medicine name + ingredient for 30 days, and re-checked on every read. The call goes through common/Net.ets, so it is
// listed in the privacy ledger.

import { Config } from '../common/Config';
import { NetResult, postJson } from '../common/Net';
import { LocalStore } from '../data/LocalStore';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('MedInfo');

const CACHE_PREFIX: string = 'medinfo.';
const TIMEOUT_MS: number = 22000;
const FIELD_MAX: number = 240;
const TIP_MAX: number = 120;
const TIPS_MAX: number = 3;
const CACHE_MAX_AGE_MS: number = 30 * 24 * 3600 * 1000;
// Same rule as the backend (med-info/logic.ts): never heart-rhythm safety talk or doses. Stems match word
// families ("arrhythmias", "torsades", "QTc", "500mg", "2.5 mg").
const BANNED: RegExp =
  /\b(qtc?\b|torsade|arrhythmi|heart rhythm|safe for (your|the) heart|stop taking|start taking|\d+([.,]\d+)?\s?(mg|mcg|µg|ml)\b)/i;

export interface MedAiInfo {
  summary: string;
  contains: string;
  usedFor: string;
  tips: string[];
  fetchedAt: number;
}

interface MedInfoReply {
  recognised: boolean;
  dropped?: boolean;
  summary: string;
  contains: string;
  usedFor: string;
  tips: string[];
}

// REJECTED: the reply broke a safety rule and was dropped. FAILED: the service answered with an error.
export type MedAiResult = 'OK' | 'NOT_RECOGNISED' | 'REJECTED' | 'OFFLINE' | 'FAILED';

export class MedAiOutcome {
  result: MedAiResult;
  info: MedAiInfo | undefined;

  constructor(result: MedAiResult, info: MedAiInfo | undefined) {
    this.result = result;
    this.info = info;
  }
}

function okString(v: string | undefined, max: number): boolean {
  return typeof v === 'string' && v.length <= max;
}

// Pure: is this info still fit to show (lengths, banned words)? Used for fresh replies and cached ones.
function infoOk(i: MedAiInfo): boolean {
  if (!okString(i.summary, FIELD_MAX) || !okString(i.contains, FIELD_MAX) || !okString(i.usedFor, FIELD_MAX) ||
    !Array.isArray(i.tips) || i.tips.length > TIPS_MAX || i.summary.trim().length === 0) {
    return false;
  }
  for (const t of i.tips) {
    if (!okString(t, TIP_MAX)) {
      return false;
    }
  }
  return !BANNED.test([i.summary, i.contains, i.usedFor].concat(i.tips).join(' '));
}

// Pure: raw body → outcome. Exported for tests.
export function classifyMedInfo(raw: string, now: number): MedAiOutcome {
  let r: MedInfoReply;
  try {
    r = JSON.parse(raw) as MedInfoReply;
  } catch (e) {
    return new MedAiOutcome('REJECTED', undefined);
  }
  if (r === null || typeof r !== 'object') {
    return new MedAiOutcome('REJECTED', undefined);
  }
  if (r.recognised !== true) {
    return new MedAiOutcome(r.dropped === true ? 'REJECTED' : 'NOT_RECOGNISED', undefined);
  }
  if (!Array.isArray(r.tips)) {
    return new MedAiOutcome('REJECTED', undefined);
  }
  const tips: string[] = [];
  for (const t of r.tips) {
    if (typeof t !== 'string') {
      return new MedAiOutcome('REJECTED', undefined);
    }
    if (t.trim().length > 0) {
      tips.push(t.trim());
    }
  }
  const info: MedAiInfo = {
    summary: typeof r.summary === 'string' ? r.summary.trim() : '',
    contains: typeof r.contains === 'string' ? r.contains.trim() : '',
    usedFor: typeof r.usedFor === 'string' ? r.usedFor.trim() : '',
    tips: tips,
    fetchedAt: now
  };
  return infoOk(info) ? new MedAiOutcome('OK', info) : new MedAiOutcome('REJECTED', undefined);
}

// Pure: raw body → validated info, or undefined. Exported for tests.
export function parseMedInfo(raw: string, now: number): MedAiInfo | undefined {
  return classifyMedInfo(raw, now).info;
}

// Pure: cached JSON → info only while it is fresh and still passes today's checks. Exported for tests.
export function checkCached(raw: string, now: number): MedAiInfo | undefined {
  if (raw.length === 0) {
    return undefined;
  }
  try {
    const i: MedAiInfo = JSON.parse(raw) as MedAiInfo;
    if (i === null || typeof i !== 'object' || typeof i.fetchedAt !== 'number' ||
      now - i.fetchedAt > CACHE_MAX_AGE_MS || !infoOk(i)) {
      return undefined;
    }
    return i;
  } catch (e) {
    return undefined;
  }
}

function cacheKey(name: string, ingredient: string): string {
  return `${CACHE_PREFIX}${name.trim().toLowerCase()}|${ingredient.trim().toLowerCase()}`;
}

export class MedInfoClient {
  static available(): boolean {
    return Config.hasBackend();
  }

  static async cached(name: string, ingredient: string): Promise<MedAiInfo | undefined> {
    try {
      return checkCached(await LocalStore.get().getSetting(cacheKey(name, ingredient), ''), Date.now());
    } catch (e) {
      return undefined;
    }
  }

  static async explain(name: string, ingredient: string): Promise<MedAiOutcome> {
    if (!Config.hasBackend()) {
      return new MedAiOutcome('OFFLINE', undefined);
    }
    // Only the medicine name goes out (shown in the privacy ledger), never anything about the user.
    const fields: Record<string, string> = {
      'medicine': name.trim().slice(0, 80),
      'ingredient': ingredient.trim().slice(0, 80)
    };
    const res: NetResult = await postJson('/functions/v1/med-info', fields, TIMEOUT_MS);
    if (!res.ok) {
      return new MedAiOutcome(res.status === 0 ? 'OFFLINE' : 'FAILED', undefined);
    }
    const out: MedAiOutcome = classifyMedInfo(res.body, Date.now());
    if (out.info === undefined) {
      log.info(`med-info: ${out.result}`);
      return out;
    }
    await LocalStore.get().setSetting(cacheKey(name, ingredient), JSON.stringify(out.info));
    return out;
  }
}
