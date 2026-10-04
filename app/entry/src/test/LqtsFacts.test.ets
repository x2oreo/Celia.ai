import { describe, it, expect } from '@ohos/hypium';
import {
  DO_NOT_USE, GENERAL_PRECAUTIONS, GENOTYPE_FACTS, GenotypeFacts, LQTS_OVERVIEW, ProtocolStep, TORSADES_STEPS,
  genotypeFacts, protocolSteps
} from '../main/ets/emergency/LqtsFacts';
import { MedRow, nameInitial, takesQtRiskMed } from '../main/ets/emergency/Responder';

const EM_DASH: string = String.fromCharCode(0x2014);

function allText(): string[] {
  const out: string[] = [];
  LQTS_OVERVIEW.forEach((s: string) => out.push(s));
  GENERAL_PRECAUTIONS.forEach((s: string) => out.push(s));
  TORSADES_STEPS.forEach((s: string) => out.push(s));
  DO_NOT_USE.forEach((s: string) => out.push(s));
  GENOTYPE_FACTS.forEach((f: GenotypeFacts) => {
    out.push(f.name, f.gene, f.share, f.ecg, f.treatment);
    f.triggers.forEach((s: string) => out.push(s));
    f.emergencyNotes.forEach((s: string) => out.push(s));
  });
  protocolSteps('112', true).forEach((p: ProtocolStep) => out.push(p.step, p.detail));
  return out;
}

function row(risk: string, avoidCongenital: boolean): MedRow {
  const r: MedRow = {
    line: 'x', risk: risk === 'KNOWN_RISK' ? 'KNOWN_RISK' : risk === 'POSSIBLE_RISK' ? 'POSSIBLE_RISK' : 'NOT_LISTED',
    avoidCongenital: avoidCongenital
  };
  return r;
}

export default function lqtsFactsTest() {
  describe('LqtsFacts', () => {
    it('everyGenotypeHasFullFacts', 0, () => {
      expect(GENOTYPE_FACTS.length).assertEqual(4);
      GENOTYPE_FACTS.forEach((f: GenotypeFacts) => {
        expect(genotypeFacts(f.genotype)).assertEqual(f);
        expect(f.name.length > 0).assertTrue();
        expect(f.triggers.length > 0).assertTrue();
        expect(f.treatment.length > 0).assertTrue();
        expect(f.emergencyNotes.length > 0).assertTrue();
        if (f.genotype !== 'UNKNOWN') {
          expect(f.gene.length > 0 && f.ecg.length > 0 && f.share.length > 0).assertTrue();
        }
      });
    });

    it('genesMatchTheDomainTable', 0, () => {
      expect(genotypeFacts('LQT1').gene.includes('KCNQ1')).assertTrue();
      expect(genotypeFacts('LQT2').gene.includes('KCNH2')).assertTrue();
      expect(genotypeFacts('LQT3').gene.includes('SCN5A')).assertTrue();
    });

    it('noEmDashAndNoDoses', 0, () => {
      allText().forEach((s: string) => {
        expect(s.includes(EM_DASH)).assertFalse();
        expect(/\d+(\.\d+)?\s?(mg|g|mmol|mEq|mcg|µg)\b/.test(s)).assertFalse();
      });
    });

    it('protocolUsesTheLocalNumberAndMagnesium', 0, () => {
      const steps: ProtocolStep[] = protocolSteps('999', false);
      expect(steps[0].detail.includes('999')).assertTrue();
      expect(steps.some((p: ProtocolStep) => p.step.includes('magnesium'))).assertTrue();
      expect(steps.some((p: ProtocolStep) => p.step.includes('ICD'))).assertFalse();
      expect(protocolSteps('112', true).some((p: ProtocolStep) => p.step.includes('ICD'))).assertTrue();
    });

    it('neverRecommendsLidocaineAvoidanceOrIsoproterenolForCongenital', 0, () => {
      allText().forEach((s: string) => {
        expect(s.toLowerCase().includes('lidocaine')).assertFalse();
      });
      expect(TORSADES_STEPS.some((s: string) => s.includes('Isoproterenol is for acquired'))).assertTrue();
    });

    it('takesQtRiskMedFlagsKnownRiskAndCongenital', 0, () => {
      expect(takesQtRiskMed([row('NOT_LISTED', false), row('POSSIBLE_RISK', false)])).assertFalse();
      expect(takesQtRiskMed([row('NOT_LISTED', false), row('KNOWN_RISK', false)])).assertTrue();
      expect(takesQtRiskMed([row('NOT_LISTED', true)])).assertTrue();
      expect(takesQtRiskMed([])).assertFalse();
    });

    it('nameInitial', 0, () => {
      expect(nameInitial(' anna kowalska')).assertEqual('A');
      expect(nameInitial('')).assertEqual('');
      expect(nameInitial(undefined)).assertEqual('');
    });
  });
}
