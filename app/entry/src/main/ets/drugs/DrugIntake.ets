// "I took it" for a medicine with QT risk (Check result page). Checking a medicine is not taking it, so only this
// tells the watch: it writes the drug and the time of taking to watch_context (WatchContextSync). The watch then
// lowers its high heart-rate limits for 72 h, shows its drug glance once, and a symptom answered within 24 h becomes
// a SYMPTOM_AFTER_RISKY_DRUG insight. Logging an intake never means the medicine is safe.

import { CheckOutcome } from './CheckService';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { WatchContextSync } from '../vitals/WatchContextSync';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('DrugIntake');

/** Same window the watch uses for a recent risky drug (watch/…/sync/PatientContextClient.ets RECENT_DRUG_MS). */
export const WATCH_WINDOW_MS: number = 72 * 3600 * 1000;

const KEY_LAST: string = 'riskyIntakeLast';

/** A symptom this soon after a logged risky drug gets the stronger warning (watch: DrugBadge, DB: watch_insights). */
export const SYMPTOM_WINDOW_MS: number = 24 * 3600 * 1000;

/**
 * "You said you feel dizzy 3 h after taking clarithromycin. …" for a watch "How do you feel?" answer within 24 h of
 * a logged intake; '' otherwise ('fine' never warns). Same rule as the watch, so both say the same thing. Pure.
 */
export function symptomAfterDrugText(kind: string, rec: IntakeRecord | undefined, now: number): string {
  if (rec === undefined || rec.ts <= 0 || now < rec.ts || now - rec.ts > SYMPTOM_WINDOW_MS) {
    return '';
  }
  let feel: string = '';
  switch (kind) {
    case 'dizziness':
      feel = 'feel dizzy';
      break;
    case 'palpitations':
      feel = 'your heart is racing';
      break;
    case 'fainting':
      feel = 'you fainted';
      break;
    case 'other':
      feel = 'you feel unwell';
      break;
    default:
      return '';
  }
  const hours: number = Math.max(1, Math.round((now - rec.ts) / 3600000));
  return `On your watch you said ${feel}, ${hours} h after taking ${rec.name}, which can affect heart rhythm. ` +
    'Don\'t take the next dose, and call your doctor or pharmacist today. If you faint, call 112.';
}

export interface IntakeRecord {
  name: string;
  risk: string;
  ts: number;
  watchSynced: boolean;
}

interface DoseDetail {
  med: string;
  status: string;
  risk: string;
}

/** Name to log and send: the ingredient when known, else what the user checked. */
export function intakeName(o: CheckOutcome): string {
  return o.verdict.ingredient !== '' ? o.verdict.ingredient : o.verdict.query;
}

/**
 * The QT risk an intake is logged with, or '' when there is nothing to watch for. A dangerous combination with the
 * user's medicines counts as POSSIBLE_RISK even when the medicine alone is not listed. Unknown medicines return ''
 * (we can't say what to watch for; the verdict already says "Couldn't identify").
 */
export function intakeRisk(o: CheckOutcome): string {
  return riskToLog(o.verdict.risk, o.combo.kind !== 'NONE');
}

/** Same rule for any screen: a listed QT risk as is; not listed but in a risky combination → POSSIBLE_RISK. */
export function riskToLog(risk: string, riskyCombination: boolean): string {
  if (risk === 'KNOWN_RISK' || risk === 'POSSIBLE_RISK' || risk === 'CONDITIONAL_RISK') {
    return risk;
  }
  return riskyCombination && risk === 'NOT_LISTED' ? 'POSSIBLE_RISK' : '';
}

export class DrugIntake {
  /**
   * Logs the intake on the phone and tells the watch. Resolves even when the watch can't be reached.
   * resend = true only re-sends to the watch (the dose is already in the event log).
   */
  static async record(name: string, risk: string, now: number, resend: boolean = false):
    Promise<IntakeRecord | undefined> {
    if (risk === '' || name === '') {
      return undefined;
    }
    if (!resend) {
      const detail: DoseDetail = { med: name, status: 'TAKEN', risk: risk };
      await LocalStore.get().logEvent('DOSE', JSON.stringify(detail));
    }
    let synced: boolean = false;
    try {
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      synced = await WatchContextSync.riskyDrug(profile?.genotype ?? 'UNKNOWN', name, risk, now);
    } catch (e) {
      log.warn(`watch context failed: ${String(e)}`);
    }
    const rec: IntakeRecord = { name: name, risk: risk, ts: now, watchSynced: synced };
    await LocalStore.get().setSetting(KEY_LAST, JSON.stringify(rec));
    log.info(`intake logged: ${name} (${risk}), watch ${synced ? 'told' : 'not reached'}`);
    return rec;
  }

  /** The last logged intake of any medicine, if it is still inside the watch window. */
  static async last(now: number): Promise<IntakeRecord | undefined> {
    try {
      const rec: IntakeRecord = JSON.parse(await LocalStore.get().getSetting(KEY_LAST, '{}')) as IntakeRecord;
      return typeof rec.name === 'string' && typeof rec.ts === 'number' && now - rec.ts < WATCH_WINDOW_MS ? rec :
        undefined;
    } catch (e) {
      return undefined;
    }
  }

  /** The last intake of this medicine if it is still inside the watch window (shown when the page reopens). */
  static async recent(name: string, now: number): Promise<IntakeRecord | undefined> {
    try {
      const rec: IntakeRecord = JSON.parse(await LocalStore.get().getSetting(KEY_LAST, '{}')) as IntakeRecord;
      if (typeof rec.name === 'string' && rec.name === name && typeof rec.ts === 'number' &&
        now - rec.ts < WATCH_WINDOW_MS) {
        return rec;
      }
    } catch (e) {
      log.warn(`bad saved intake: ${String(e)}`);
    }
    return undefined;
  }
}
