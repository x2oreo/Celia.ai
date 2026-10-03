import { describe, it, expect } from '@ohos/hypium';
import { BriefSection, briefText, buildBrief } from '../main/ets/doctor/DoctorPrep';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { ScanRecord } from '../main/ets/model/ScanRecord';
import { AppEvent } from '../main/ets/model/AppEvent';
import { beatIntervalMs } from '../main/ets/bystander/Metronome';

function profile(): Profile {
  const p: Profile = { condition: 'LQTS', genotype: 'LQT1', hasIcd: false, notes: 'Allergic to penicillin',
    contacts: [] };
  return p;
}

const NOW: number = 1790000000000;

export default function doctorPrepTest() {
  describe('DoctorPrep', () => {
    it('dentistBriefMentionsAdrenalineAndFlaggedDrug', 0, () => {
      const meds: Medication[] = [
        { id: 1, name: 'Nadolol', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 },
        { id: 2, name: 'Cipralex', ingredient: 'escitalopram', dose: '', addedAt: 0 }
      ];
      const scans: ScanRecord[] = [
        { id: 3, ts: NOW - 86400000, via: 'TEXT', query: 'Klacid', ingredient: 'clarithromycin', risk: 'KNOWN_RISK',
          combo: 'CYP_INTERACTION' }
      ];
      const symptom: AppEvent = { id: 4, ts: NOW - 3600000, kind: 'SYMPTOM',
        detail: '{"symptom":"DIZZINESS","severity":3,"activity":"stairs"}' };
      const sections: BriefSection[] = buildBrief(profile(), meds, scans, [symptom], 'DENTIST', NOW);
      const text: string = briefText(sections, 'DENTIST', NOW);
      expect(text.includes('adrenaline')).assertTrue();
      expect(text.includes('clarithromycin')).assertTrue();
      expect(text.includes('Allergic to penicillin')).assertTrue();
      expect(text.includes('dizziness, severity 3/5, during stairs')).assertTrue();
      expect(text.includes('Cipralex — known risk of torsades')).assertTrue();
    });

    it('oldScansAreLeftOut', 0, () => {
      const scans: ScanRecord[] = [
        { id: 3, ts: NOW - 200 * 86400000, via: 'TEXT', query: 'Zofran', ingredient: 'ondansetron',
          risk: 'KNOWN_RISK', combo: 'NONE' }
      ];
      const text: string = briefText(buildBrief(profile(), [], scans, [], 'GP', NOW), 'GP', NOW);
      expect(text.includes('ondansetron')).assertFalse();
      expect(text.includes('None recorded')).assertTrue();
    });

    it('cprMetronomeIs110PerMinute', 0, () => {
      expect(beatIntervalMs(110)).assertEqual(545);
    });
  });
}
