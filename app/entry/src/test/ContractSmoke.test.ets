// Smoke tests for the day-1 stubs. Pattern for real tests (DrugChecker, AlarmRules, ResponseValidator):
// keep logic in plain .ets classes without UI so it runs here, locally, without a device.

import { describe, it, expect } from '@ohos/hypium';
import { DrugChecker } from '../main/ets/drugs/DrugChecker';
import { LocalStore } from '../main/ets/data/LocalStore';
import { DrugVerdict } from '../main/ets/model/DrugVerdict';
import { Medication } from '../main/ets/model/Medication';
import { Profile } from '../main/ets/model/Profile';
import { Listeners } from '../main/ets/common/Listeners';

export default function contractSmokeTest() {
  describe('ContractSmoke', () => {
    it('unknownDrugIsNeverSafe', 0, async () => {
      const v: DrugVerdict = await DrugChecker.get().check('xyzzy-not-a-drug');
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
      expect(v.ingredient).assertEqual('');
    });

    it('emptyQueryIsUnknown', 0, async () => {
      const v: DrugVerdict = await DrugChecker.get().check('  500 mg ');
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
    });

    it('knownDrugWithDoseResolves', 0, async () => {
      const v: DrugVerdict = await DrugChecker.get().check('Paracetamol 500 mg tablets');
      expect(v.risk).assertEqual('NOT_LISTED');
      expect(v.ingredient).assertEqual('paracetamol');
    });

    it('harmlessDrugNeverHidesRiskyOne', 0, async () => {
      const v: DrugVerdict = await DrugChecker.get().check('paracetamol + clarithromycin');
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(v.ingredient).assertEqual('clarithromycin');
    });

    it('unrecognisedTokenBlocksNotListed', 0, async () => {
      const v: DrugVerdict = await DrugChecker.get().check('Paracetamol + azithromycin');
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
    });

    it('localStoreStartsEmpty', 0, async () => {
      // Fresh instance on purpose: the app singleton may already hold state from other tests.
      const store: LocalStore = new LocalStore();
      const profile: Profile | undefined = await store.getProfile();
      const meds: Medication[] = await store.listMeds();
      expect(profile === undefined).assertTrue();
      expect(meds.length).assertEqual(0);
    });

    it('listenersUnsubscribe', 0, () => {
      const l: Listeners<number> = new Listeners<number>();
      let sum: number = 0;
      const off = l.add((n: number) => {
        sum += n;
      });
      l.emit(2);
      off();
      l.emit(5);
      expect(sum).assertEqual(2);
    });
  });
}
