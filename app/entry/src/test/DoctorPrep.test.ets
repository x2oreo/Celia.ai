import { describe, it, expect } from '@ohos/hypium';
import { BriefSection, briefText, buildBrief } from '../main/ets/doctor/DoctorPrep';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { ScanRecord } from '../main/ets/model/ScanRecord';
import { AppEvent } from '../main/ets/model/AppEvent';
import { beatIntervalMs } from '../main/ets/bystander/Metronome';
import { parseSummary, summaryFields } from '../main/ets/doctor/DoctorSummary';

function profile(): Profile {
  const p: Profile = { condition: 'LQTS', genotype: 'LQT1', hasIcd: false, notes: 'Allergic to penicillin',
    contacts: [] };
  return p;
}

const NOW: number = 1790000000000;

export default function doctorPrepTest() {
  describe('DoctorSummary', () => {
    it('sendsNoNameNotesOrSymptomText', 0, () => {
      const p: Profile = profile();
      p.name = 'Anna Kowalska';
      const meds: Medication[] = [
        { id: 1, name: 'Nadolol', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 } as Medication
      ];
      const symptom: AppEvent = { id: 9, ts: NOW - 1000, kind: 'SYMPTOM',
        detail: '{"symptom":"DIZZINESS","severity":2,"activity":"resting","note":"after my sister called","hrMin":-1,"hrMax":-1}' };
      const sections: BriefSection[] = buildBrief(p, meds, [], [symptom], 'DENTIST', NOW);
      const fields: Record<string, string> = summaryFields(sections, 'DENTIST', p.genotype);
      const all: string = Object.keys(fields).map((k: string) => fields[k]).join(' ');
      expect(all.includes('Anna')).assertFalse();
      expect(all.includes('penicillin')).assertFalse();
      expect(all.includes('sister')).assertFalse();
      expect(fields['medicines'].includes('Nadolol')).assertTrue();
      expect(fields['symptoms']).assertEqual('1');
    });

    it('rejectsReassuranceAndDoses', 0, () => {
      expect(parseSummary('{"summary":"Clarithromycin is safe for this patient with LQT2."}').result)
        .assertEqual('REJECTED');
      expect(parseSummary('{"summary":"Continue nadolol 40 mg daily as prescribed for LQT1."}').result)
        .assertEqual('REJECTED');
      expect(parseSummary('{"summary":"",' + '"dropped":true}').result).assertEqual('REJECTED');
      expect(parseSummary('oops').result).assertEqual('REJECTED');
      const ok: string = '{"summary":"LQT1 patient on nadolol; one flagged antibiotic in the last 90 days."}';
      expect(parseSummary(ok).result).assertEqual('OK');
    });
  });

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
