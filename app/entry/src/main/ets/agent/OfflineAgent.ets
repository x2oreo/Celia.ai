// Deterministic agent used when the model is unreachable, times out or returns something invalid.
// Covers the core jobs with simple patterns so the app stays useful offline (airplane-mode demo).

import { AgentReply, UiAction, VerdictCardPayload } from '../model/AgentTypes';
import { checkDrugFull } from './DrugCheckFlow';
import { verdictText } from './VerdictText';
import { action } from './ToolTypes';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';

export type OfflineIntent = 'CHECK_DRUG' | 'MY_MEDS' | 'EMERGENCY_CARD' | 'SCAN' | 'UNKNOWN';

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
  if (/\b(scan|photo|picture|camera|look at)\b/.test(t)) {
    const r: ParsedIntent = { intent: 'SCAN', drug: '' };
    return r;
  }
  if (/\bmy (meds|medicines|medications|pills)\b/.test(t)) {
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
        const meds: Medication[] = await LocalStore.get().listMeds();
        const list: string = meds.length === 0 ? 'You have no medicines saved yet.'
          : `Your medicines: ${meds.map((m: Medication) => m.dose !== '' ? `${m.name} ${m.dose}` : m.name).join(', ')}.`;
        return reply(list, []);
      }
      case 'EMERGENCY_CARD': {
        const a: UiAction = { type: 'SHOW_EMERGENCY_CARD', payload: '{"language":""}' };
        return reply('Here is your emergency card.', [a]);
      }
      case 'SCAN': {
        const a: UiAction = { type: 'OPEN_MED_SCAN', payload: '{}' };
        return reply('Point the camera at the medicine box.', [a]);
      }
      default:
        return reply(`${prefix} I can still check medicines — try "Can I take ibuprofen?" — show your emergency ` +
          'card, or scan a medicine box.', []);
    }
  }
}
