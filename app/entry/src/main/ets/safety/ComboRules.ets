// OWNER: Kaloyan — deterministic interaction rules. The LLM explains these findings; it never computes them.
//
// Rules (simplified, conservative — decision support, not a clinical interaction checker):
//   ADDITIVE_QT     new drug and a current drug are both on a QT-risk list (known/possible/conditional)
//   CYP_INHIBITION  one drug inhibits the enzyme that clears a QT-risk drug in the pair → higher levels
//   MANY_QT_DRUGS   three or more QT-risk drugs in total
// Any finding escalates the combined risk by one level. UNKNOWN_DRUG is never escalated or lowered.
//
// Enzyme data: the bundled dataset (drugs/DrugDataset.ets: cypInhibitor / cypSubstrate) — the same table the
// check screen uses through DrugChecker.checkCombos, so the chat and the screens cannot disagree.

import { DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { InteractionFinding } from '../model/AgentTypes';
import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';

export interface ComboResult {
  combinedRisk: RiskLevel;
  findings: InteractionFinding[];
}

export function isQtRisk(risk: RiskLevel): boolean {
  return risk === 'KNOWN_RISK' || risk === 'POSSIBLE_RISK' || risk === 'CONDITIONAL_RISK';
}

export function escalate(risk: RiskLevel): RiskLevel {
  switch (risk) {
    case 'NOT_LISTED':
    case 'CONDITIONAL_RISK':
      return 'POSSIBLE_RISK';
    case 'POSSIBLE_RISK':
      return 'KNOWN_RISK';
    default:
      return risk; // KNOWN_RISK stays, UNKNOWN_DRUG stays (never turns into a listed category)
  }
}

function finding(kind: string, withDrug: string, detail: string): InteractionFinding {
  const f: InteractionFinding = { kind: kind, withDrug: withDrug, detail: detail };
  return f;
}

// "a" raises the level of "b" if a inhibits an enzyme that clears b and b is a QT-risk drug.
function cypFinding(a: DrugVerdict, b: DrugVerdict): InteractionFinding | undefined {
  if (a.ingredient === '' || b.ingredient === '' || !isQtRisk(b.risk)) {
    return undefined;
  }
  const inhibitor: DrugEntry | undefined = DrugChecker.get().entry(a.ingredient);
  const substrate: DrugEntry | undefined = DrugChecker.get().entry(b.ingredient);
  if (inhibitor === undefined || substrate === undefined) {
    return undefined;
  }
  for (const enzyme of inhibitor.cypInhibitor) {
    if (substrate.cypSubstrate.includes(enzyme)) {
      return finding('CYP_INHIBITION', '',
        `${a.ingredient} slows the breakdown of ${b.ingredient} (${enzyme}), which can raise its level and ` +
          'its effect on the QT interval.');
    }
  }
  return undefined;
}

// newDrug: verdict for the medicine being checked. current: verdicts for the user's current medicines.
export function evaluateCombo(newDrug: DrugVerdict, current: DrugVerdict[]): ComboResult {
  const findings: InteractionFinding[] = [];
  const others: DrugVerdict[] = current.filter((c: DrugVerdict) =>
    c.ingredient === '' || c.ingredient !== newDrug.ingredient);

  for (const med of others) {
    const name: string = med.ingredient !== '' ? med.ingredient : med.query;
    if (isQtRisk(newDrug.risk) && isQtRisk(med.risk)) {
      findings.push(finding('ADDITIVE_QT', name,
        `Both ${newDrug.ingredient} and ${name} are on QT-risk lists; together their effects can add up.`));
    }
    const forward: InteractionFinding | undefined = cypFinding(newDrug, med);
    const backward: InteractionFinding | undefined = cypFinding(med, newDrug);
    const cyp: InteractionFinding | undefined = forward ?? backward;
    if (cyp !== undefined) {
      cyp.withDrug = name;
      findings.push(cyp);
    }
  }

  const qtCount: number = others.filter((c: DrugVerdict) => isQtRisk(c.risk)).length +
    (isQtRisk(newDrug.risk) ? 1 : 0);
  if (qtCount >= 3) {
    findings.push(finding('MANY_QT_DRUGS', '',
      `This would make ${qtCount} medicines on QT-risk lists at the same time.`));
  }

  const combined: RiskLevel = findings.length > 0 ? escalate(newDrug.risk) : newDrug.risk;
  const result: ComboResult = { combinedRisk: combined, findings: findings };
  return result;
}
