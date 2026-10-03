import { describe, it, expect } from '@ohos/hypium';
import { IdentifyReply, parseIdentify } from '../main/ets/drugs/BoxIdentifyClient';

const TYLENOL: string = '{"found":true,"candidate":{"gtin":"0300450449108","brand":"Tylenol Extra Strength",' +
  '"ingredients":["acetaminophen"],"unresolved":[],"strength":"","form":"oral","country":"US",' +
  '"method":"REGISTRY","source":"FDA drug label (openFDA)",' +
  '"sourceUrl":"https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=x","confirmations":0},"ms":812}';

export default function boxIdentifyTest() {
  describe('BoxIdentifyClient', () => {
    it('parsesARegistryHit', 0, () => {
      const r: IdentifyReply = parseIdentify(TYLENOL, '0300450449108');
      expect(r.candidate !== undefined).assertTrue();
      expect(r.candidate?.brand).assertEqual('Tylenol Extra Strength');
      expect(r.candidate?.ingredients.join('+')).assertEqual('acetaminophen');
      expect(r.candidate?.method).assertEqual('REGISTRY');
    });

    it('rejectsAnswerForAnotherBarcode', 0, () => {
      expect(parseIdentify(TYLENOL, '5909990331710').candidate === undefined).assertTrue();
    });

    it('missKeepsTheHintForTheWebSearch', 0, () => {
      const r: IdentifyReply = parseIdentify('{"found":false,"hint":"Nurofen Forte"}', '5000158100107');
      expect(r.candidate === undefined).assertTrue();
      expect(r.hint).assertEqual('Nurofen Forte');
    });

    it('rejectsMalformedReplies', 0, () => {
      const bad: string[] = [
        'not json',
        '{"found":true}',
        '{"found":true,"candidate":{"gtin":"0300450449108","brand":"","ingredients":["x1"],"method":"REGISTRY"}}',
        '{"found":true,"candidate":{"gtin":"0300450449108","brand":"B","ingredients":[],"method":"REGISTRY"}}',
        '{"found":true,"candidate":{"gtin":"0300450449108","brand":"B","ingredients":["ab"],"method":"GUESS"}}'
      ];
      for (const b of bad) {
        expect(parseIdentify(b, '0300450449108').candidate === undefined).assertTrue();
      }
    });

    it('dropsInsecureSourceUrlsAndStrayUnresolvedNames', 0, () => {
      const body: string = '{"found":true,"candidate":{"gtin":"8470006500064","brand":"DEPAKINE",' +
        '"ingredients":["valproic acid","mysteryine"],"unresolved":["mysteryine","other"],' +
        '"method":"AI_WEB","source":"Web search","sourceUrl":"http://x.example","confirmations":2}}';
      const r: IdentifyReply = parseIdentify(body, '8470006500064');
      expect(r.candidate?.sourceUrl).assertEqual('');
      expect(r.candidate?.unresolved.join(',')).assertEqual('mysteryine');
      expect(r.candidate?.confirmations).assertEqual(2);
    });
  });
}
