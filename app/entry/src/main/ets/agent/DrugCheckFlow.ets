// The one path for an agent-side medicine check: CheckService (main's UI path - barcode, offline dataset, online
// fallback, history log, watch buzz) plus ComboRules against the user's current medicines. Shared by the
// check_drug tool, the offline agent and the Celia intent, so the chat and the check screen never disagree.

import { DrugChecker } from '../drugs/DrugChecker';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { ComboVerdict, DrugVerdict } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { ScanVia } from '../model/ScanRecord';
import { InteractionFinding, VerdictCardPayload } from '../model/AgentTypes';
import { ComboResult, escalate, evaluateCombo } from '../safety/ComboRules';

export async function currentMedVerdicts(): Promise<DrugVerdict[]> {
  const meds: Medication[] = await LocalStore.get().listMeds();
  const out: DrugVerdict[] = [];
  for (const m of meds) {
    out.push(await DrugChecker.get().check(m.ingredient !== '' ? m.ingredient : m.name));
  }
  return out;
}

// DrugChecker.checkCombo's finding, unless ComboRules already reported the same pair.
function mergeCheckerCombo(findings: InteractionFinding[], combo: ComboVerdict): void {
  if (combo.kind === 'NONE' || combo.drugs.length < 2) {
    return;
  }
  const other: string = combo.drugs[1];
  const kind: string = combo.kind === 'CYP_INTERACTION' ? 'CYP_INHIBITION' : 'ADDITIVE_QT';
  if (findings.some((f: InteractionFinding) => f.withDrug === other && f.kind === kind)) {
    return;
  }
  const f: InteractionFinding = { kind: kind, withDrug: other, detail: combo.reason };
  findings.push(f);
}

export async function checkDrugFull(query: string, via: ScanVia = 'CHAT'): Promise<VerdictCardPayload> {
  const outcome: CheckOutcome = await CheckService.run(query, via);
  const verdict: DrugVerdict = outcome.verdict;
  const combo: ComboResult = evaluateCombo(verdict, await currentMedVerdicts());
  const findings: InteractionFinding[] = combo.findings;
  for (const c of outcome.combos) {
    mergeCheckerCombo(findings, c);
  }
  const card: VerdictCardPayload = {
    query: verdict.query,
    ingredient: verdict.ingredient,
    risk: verdict.risk,
    combinedRisk: findings.length > 0 ? escalate(verdict.risk) : verdict.risk,
    reason: verdict.reason,
    source: verdict.source,
    findings: findings
  };
  return card;
}
