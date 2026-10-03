import { describe, it, expect } from '@ohos/hypium';
import { personalTerms, REDACTED, redactPersonal } from '../main/ets/doctor/Redact';
import {
  DoctorVisit, isVisitDate, newVisit, nextVisitId, parseVisits, removeVisit, sortVisits, upsertVisit, VISIT_TEXT_MAX
} from '../main/ets/doctor/Visit';
import { BriefSection, buildBrief, visitSections } from '../main/ets/doctor/DoctorPrep';
import { summaryFields } from '../main/ets/doctor/DoctorSummary';
import { forbiddenFields } from '../main/ets/privacy/Ledger';
import { Profile } from '../main/ets/model/Profile';

const NOW: number = 1790000000000;

function profile(): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: false, notes: '', name: 'Anna Kowalska',
    contacts: [{ name: 'Piotr Nowak', phone: '+48 601 222 333', relation: 'brother', email: 'piotr@example.com' }],
    cardiologistName: 'Dr Zofia Wiśniewska', cardiologistPhone: '22 555 01 02', hospital: 'Szpital Bielański'
  };
  return p;
}

export default function visitsTest() {
  describe('Redact', () => {
    it('removesPatternsEmailsPhonesLinks', 0, () => {
      const out: string = redactPersonal('Call me on +48 601 222 333 or 601-222-333, mail a.b@mail.pl, see ' +
        'https://x.pl/a', []);
      expect(out.includes('601')).assertFalse();
      expect(out.includes('mail.pl')).assertFalse();
      expect(out.includes('x.pl')).assertFalse();
      expect(out.includes(REDACTED)).assertTrue();
    });

    it('keepsDatesDosesAndShortNumbers', 0, () => {
      const t: string = 'Since 2026-09-12 and 12.09.2026 I faint twice a week, 40 mg nadolol, call 112.';
      expect(redactPersonal(t, [])).assertEqual(t);
    });

    it('removesProfileNamesAsWholeWords', 0, () => {
      const terms: string[] = personalTerms(profile());
      const out: string = redactPersonal('Anna is worried. Piotr saw it, Annabelle did not. ' +
        'Dr Wiśniewska at Szpital Bielański said wait. KOWALSKA family.', terms);
      expect(out.includes('Anna is')).assertFalse();
      expect(out.includes('Piotr')).assertFalse();
      expect(out.includes('Wiśniewska')).assertFalse();
      expect(out.includes('Bielański')).assertFalse();
      expect(out.includes('KOWALSKA')).assertFalse();
      expect(out.includes('Annabelle')).assertTrue();
      expect(out.includes('worried')).assertTrue();
    });

    it('termsSkipShortPartsAndTitles', 0, () => {
      const p: Profile = profile();
      p.name = 'Jo Li';
      const terms: string[] = personalTerms(p);
      expect(terms.includes('Jo')).assertFalse();
      expect(terms.includes('Jo Li')).assertTrue();
      expect(terms.includes('Dr')).assertFalse();
      expect(personalTerms(undefined).length).assertEqual(0);
    });
  });

  describe('Visit', () => {
    it('newVisitClipsText', 0, () => {
      const long: string = 'x'.repeat(VISIT_TEXT_MAX + 50);
      const v: DoctorVisit = newVisit(1, 'DENTIST', '2026-10-20', `  ${long} `, 'a   b', NOW);
      expect(v.reason.length).assertEqual(VISIT_TEXT_MAX);
      expect(v.worries).assertEqual('a b');
      expect(v.summary).assertEqual('');
    });

    it('validDatesOnly', 0, () => {
      expect(isVisitDate('2026-10-20')).assertTrue();
      expect(isVisitDate('2026-02-30')).assertFalse();
      expect(isVisitDate('20.10.2026')).assertFalse();
    });

    it('listOperations', 0, () => {
      let list: DoctorVisit[] = [];
      list = upsertVisit(list, newVisit(nextVisitId(list), 'GP', '2026-09-01', 'check-up', '', NOW));
      list = upsertVisit(list, newVisit(nextVisitId(list), 'DENTIST', '2026-10-20', 'tooth', '', NOW));
      list = upsertVisit(list, newVisit(nextVisitId(list), 'SURGEON', '2026-10-05', 'knee', '', NOW));
      expect(list.length).assertEqual(3);
      const edited: DoctorVisit = newVisit(2, 'DENTIST', '2026-10-21', 'tooth ache', '', NOW);
      list = upsertVisit(list, edited);
      expect(list.length).assertEqual(3);
      const sorted: DoctorVisit[] = sortVisits(list, '2026-10-03');
      expect(sorted.map((v: DoctorVisit) => v.id).join(',')).assertEqual('3,2,1');
      list = removeVisit(list, 3);
      expect(list.length).assertEqual(2);
      expect(nextVisitId(list)).assertEqual(3);
    });

    it('parseRoundTripsAndSkipsBroken', 0, () => {
      const v: DoctorVisit = newVisit(4, 'CARDIOLOGIST', '2026-11-02', 'ECG', 'fainting', NOW);
      v.summary = 'LQT2 patient on nadolol, one flagged antibiotic.';
      v.summaryAt = NOW;
      const raw: string = JSON.stringify([v, { id: 'x' }, { id: 5, date: 'soon' },
        { id: 6, date: '2026-12-01', specialty: 'ASTROLOGER' }]);
      const back: DoctorVisit[] = parseVisits(raw);
      expect(back.length).assertEqual(2);
      expect(back[0].summary).assertEqual(v.summary);
      expect(back[0].worries).assertEqual('fainting');
      expect(back[1].specialty).assertEqual('GP');
      expect(parseVisits('not json').length).assertEqual(0);
      expect(parseVisits('{"a":1}').length).assertEqual(0);
    });
  });

  describe('VisitBrief', () => {
    it('briefCarriesTheVisitAnswers', 0, () => {
      const v: DoctorVisit = newVisit(1, 'DENTIST', '2026-10-20', 'Wisdom tooth out', 'Adrenaline\nThe noise', NOW);
      const sections: BriefSection[] = buildBrief(profile(), [], [], [], 'DENTIST', NOW, v);
      expect(sections[1].title).assertEqual('This visit');
      expect(sections[1].lines[1]).assertEqual('Reason: Wisdom tooth out');
      expect(sections[2].title).assertEqual('What worries me');
      expect(sections[2].lines.length).assertEqual(2);
      expect(visitSections(newVisit(2, 'GP', '2026-10-20', '', '', NOW)).length).assertEqual(1);
      expect(buildBrief(profile(), [], [], [], 'DENTIST', NOW)[1].title === 'This visit').assertFalse();
    });

    it('summarySendsRedactedAnswersOnly', 0, () => {
      const p: Profile = profile();
      const v: DoctorVisit = newVisit(1, 'CARDIOLOGIST', '2026-10-20', 'Piotr says I faint at night',
        'Anna worries, call 601 222 333', NOW);
      const sections: BriefSection[] = buildBrief(p, [], [], [], 'CARDIOLOGIST', NOW, v);
      const fields: Record<string, string> = summaryFields(sections, 'CARDIOLOGIST', p.genotype, v, personalTerms(p));
      const all: string = Object.keys(fields).map((k: string) => fields[k]).join(' ');
      expect(all.includes('Piotr')).assertFalse();
      expect(all.includes('Anna')).assertFalse();
      expect(all.includes('601')).assertFalse();
      expect(fields['reason'].includes('faint at night')).assertTrue();
      expect(forbiddenFields(Object.keys(fields)).length).assertEqual(0);
      expect(Object.keys(summaryFields(sections, 'CARDIOLOGIST', p.genotype)).includes('reason')).assertFalse();
    });
  });
}
