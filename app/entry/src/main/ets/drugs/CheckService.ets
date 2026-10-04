// One entry point for every medicine check in the UI: verdict + interaction with my meds + history log.
// Deterministic only. Screens, the widget and (later) intents call this instead of DrugChecker directly.

import { ComboVerdict, DrugVerdict, RiskLevel } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { ScanRecord, ScanVia } from '../model/ScanRecord';
import { LocalStore } from '../data/LocalStore';
import { DrugChecker } from './DrugChecker';
import { Listener, Listeners } from '../common/Listeners';
import { BarcodeResult, resolveBarcode } from './BarcodeService';
import { BoxInfo } from '../model/BoxInfo';
import { checkOnline } from './DrugCheckClient';
import { escalate } from '../safety/ComboRules';

export class CheckOutcome {
  verdict: DrugVerdict;
  combo: ComboVerdict;
  box: BoxInfo | undefined;   // set when the query was a box barcode we know
  combos: ComboVerdict[];     // every interaction with my medicines; combo is the first of them (or NONE)
  combinedRisk: RiskLevel;    // verdict.risk, one level up when anything interacts (never lower)

  constructor(verdict: DrugVerdict, combo: ComboVerdict, box: BoxInfo | undefined = undefined,
    combos: ComboVerdict[] | undefined = undefined) {
    this.verdict = verdict;
    this.combo = combo;
    this.box = box;
    this.combos = combos ?? (combo.kind === 'NONE' ? [] : [combo]);
    this.combinedRisk = this.combos.length > 0 ? escalate(verdict.risk) : verdict.risk;
  }
}

const NO_COMBO: ComboVerdict = { kind: 'NONE', drugs: [], enzyme: '', reason: '' };

function outcomeOf(resolved: Resolved, meds: Medication[]): CheckOutcome {
  const combos: ComboVerdict[] = DrugChecker.get().checkCombos(resolved.verdict, meds);
  return new CheckOutcome(resolved.verdict, combos.length > 0 ? combos[0] : NO_COMBO, resolved.box, combos);
}

export class Resolved {
  verdict: DrugVerdict;
  box: BoxInfo | undefined;

  constructor(verdict: DrugVerdict, box: BoxInfo | undefined) {
    this.verdict = verdict;
    this.box = box;
  }
}

export function boxLabel(box: BoxInfo): string {
  return box.strength.length > 0 ? `${box.brand} ${box.strength}` : box.brand;
}

export class CheckService {
  private static riskyChecks: Listeners<CheckOutcome> = new Listeners<CheckOutcome>();

  // Fires for KNOWN_RISK verdicts and any interaction - used to buzz the watch (F-33).
  static onRiskyCheck(cb: Listener<CheckOutcome>): () => void {
    return CheckService.riskyChecks.add(cb);
  }

  // A typed or scanned barcode number is resolved to the box first (F-36): its ingredients are checked, and the
  // box details travel with the outcome. Unknown barcodes are checked as typed (→ UNKNOWN_DRUG, never "safe").
  static async resolveQuery(query: string): Promise<Resolved> {
    if (/^[0-9]{8,14}$/.test(query.trim())) {
      const b: BarcodeResult = await resolveBarcode(query);
      if (b.box !== undefined) {
        return new Resolved(await CheckService.checkBox(b.box), b.box);
      }
    }
    const offline: DrugVerdict = await DrugChecker.get().check(query);
    return new Resolved(offline.risk === 'UNKNOWN_DRUG' ? await checkOnline(query, offline) : offline, undefined);
  }

  private static async checkBox(box: BoxInfo): Promise<DrugVerdict> {
    const offline: DrugVerdict = await DrugChecker.get().check(box.ingredients);
    const v: DrugVerdict = offline.risk === 'UNKNOWN_DRUG' ? await checkOnline(box.ingredients, offline) : offline;
    v.query = boxLabel(box);
    if (v.risk === 'UNKNOWN_DRUG') {
      // We know the box, just not (all of) its ingredients - say so precisely.
      v.reason = `We know this box, but ${box.ingredients} is not in our QT list yet, so we cannot say it is ` +
        'safe. Ask your pharmacist before taking it.';
    }
    return v;
  }

  static async run(query: string, via: ScanVia): Promise<CheckOutcome> {
    const resolved: Resolved = await CheckService.resolveQuery(query);
    const verdict: DrugVerdict = resolved.verdict;
    const meds: Medication[] = await LocalStore.get().listMeds();
    const outcome: CheckOutcome = outcomeOf(resolved, meds);
    const combo: ComboVerdict = outcome.combo;
    const record: ScanRecord = {
      id: 0,
      ts: Date.now(),
      via: via,
      query: query,
      ingredient: verdict.ingredient,
      risk: verdict.risk,
      combo: combo.kind
    };
    await LocalStore.get().logScan(record);
    await LocalStore.get().logEvent('DRUG_CHECK',
      JSON.stringify(record));
    if (verdict.risk === 'KNOWN_RISK' || combo.kind !== 'NONE') {
      CheckService.riskyChecks.emit(outcome);
    }
    return outcome;
  }

  // Re-evaluate without logging (e.g. opening an entry from history).
  static async peek(query: string): Promise<CheckOutcome> {
    const resolved: Resolved = await CheckService.resolveQuery(query);
    const meds: Medication[] = await LocalStore.get().listMeds();
    return outcomeOf(resolved, meds);
  }
}
