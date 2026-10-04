// check_drug, get_my_meds, suggest_alternatives - all answers come from DrugChecker + ComboRules.

import { AgentTool, TurnState, action, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { checkDrugFull } from '../DrugCheckFlow';
import { DrugChecker } from '../../drugs/DrugChecker';
import { LocalStore } from '../../data/LocalStore';
import { DrugVerdict } from '../../model/DrugVerdict';
import { Medication } from '../../model/Medication';
import {
  AlternativesPayload, InteractionFinding, MedLinePayload, MedsPayload, VerdictCardPayload
} from '../../model/AgentTypes';

interface CheckDrugOutput {
  query: string;
  ingredient: string;
  verdict: string;
  combinedVerdict: string;
  reason: string;
  source: string;
  interactions: string[];
  instruction: string;
}

export class CheckDrugTool implements AgentTool {
  name: string = 'check_drug';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const name: string = argString(args, 'name', 80);
    if (name.length === 0) {
      return toolError('name is required');
    }
    const card: VerdictCardPayload = await checkDrugFull(name);
    turn.verdicts.push(card);
    turn.actions.push(action('SHOW_VERDICT', card));
    const out: CheckDrugOutput = {
      query: card.query,
      ingredient: card.ingredient,
      verdict: card.risk,
      combinedVerdict: card.combinedRisk,
      reason: card.reason,
      source: card.source,
      interactions: card.findings.map((f: InteractionFinding) => f.detail),
      instruction: 'A verdict card is already on screen. Explain combinedVerdict in plain words without changing it.'
    };
    return JSON.stringify(out);
  }
}


// The user's medicines, each with the list's risk. Shared by the tool and the offline agent.
export async function myMedsPayload(): Promise<MedsPayload> {
  const meds: Medication[] = await LocalStore.get().listMeds();
  const lines: MedLinePayload[] = [];
  for (const m of meds) {
    const v: DrugVerdict = await DrugChecker.get().check(m.ingredient !== '' ? m.ingredient : m.name);
    const line: MedLinePayload = { name: m.name, ingredient: m.ingredient, dose: m.dose, risk: v.risk };
    lines.push(line);
  }
  const out: MedsPayload = { medicines: lines };
  return out;
}

export class GetMyMedsTool implements AgentTool {
  name: string = 'get_my_meds';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const out: MedsPayload = await myMedsPayload();
    turn.actions.push(action('SHOW_MEDS', out));
    return JSON.stringify(out);
  }
}

// Candidate alternatives per risky ingredient. Every candidate is re-checked with DrugChecker at runtime and only
// returned if it is NOT_LISTED - so this table can never introduce a QT-risk drug, even if it is wrong.
interface AltGroup {
  members: string[];
  candidates: string[];
  note: string;
}

const ALT_GROUPS: AltGroup[] = [
  {
    members: ['clarithromycin', 'erythromycin', 'azithromycin', 'ciprofloxacin', 'levofloxacin', 'moxifloxacin'],
    candidates: ['amoxicillin', 'cefalexin', 'doxycycline'],
    note: 'Antibiotic choice depends on the infection and allergies - only a doctor can switch.'
  },
  {
    members: ['diphenhydramine', 'hydroxyzine'],
    candidates: ['cetirizine', 'loratadine'],
    note: 'For allergy symptoms.'
  },
  {
    members: ['pseudoephedrine', 'phenylephrine'],
    candidates: ['saline nasal spray'],
    note: 'Decongestant tablets act like adrenaline and are avoided in congenital LQTS.'
  },
  {
    members: ['ondansetron', 'domperidone', 'metoclopramide', 'granisetron'],
    candidates: [],
    note: 'Most anti-sickness medicines affect the QT interval; your doctor needs to choose one with you.'
  }
];

interface AlternativesOutput {
  forDrug: string;
  alternatives: string[];
  note: string;
}

export class SuggestAlternativesTool implements AgentTool {
  name: string = 'suggest_alternatives';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const query: string = argString(args, 'drug_name', 80);
    if (query.length === 0) {
      return toolError('drug_name is required');
    }
    const v: DrugVerdict = await DrugChecker.get().check(query);
    const group: AltGroup | undefined = ALT_GROUPS.find((g: AltGroup) => g.members.includes(v.ingredient));
    const verified: string[] = [];
    if (group !== undefined) {
      for (const c of group.candidates) {
        const cv: DrugVerdict = await DrugChecker.get().check(c);
        if (cv.risk === 'NOT_LISTED') {
          verified.push(cv.ingredient !== '' ? cv.ingredient : c);
        }
      }
    }
    const card: AlternativesPayload = {
      forDrug: v.ingredient !== '' ? v.ingredient : query,
      alternatives: verified,
      note: group !== undefined ? group.note : ''
    };
    turn.actions.push(action('SHOW_ALTERNATIVES', card));
    const out: AlternativesOutput = {
      forDrug: v.ingredient !== '' ? v.ingredient : query,
      alternatives: verified,
      note: verified.length > 0
        ? `${group !== undefined ? group.note + ' ' : ''}Mention only these, and only as options to discuss with a doctor.`
        : `${group !== undefined ? group.note + ' ' : ''}No verified alternatives in the list - do not suggest any.`
    };
    return JSON.stringify(out);
  }
}
