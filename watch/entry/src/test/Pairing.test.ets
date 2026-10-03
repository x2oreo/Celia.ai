import { describe, it, expect } from '@ohos/hypium';
import { formatPairCode, startSecret } from '../main/ets/sync/PairingClient';

export default function pairingTest() {
  describe('Pairing', () => {
    it('formats a 6-digit code as two groups', 0, () => {
      expect(formatPairCode('482913')).assertEqual('482 913');
      expect(formatPairCode('12')).assertEqual('12');
    });

    it('takes the watch secret from the first pairing_start answer only', 0, () => {
      const secret = 'ab'.repeat(32);
      expect(startSecret(`{"code":"482913","expires_at":"2026-10-04T10:00:00Z","secret":"${secret}"}`)).assertEqual(secret);
      expect(startSecret('{"code":"482913","expires_at":"2026-10-04T10:00:00Z","secret":null}')).assertEqual('');
      expect(startSecret('{"code":"482913","expires_at":"2026-10-04T10:00:00Z"}')).assertEqual('');
      expect(startSecret('{"secret":"short"}')).assertEqual('');
      expect(startSecret('not json')).assertEqual('');
    });
  });
}
