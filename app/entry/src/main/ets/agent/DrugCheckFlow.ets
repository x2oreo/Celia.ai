// The one path for checking a medicine: DrugChecker (Mark) + ComboRules against the user's current medicines.
// Shared by the check_drug tool, the offline agent, the photo flow and the Celia intent — one verdict everywhere.

import { DrugChecker } from '../drugs/DrugChecker';
import { LocalStore } from '../data/LocalStore';
import { DrugVerdict } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { VerdictCardPayload } from '../model/AgentTypes';
import { ComboResult, evaluateCombo } from '../safety/ComboRules';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('DrugCheckFlow');

interface DrugCheckEvent {
  query: string;
  ingredient: string;
  risk: string;
  combinedRisk: string;
  findings: number;
}

export async function currentMedVerdicts(): Promise<DrugVerdict[]> {
  const meds: Medication[] = await LocalStore.get().listMeds();
  const out: DrugVerdict[] = [];
  for (const m of meds) {
    out.push(await DrugChecker.get().check(m.ingredient !== '' ? m.ingredient : m.name));
  }
  return out;
}

export async function checkDrugFull(query: string): Promise<VerdictCardPayload> {
  const verdict: DrugVerdict = await DrugChecker.get().check(query);
  const combo: ComboResult = evaluateCombo(verdict, await currentMedVerdicts());
  const card: VerdictCardPayload = {
    query: verdict.query,
    ingredient: verdict.ingredient,
    risk: verdict.risk,
    combinedRisk: combo.combinedRisk,
    reason: verdict.reason,
    source: verdict.source,
    findings: combo.findings
  };
  const event: DrugCheckEvent = {
    query: query,
    ingredient: card.ingredient,
    risk: card.risk,
    combinedRisk: card.combinedRisk,
    findings: card.findings.length
  };
  try {
    await LocalStore.get().logEvent('DRUG_CHECK', JSON.stringify(event));
  } catch (e) {
    log.warn(`logEvent failed: ${String(e)}`);
  }
  return card;
}
