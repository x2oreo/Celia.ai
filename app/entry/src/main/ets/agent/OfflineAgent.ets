// Deterministic agent used when the model is unreachable, times out or returns something invalid.
// Covers the core jobs with simple patterns so the app stays useful offline (airplane-mode demo).

import { AgentReply, MedLinePayload, MedsPayload, UiAction, VerdictCardPayload } from '../model/AgentTypes';
import { checkDrugFull } from './DrugCheckFlow';
import { verdictText } from './VerdictText';
import { TurnState, action } from './ToolTypes';
import { myMedsPayload } from './tools/DrugTools';
import {
  GetDoseStatusTool, GetTrendsTool, OpenRemindersTool, OpenSymptomLogTool, SymptomLine, SymptomLogOutput
} from './tools/CareTools';

export type OfflineIntent = 'CHECK_DRUG' | 'MY_MEDS' | 'EMERGENCY_CARD' | 'SCAN' | 'SYMPTOM_LOG' | 'DOSES' |
  'REMINDERS' | 'TRENDS' | 'UNKNOWN';

export interface ParsedIntent {
  intent: OfflineIntent;
  drug: string;
}

const DRUG_PATTERNS: RegExp[] = [
  /\b(offered|prescribed|given|told to take)\s+([^.?!,]+)/,
  /\bcan i (take|use|have)\s+(.+)/,
  /\bis\s+(.+?)\s+(safe|ok|okay|risky|dangerous)\b/,
  /\b(check|what about|how about|tell me about)\s+(.+)/,
  /\bczy mogę (wziąć|brać|przyjąć)\s+(.+)/
];

// "Is it safe?" — a pronoun is never a medicine name; keep looking (or fall through to UNKNOWN).
const PRONOUNS: string[] = ['it', 'this', 'that', 'they', 'them', 'these', 'those', 'he', 'she'];

const TRAILING: RegExp = /\b(for me|please|now|today|with my (meds|medicines|medication))\b.*$/;

function cleanDrug(s: string): string {
  return s.replace(TRAILING, '').replace(/[?.!,]+/g, ' ').trim().slice(0, 80);
}

export function parseOfflineIntent(text: string): ParsedIntent {
  const t: string = text.toLowerCase().trim();
  if (/\bemergency card\b|\bkarta\b/.test(t)) {
    const r: ParsedIntent = { intent: 'EMERGENCY_CARD', drug: '' };
    return r;
  }
  // Pages the agent opens. Checked before the medicine patterns: "check my reminders" is not a medicine.
  if (/\bsymptom (log|history|diary)\b|\b(my|past|previous|recent|logged) symptoms\b/.test(t)) {
    const r: ParsedIntent = { intent: 'SYMPTOM_LOG', drug: '' };
    return r;
  }
  if (/\b(did i|have i) (take|taken|had|have)\b|\bdoses? (due|today|left)\b|\bwhat(('|’)s| is) due\b|\bmissed (a |my )?dose\b/
    .test(t)) {
    const r: ParsedIntent = { intent: 'DOSES', drug: '' };
    return r;
  }
  if (/\breminders?\b|\bremind me\b/.test(t)) {
    const r: ParsedIntent = { intent: 'REMINDERS', drug: '' };
    return r;
  }
  if (/\btrends?\b|\bhow have i been\b|\b(last|past) (two weeks|14 days|30 days|month)\b/.test(t)) {
    const r: ParsedIntent = { intent: 'TRENDS', drug: '' };
    return r;
  }
  if (/\b(scan|photo|picture|camera|look at)\b/.test(t)) {
    const r: ParsedIntent = { intent: 'SCAN', drug: '' };
    return r;
  }
  if (/\bmy (current |own |daily )?(meds|medicines|medications|pills)\b/.test(t)) {
    const r: ParsedIntent = { intent: 'MY_MEDS', drug: '' };
    return r;
  }
  let pronoun: boolean = false;
  for (const p of DRUG_PATTERNS) {
    const m: RegExpExecArray | null = p.exec(t);
    if (m !== null) {
      // The drug is always in the last capture group that holds more than a verb.
      const raw: string = m.length > 2 && m[2] !== undefined && !/^(safe|ok|okay|risky|dangerous)$/.test(m[2])
        ? m[2] : m[1];
      const drug: string = cleanDrug(raw);
      if (drug.length > 0 && !PRONOUNS.includes(drug)) {
        const r: ParsedIntent = { intent: 'CHECK_DRUG', drug: drug };
        return r;
      }
      pronoun = pronoun || PRONOUNS.includes(drug);
    }
  }
  // A short message is often just a medicine name ("Klacid", "ibuprofen 400").
  const smallTalk: boolean = /^(hi|hello|hey|thanks|thank you|ok|okay|yes|no|cześć|dzięki)\b/.test(t);
  if (!smallTalk && !pronoun && t.split(/\s+/).length <= 3 && t.length > 2) {
    const r: ParsedIntent = { intent: 'CHECK_DRUG', drug: cleanDrug(t) };
    return r;
  }
  const r: ParsedIntent = { intent: 'UNKNOWN', drug: '' };
  return r;
}

interface DoseLineOut {
  medicine: string;
  time: string;
  status: string;
}

interface DoseListOut {
  doses: DoseLineOut[];
}

interface ReminderLineOut {
  medicine: string;
  time: string;
}

interface ReminderListOut {
  reminders: ReminderLineOut[];
}

function daysAgoText(d: number): string {
  return d === 0 ? 'today' : (d === 1 ? 'yesterday' : `${d} days ago`);
}

// Fixed sentences for the page intents, built from the same tool output the model would get.
export function symptomLogText(out: SymptomLogOutput): string {
  if (out.entriesLast30Days === 0) {
    return 'You have no symptoms logged in the last 30 days. You can add one in the symptom log.';
  }
  const last: SymptomLine = out.recent[0];
  const n: number = out.entriesLast30Days;
  return `You logged ${n} ${n === 1 ? 'symptom' : 'symptoms'} in the last 30 days. The most recent: ` +
    `${last.symptom.toLowerCase()}, ${daysAgoText(last.daysAgo)}. The full log is one tap away.`;
}

export function dosesText(doses: DoseLineOut[]): string {
  if (doses.length === 0) {
    return 'No reminders are set, so I have no doses to show. You can add one on the reminders screen.';
  }
  return `Today's doses: ${doses.map((d: DoseLineOut) =>
    `${d.medicine} ${d.time} ${d.status.toLowerCase()}`).join(', ')}. You can mark a dose on the reminders screen.`;
}

export function remindersText(reminders: ReminderLineOut[]): string {
  if (reminders.length === 0) {
    return 'No reminders are set yet. You can add one on the reminders screen.';
  }
  return `Your reminders: ${reminders.map((r: ReminderLineOut) => `${r.medicine} at ${r.time}`).join(', ')}. ` +
    'You can change them on the reminders screen.';
}

function reply(text: string, actions: UiAction[]): AgentReply {
  const r: AgentReply = { text: text, actions: actions, fallback: true };
  return r;
}

export class OfflineAgent {
  // prefix: why we are offline, e.g. "I can't reach my assistant service right now."
  static async answer(text: string, prefix: string): Promise<AgentReply> {
    const parsed: ParsedIntent = parseOfflineIntent(text);
    switch (parsed.intent) {
      case 'CHECK_DRUG': {
        const card: VerdictCardPayload = await checkDrugFull(parsed.drug);
        return reply(verdictText(card), [action('SHOW_VERDICT', card)]);
      }
      case 'MY_MEDS': {
        const meds: MedsPayload = await myMedsPayload();
        const list: string = meds.medicines.length === 0 ? 'You have no medicines saved yet.'
          : `Your medicines: ${meds.medicines.map((m: MedLinePayload) =>
            m.dose !== '' ? `${m.name} ${m.dose}` : m.name).join(', ')}.`;
        return reply(list, [action('SHOW_MEDS', meds)]);
      }
      case 'EMERGENCY_CARD': {
        const a: UiAction = { type: 'SHOW_EMERGENCY_CARD', payload: '{"language":""}' };
        return reply('Here is your emergency card.', [a]);
      }
      case 'SCAN': {
        const a: UiAction = { type: 'OPEN_MED_SCAN', payload: '{}' };
        return reply('Point the camera at the medicine box.', [a]);
      }
      case 'SYMPTOM_LOG': {
        const turn: TurnState = new TurnState();
        const out: string = await new OpenSymptomLogTool().execute({}, turn);
        return reply(symptomLogText(JSON.parse(out) as SymptomLogOutput), turn.actions);
      }
      case 'DOSES': {
        const turn: TurnState = new TurnState();
        const out: string = await new GetDoseStatusTool().execute({}, turn);
        return reply(dosesText((JSON.parse(out) as DoseListOut).doses), turn.actions);
      }
      case 'REMINDERS': {
        const turn: TurnState = new TurnState();
        const out: string = await new OpenRemindersTool().execute({}, turn);
        return reply(remindersText((JSON.parse(out) as ReminderListOut).reminders), turn.actions);
      }
      case 'TRENDS': {
        const turn: TurnState = new TurnState();
        await new GetTrendsTool().execute({}, turn);
        return reply('Your resting heart rate, doses and symptoms by day are one tap away.', turn.actions);
      }
      default:
        return reply(`${prefix} I can still check medicines — try "Can I take ibuprofen?" — show your emergency ` +
          'card, scan a medicine box, or open your reminders, symptom log and trends.', []);
    }
  }
}
