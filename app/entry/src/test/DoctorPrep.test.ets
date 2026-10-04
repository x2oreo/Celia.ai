import { describe, it, expect } from '@ohos/hypium';
import { BriefSection, briefText, buildBrief } from '../main/ets/doctor/DoctorPrep';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { ScanRecord } from '../main/ets/model/ScanRecord';
import { AppEvent } from '../main/ets/model/AppEvent';
import { beatIntervalMs } from '../main/ets/bystander/Metronome';
import { parseSummary, summaryFields } from '../main/ets/doctor/DoctorSummary';
import {
  AvoidDrug, cautionNames, guessPurposes, knownNames, PlanGroup, visitPlan, visitText
} from '../main/ets/doctor/VisitPlan';
import { DoctorVisit, parseVisits, visitWhen } from '../main/ets/doctor/VisitStore';
import { ReportVisit, reportVisit } from '../main/ets/doctor/ReportPayload';

function profile(): Profile {
  const p: Profile = { condition: 'LQTS', genotype: 'LQT1', hasIcd: false, notes: 'Allergic to penicillin',
    contacts: [] };
  return p;
}

const NOW: number = 1790000000000;

export default function doctorPrepTest() {
  describe('DoctorSummary', () => {
    it('keepsTheVisitDateAndWorries', 0, () => {
      const raw: string = JSON.stringify([
        { id: 2, specialty: 'DENTIST', createdAt: 100, date: '2026-10-20', worries: 'Dizzy when I stand' },
        { id: 1, specialty: 'GP', createdAt: 50, date: '20/10/2026' }
      ]);
      const visits: DoctorVisit[] = parseVisits(raw);
      expect(visits[0].date).assertEqual('2026-10-20');
      expect(visits[0].worries).assertEqual('Dizzy when I stand');
      expect(new Date(visitWhen(visits[0])).getDate()).assertEqual(20);
      expect(visits[1].date).assertEqual('');            // not YYYY-MM-DD: dropped
      expect(visitWhen(visits[1])).assertEqual(50);       // falls back to the day it was created
    });

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

  describe('DoctorVisits', () => {
    it('guessesThePurposeFromTheReason', 0, () => {
      expect(guessPurposes('Sore throat and fever for three days')).assertDeepEquals(['INFECTION', 'PAIN']);
      expect(guessPurposes('I keep throwing up').includes('NAUSEA')).assertTrue();
      expect(guessPurposes('routine check-up')).assertDeepEquals(['CHECKUP']);
      // matched at the start of a word only: "year" is not "ear", "scold" is not "cold"
      expect(guessPurposes('same as last year, do not scold me').length).assertEqual(0);
      expect(guessPurposes('').length).assertEqual(0);
    });

    it('infectionPlanFlagsMacrolidesAndOffersUnlistedAntibiotics', 0, () => {
      const plan: PlanGroup[] = visitPlan('sinus infection', 'GP');
      expect(plan[0].purpose).assertEqual('INFECTION');
      expect(plan[0].fromReason).assertTrue();
      const names: string[] = plan[0].avoid.map((a: AvoidDrug) => a.name);
      expect(names.includes('Clarithromycin')).assertTrue();
      expect(names.includes('Ciprofloxacin')).assertTrue();
      expect(names.includes('Amoxicillin')).assertFalse();
      expect(plan[0].options.includes('Amoxicillin')).assertTrue();
      // worst first, and nothing "not listed" is ever in the avoid list
      expect(plan[0].avoid[0].risk).assertEqual('KNOWN_RISK');
      for (const g of plan) {
        expect(g.avoid.some((a: AvoidDrug) => a.risk === 'NOT_LISTED')).assertFalse();
      }
    });

    it('fallsBackToWhatTheDoctorUsuallyPrescribes', 0, () => {
      const plan: PlanGroup[] = visitPlan('', 'PSYCHIATRIST');
      expect(plan.map((g: PlanGroup) => g.purpose)).assertDeepEquals(['MOOD', 'SLEEP']);
      expect(plan[0].fromReason).assertFalse();
      expect(knownNames(plan).includes('Citalopram')).assertTrue();
      expect(knownNames(plan).includes('Sertraline')).assertFalse();
      expect(cautionNames(plan).includes('Sertraline')).assertTrue();
      expect(visitPlan('toothache', 'DENTIST').length <= 4).assertTrue();
    });

    it('visitTextLeadsWithReasonAndAvoidList', 0, () => {
      const plan: PlanGroup[] = visitPlan('tooth extraction', 'DENTIST');
      const text: string = visitText('DENTIST', 'Dr Nowak', 'Tooth extraction', plan,
        buildBrief(profile(), [], [], [], 'DENTIST', NOW), NOW);
      expect(text.includes('Dr Nowak')).assertTrue();
      expect(text.indexOf('REASON FOR THE VISIT') < text.indexOf('PLEASE DO NOT PRESCRIBE')).assertTrue();
      expect(text.indexOf('PLEASE DO NOT PRESCRIBE') < text.indexOf('CURRENT MEDICINES')).assertTrue();
      expect(text.includes('Ondansetron')).assertTrue();
    });

    it('storedVisitsAreValidated', 0, () => {
      const raw: string = JSON.stringify([
        { id: 5, specialty: 'DENTIST', doctor: 'Dr A', reason: 'toothache', createdAt: 5, summary: '', sharedAt: 0 },
        { id: 9, specialty: 'GP', doctor: 7, reason: 'x', createdAt: 9 },
        { id: 9, specialty: 'GP', reason: 'duplicate id', createdAt: 10 },
        { id: 3, specialty: 'WIZARD', reason: 'x', createdAt: 3 },
        'nonsense', null
      ]);
      const visits: DoctorVisit[] = parseVisits(raw);
      expect(visits.length).assertEqual(2);
      expect(visits[0].id).assertEqual(9);        // newest first
      expect(visits[0].doctor).assertEqual('');
      expect(visits[0].sharedAt).assertEqual(0);
      expect(parseVisits('oops').length).assertEqual(0);
      expect(parseVisits('{"a":1}').length).assertEqual(0);
    });

    it('summarySendsPurposeTitlesNotTheReason', 0, () => {
      const reason: string = 'Sore throat since my sister visited';
      const plan: PlanGroup[] = visitPlan(reason, 'GP');
      const fields: Record<string, string> = summaryFields(buildBrief(profile(), [], [], [], 'GP', NOW), 'GP',
        'LQT1', plan);
      const all: string = Object.keys(fields).map((k: string) => fields[k]).join(' ');
      expect(all.includes('sister')).assertFalse();
      expect(fields['visitFor'].includes('Infection')).assertTrue();
      expect(fields['avoid'].includes('Clarithromycin')).assertTrue();
    });

    it('reportCarriesTheVisit', 0, () => {
      const v: ReportVisit = reportVisit('Dr Nowak', 'sinus infection', visitPlan('sinus infection', 'GP'), '');
      expect(v.reason).assertEqual('sinus infection');
      expect(v.groups[0].title).assertEqual('Infection');
      expect(v.groups[0].avoid[0].risk).assertEqual('KNOWN_RISK');
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
      expect(text.includes('Cipralex - known risk of torsades')).assertTrue();
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
