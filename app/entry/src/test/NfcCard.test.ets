import { describe, it, expect } from '@ohos/hypium';
import {
  NTAG213_BYTES, NTAG216_BYTES, ndefUriBytes, resultForError, smallestTagFor
} from '../main/ets/emergency/NfcCard';

// Shape of an encrypted share link: viewer + 'card/#' + 16-char id + '.' + 43-char key (share/ShareService.ets).
const SHORT_LINK: string = 'https://celia-share.vercel.app/card/#' + 'a'.repeat(16) + '.' + 'b'.repeat(43);

export default function nfcCardTest() {
  describe('NfcCard', () => {
    it('ndefSizeFollowsTheUriRecordLayout', 0, () => {
      // 'https://' becomes one prefix byte: TLV 2 + header 4 + (1 + 3) payload + terminator 1.
      expect(ndefUriBytes('https://a.b')).assertEqual(11);
      expect(ndefUriBytes('http://a.b')).assertEqual(11);
      expect(ndefUriBytes('tel:112')).assertEqual(2 + 4 + 1 + 7 + 1);
      // Long records switch to a 4-byte length and a 3-byte TLV length.
      const long: string = 'https://' + 'x'.repeat(300);
      expect(ndefUriBytes(long)).assertEqual(4 + 7 + 301 + 1);
    });

    it('encryptedShareLinkFitsTheSmallestTag', 0, () => {
      expect(ndefUriBytes(SHORT_LINK)).assertEqual(97);
      expect(ndefUriBytes(SHORT_LINK) <= NTAG213_BYTES).assertTrue();
      expect(smallestTagFor(SHORT_LINK)).assertEqual('NTAG213');
    });

    it('longInLinkCardsNeedBiggerTagsOrNone', 0, () => {
      const demoV2: string = 'https://celia-share.vercel.app/card/#' + 'x'.repeat(435);
      expect(smallestTagFor(demoV2)).assertEqual('NTAG215');
      const full: string = 'https://celia-share.vercel.app/card/#' + 'x'.repeat(900);
      expect(ndefUriBytes(full) > NTAG216_BYTES).assertTrue();
      expect(smallestTagFor(full)).assertEqual('');
    });

    it('ioErrorsAskToRetry', 0, () => {
      expect(resultForError(3100204)).assertEqual('IO_FAILED');
      expect(resultForError(3100201)).assertEqual('IO_FAILED');
      expect(resultForError(201)).assertEqual('ERROR');
    });
  });
}
