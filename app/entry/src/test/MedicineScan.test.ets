// Photo flow: OCR text → candidate words. The candidate list may only contain words DrugChecker recognises.

import { describe, it, expect } from '@ohos/hypium';
import { ocrTokens } from '../main/ets/agent/MedicineScanFlow';

export default function medicineScanTest() {
  describe('MedicineScan', () => {
    it('extractsWordsFromBoxText', 0, () => {
      const tokens: string[] = ocrTokens('KLACID 500 mg\nClarithromycinum\n14 tabletek powlekanych\nKlacid');
      expect(tokens.includes('klacid')).assertTrue();
      expect(tokens.includes('clarithromycinum')).assertTrue();
      expect(tokens.includes('tabletek')).assertTrue();
      expect(tokens.includes('500')).assertFalse();
      expect(tokens.filter((t: string) => t === 'klacid').length).assertEqual(1);
    });

    it('keepsPolishLetters', 0, () => {
      expect(ocrTokens('Żółć leczniczy').includes('żółć')).assertTrue();
    });

    it('capsTokenCount', 0, () => {
      let text: string = '';
      for (let i = 0; i < 200; i++) {
        text += `word${String.fromCharCode(97 + (i % 26))}${String.fromCharCode(97 + Math.floor(i / 26))} `;
      }
      expect(ocrTokens(text).length <= 60).assertTrue();
    });
  });
}
