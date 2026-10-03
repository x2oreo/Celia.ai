import { describe, it, expect } from '@ohos/hypium';
import { parseOnlineVerdict } from '../main/ets/drugs/DrugCheckClient';
import { DrugVerdict, LookupStep } from '../main/ets/model/DrugVerdict';

function offline(query: string): DrugVerdict {
  const step: LookupStep = { kind: 'NOT_FOUND', token: query, detail: `${query} not in our list` };
  const v: DrugVerdict = {
    query: query, ingredient: '', risk: 'UNKNOWN_DRUG', reason: 'Not recognised', source: 'bundled',
    confidence: 0, trace: [step], alternatives: []
  };
  return v;
}

const TASIGNA: string = '{"query":"Tasigna","ingredient":"nilotinib","risk":"KNOWN_RISK",' +
  '"reason":"The FDA label mentions QT prolongation in its boxed warning",' +
  '"source":"FDA drug label (openFDA), set_id abc","method":"FDA_LABEL","confidence":0.8,' +
  '"snippet":"WARNING: QT PROLONGATION and SUDDEN DEATHS"}';

export default function drugCheckClientTest() {
  describe('DrugCheckClient', () => {
    it('labelVerdictKeepsRiskSourceAndQuote', 0, () => {
      const v: DrugVerdict = parseOnlineVerdict(TASIGNA, 'Tasigna', offline('Tasigna'));
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(v.ingredient).assertEqual('nilotinib');
      expect(v.confidence).assertEqual(0.8);
      expect(v.source.includes('openFDA')).assertTrue();
      const trace: LookupStep[] = v.trace ?? [];
      expect(trace.length).assertEqual(3);   // offline NOT_FOUND + LABEL mapping + LABEL quote
      expect(trace[1].kind).assertEqual('LABEL');
      expect(trace[2].detail.includes('QT PROLONGATION')).assertTrue();
    });

    it('labelNotListedStaysLowConfidence', 0, () => {
      const body: string = '{"ingredient":"levetiracetam","risk":"NOT_LISTED","reason":"No QT warning",' +
        '"source":"FDA drug label (openFDA)","method":"FDA_LABEL","confidence":0.6,"snippet":""}';
      const v: DrugVerdict = parseOnlineVerdict(body, 'Keppra', offline('Keppra'));
      expect(v.risk).assertEqual('NOT_LISTED');
      expect(v.confidence).assertEqual(0.6);
      expect((v.trace ?? []).length).assertEqual(2);   // no quote step without a snippet
    });

    it('olderServerWithoutMethodStillWorks', 0, () => {
      const body: string = '{"ingredient":"clarithromycin","risk":"KNOWN_RISK","reason":"Macrolide antibiotic",' +
        '"source":"CredibleMeds"}';
      const v: DrugVerdict = parseOnlineVerdict(body, 'Klacid', offline('Klacid'));
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(v.confidence).assertEqual(0.9);
      expect((v.trace ?? [])[1].kind).assertEqual('ONLINE');
    });

    it('confidenceIsCappedBelowTheCuratedList', 0, () => {
      const body: string = '{"ingredient":"x","risk":"POSSIBLE_RISK","reason":"r","source":"s","confidence":1}';
      expect(parseOnlineVerdict(body, 'x', offline('x')).confidence).assertEqual(0.9);
    });

    it('badPayloadsKeepTheOfflineVerdict', 0, () => {
      const bad: string[] = [
        'not json',
        '{"ingredient":"x","risk":"SAFE","reason":"r","source":"s"}',
        '{"ingredient":"","risk":"KNOWN_RISK","reason":"r","source":"s"}',
        '{"ingredient":"x","risk":"UNKNOWN_DRUG","reason":"r","source":"s"}',
        '{"risk":"KNOWN_RISK"}'
      ];
      for (const b of bad) {
        expect(parseOnlineVerdict(b, 'q', offline('q')).risk).assertEqual('UNKNOWN_DRUG');
      }
    });
  });
}
