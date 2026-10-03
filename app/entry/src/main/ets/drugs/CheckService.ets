// One entry point for every medicine check in the UI: verdict + interaction with my meds + history log.
// Deterministic only. Screens, the widget and (later) intents call this instead of DrugChecker directly.

import { ComboVerdict, DrugVerdict } from '../model/DrugVerdict';
import { Medication } from '../model/Medication';
import { ScanRecord, ScanVia } from '../model/ScanRecord';
import { LocalStore } from '../data/LocalStore';
import { DrugChecker } from './DrugChecker';
import { Listener, Listeners } from '../common/Listeners';
import { BarcodeResult, resolveBarcode } from './BarcodeService';
import { checkOnline } from './DrugCheckClient';

export class CheckOutcome {
  verdict: DrugVerdict;
  combo: ComboVerdict;

  constructor(verdict: DrugVerdict, combo: ComboVerdict) {
    this.verdict = verdict;
    this.combo = combo;
  }
}

export class CheckService {
  private static riskyChecks: Listeners<CheckOutcome> = new Listeners<CheckOutcome>();

  // Fires for KNOWN_RISK verdicts and any interaction — used to buzz the watch (F-33).
  static onRiskyCheck(cb: Listener<CheckOutcome>): () => void {
    return CheckService.riskyChecks.add(cb);
  }

  // A typed or scanned barcode number is resolved to the ingredient first (F-36).
  static async resolveQuery(query: string): Promise<DrugVerdict> {
    if (/^[0-9]{8,14}$/.test(query.trim())) {
      const b: BarcodeResult = resolveBarcode(query);
      if (b.entry !== undefined) {
        const v: DrugVerdict = await DrugChecker.get().check(b.entry.ingredient);
        v.query = b.entry.product;
        return v;
      }
    }
    const offline: DrugVerdict = await DrugChecker.get().check(query);
    return offline.risk === 'UNKNOWN_DRUG' ? checkOnline(query, offline) : offline;
  }

  static async run(query: string, via: ScanVia): Promise<CheckOutcome> {
    const verdict: DrugVerdict = await CheckService.resolveQuery(query);
    const meds: Medication[] = await LocalStore.get().listMeds();
    const combo: ComboVerdict = DrugChecker.get().checkCombo(verdict, meds);
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
    const outcome: CheckOutcome = new CheckOutcome(verdict, combo);
    if (verdict.risk === 'KNOWN_RISK' || combo.kind !== 'NONE') {
      CheckService.riskyChecks.emit(outcome);
    }
    return outcome;
  }

  // Re-evaluate without logging (e.g. opening an entry from history).
  static async peek(query: string): Promise<CheckOutcome> {
    const verdict: DrugVerdict = await CheckService.resolveQuery(query);
    const meds: Medication[] = await LocalStore.get().listMeds();
    return new CheckOutcome(verdict, DrugChecker.get().checkCombo(verdict, meds));
  }
}
