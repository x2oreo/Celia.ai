// Review of the user's current medicines as a whole: risk counts and interactions between them (F-24).

import { ComboVerdict, DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { DrugChecker } from './DrugChecker';

export class RiskCounts {
  known: number = 0;
  possible: number = 0;
  conditional: number = 0;
  notListed: number = 0;
  unknown: number = 0;

  add(risk: RiskLevel): void {
    switch (risk) {
      case 'KNOWN_RISK':
        this.known++;
        break;
      case 'POSSIBLE_RISK':
        this.possible++;
        break;
      case 'CONDITIONAL_RISK':
        this.conditional++;
        break;
      case 'NOT_LISTED':
        this.notListed++;
        break;
      default:
        this.unknown++;
        break;
    }
  }

  total(): number {
    return this.known + this.possible + this.conditional + this.notListed + this.unknown;
  }
}

function verdictOf(m: Medication): DrugVerdict {
  return DrugChecker.get().checkSync(m.ingredient !== '' ? m.ingredient : m.name);
}

export function riskCounts(meds: Medication[]): RiskCounts {
  const c: RiskCounts = new RiskCounts();
  for (const m of meds) {
    c.add(verdictOf(m).risk);
  }
  return c;
}

// Every interacting pair among my medicines, each pair once, CYP interactions first.
export function medsInteractions(meds: Medication[]): ComboVerdict[] {
  const out: ComboVerdict[] = [];
  const seen: string[] = [];
  for (let i = 0; i < meds.length; i++) {
    const v: DrugVerdict = verdictOf(meds[i]);
    for (let j = i + 1; j < meds.length; j++) {
      const combo: ComboVerdict = DrugChecker.get().checkCombo(v, [meds[j]]);
      if (combo.kind === 'NONE') {
        continue;
      }
      const key: string = combo.drugs.slice().sort().join('+');
      if (!seen.includes(key)) {
        seen.push(key);
        out.push(combo);
      }
    }
  }
  out.sort((a: ComboVerdict, b: ComboVerdict) => (a.kind === 'CYP_INTERACTION' ? 0 : 1) -
    (b.kind === 'CYP_INTERACTION' ? 0 : 1));
  return out;
}
