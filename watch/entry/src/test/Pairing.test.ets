import { describe, it, expect } from '@ohos/hypium';
import { formatPairCode } from '../main/ets/sync/PairingClient';

export default function pairingTest() {
  describe('Pairing', () => {
    it('formats a 6-digit code as two groups', 0, () => {
      expect(formatPairCode('482913')).assertEqual('482 913');
      expect(formatPairCode('12')).assertEqual('12');
    });
  });
}
