import { describe, it, expect } from '@ohos/hypium';
import {
  AvoidGroup, InsteadGroup, MedRow, STIMULANT_GROUP_TITLE, ageYears, careNotes, doNotGive, medRows,
  recentRiskyIntake, useInstead
} from '../main/ets/emergency/Responder';
import { DRUGS, DrugEntry } from '../main/ets/drugs/DrugDataset';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { IntakeRecord } from '../main/ets/drugs/DrugIntake';

function allAvoided(groups: AvoidGroup[]): string[] {
  const out: string[] = [];
  groups.forEach((g: AvoidGroup) => g.drugs.forEach((d: string) => out.push(d)));
  return out;
}

function med(id: number, name: string, ingredient: string, dose: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: dose, addedAt: 0 };
  return m;
}

function profile(genotype: string, hasIcd: boolean, icdModel: string): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: genotype === 'LQT2' ? 'LQT2' : genotype === 'LQT1' ? 'LQT1' : 'UNKNOWN',
    hasIcd: hasIcd, icdModel: icdModel, notes: '', contacts: []
  };
  return p;
}

export default function responderTest() {
  describe('Responder', () => {
    it('doNotGiveHasEveryKnownRiskAndCongenitalDrugOnce', 0, () => {
      const avoided: string[] = allAvoided(doNotGive());
      DRUGS.forEach((e: DrugEntry) => {
        const expected: boolean = e.risk === 'KNOWN_RISK' || e.avoidCongenital;
        expect(avoided.includes(e.ingredient)).assertEqual(expected);
      });
      expect(new Set<string>(avoided).size).assertEqual(avoided.length);
      expect(avoided.includes('ibuprofen')).assertFalse();
      expect(avoided.includes('venlafaxine')).assertFalse();   // Possible risk: not on this list
    });

    it('antiemeticsThenStimulantsComeFirst', 0, () => {
      const g: AvoidGroup[] = doNotGive();
      expect(g[0].title).assertEqual('Antiemetics');
      expect(g[0].drugs.includes('ondansetron')).assertTrue();
      expect(g[0].drugs.includes('domperidone')).assertTrue();
      expect(g[0].drugs.includes('droperidol')).assertTrue();
      expect(g[1].title).assertEqual(STIMULANT_GROUP_TITLE);
      expect(g[1].drugs.includes('adrenaline')).assertTrue();
      expect(g[1].note.includes('unless life-saving')).assertTrue();
      expect(g.some((x: AvoidGroup) => x.title === 'Macrolide antibiotic' && x.drugs.includes('clarithromycin')))
        .assertTrue();
    });

    it('useInsteadIsGroupedByWhatItReplaces', 0, () => {
      const g: InsteadGroup[] = useInstead();
      const antibiotics: InsteadGroup | undefined = g.find((x: InsteadGroup) => x.replaces.includes('clarithromycin'));
      expect(antibiotics !== undefined).assertTrue();
      expect(antibiotics?.replaces.includes('ciprofloxacin')).assertTrue();
      expect(antibiotics?.classes.includes('Fluoroquinolone antibiotic')).assertTrue();
      expect(antibiotics?.options.includes('amoxicillin')).assertTrue();
      const pain: InsteadGroup | undefined = g.find((x: InsteadGroup) => x.replaces.includes('tramadol'));
      expect(pain?.options[0]).assertEqual('paracetamol');
      // Every option is itself not on the QT lists.
      g.forEach((x: InsteadGroup) => x.options.forEach((o: string) => {
        const e: DrugEntry | undefined = DRUGS.find((d: DrugEntry) => d.ingredient === o);
        expect(e?.risk).assertEqual('NOT_LISTED');
      }));
      // Each risky drug appears in at most one group.
      const seen: string[] = [];
      g.forEach((x: InsteadGroup) => x.replaces.forEach((r: string) => {
        expect(seen.includes(r)).assertFalse();
        seen.push(r);
      }));
    });

    it('careNotesFollowTheProfile', 0, () => {
      const meds: Medication[] = [med(1, 'Corgard', 'nadolol', '40 mg'), med(2, 'Ventolin', 'salbutamol', '')];
      const lqt2: string[] = careNotes(profile('LQT2', true, 'Medtronic Visia AF'), meds, '999');
      expect(lqt2[0].includes('call 999')).assertTrue();
      expect(lqt2.some((n: string) => n.includes('magnesium sulfate'))).assertTrue();
      expect(lqt2.some((n: string) => n.includes('ICD): Medtronic Visia AF'))).assertTrue();
      expect(lqt2.some((n: string) => n.startsWith('Beta-blocker: Corgard (nadolol) 40 mg'))).assertTrue();
      expect(lqt2.some((n: string) => n.includes('sudden loud noise'))).assertTrue();
      const unknown: string[] = careNotes(profile('UNKNOWN', false, ''), [], '112');
      expect(unknown.some((n: string) => n.includes('ICD'))).assertFalse();
      expect(unknown.some((n: string) => n.startsWith('Beta-blocker'))).assertFalse();
      expect(unknown.some((n: string) => n.startsWith('Typical trigger'))).assertFalse();
    });

    it('medRowsCarryTheDatasetRisk', 0, () => {
      const rows: MedRow[] = medRows([med(1, 'Klacid', 'clarithromycin', '500 mg'), med(2, 'Ventolin', '', ''),
        med(3, 'Herbal tea', '', '')]);
      expect(rows[0].risk).assertEqual('KNOWN_RISK');
      expect(rows[0].line).assertEqual('Klacid (clarithromycin) 500 mg');
      expect(rows[1].avoidCongenital).assertTrue();
      expect(rows[2].risk).assertEqual('UNKNOWN_DRUG');
    });

    it('ageAndRecentIntake', 0, () => {
      const now: number = new Date(2026, 9, 4, 10, 0).getTime();
      expect(ageYears('1990-10-04', now)).assertEqual(36);
      expect(ageYears('1990-10-05', now)).assertEqual(35);
      expect(ageYears('04.10.1990', now) === undefined).assertTrue();
      expect(ageYears('2030-01-01', now) === undefined).assertTrue();
      expect(ageYears(undefined, now) === undefined).assertTrue();
      const recent: IntakeRecord = { name: 'clarithromycin', risk: 'KNOWN_RISK', ts: now - 3600000, watchSynced: false };
      const hourAgo: string = JSON.stringify(recent);
      expect(recentRiskyIntake(hourAgo, now)?.name).assertEqual('clarithromycin');
      const stale: IntakeRecord = { name: 'clarithromycin', risk: 'KNOWN_RISK', ts: now - 4 * 86400000,
        watchSynced: false };
      const old: string = JSON.stringify(stale);
      expect(recentRiskyIntake(old, now) === undefined).assertTrue();
      expect(recentRiskyIntake('{}', now) === undefined).assertTrue();
      expect(recentRiskyIntake('oops', now) === undefined).assertTrue();
    });
  });
}
