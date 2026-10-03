import { describe, it, expect } from '@ohos/hypium';
import { PairResult, normalizeCode, parseClaim, shortId } from '../main/ets/data/WatchPairing';

const TOKEN: string = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';

export default function watchPairingTest() {
  describe('WatchPairing', () => {
    it('normalizesCodesWithSpacesAndDashes', 0, () => {
      expect(normalizeCode('482913')).assertEqual('482913');
      expect(normalizeCode(' 482 913 ')).assertEqual('482913');
      expect(normalizeCode('482-913')).assertEqual('482913');
      expect(normalizeCode('48291')).assertEqual('');
      expect(normalizeCode('48291a')).assertEqual('');
      expect(normalizeCode('4829134')).assertEqual('');
    });

    it('parsesSuccessfulClaim', 0, () => {
      const r: PairResult = parseClaim(`{"device_id":"3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f","token":"${TOKEN}"}`);
      expect(r.outcome).assertEqual('PAIRED');
      expect(r.deviceId).assertEqual('3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f');
    });

    it('mapsServerErrors', 0, () => {
      expect(parseClaim('{"error":"INVALID_CODE"}').outcome).assertEqual('INVALID_CODE');
      expect(parseClaim('{"error":"RATE_LIMITED"}').outcome).assertEqual('RATE_LIMITED');
    });

    it('rejectsMalformedClaims', 0, () => {
      expect(parseClaim('not json').outcome).assertEqual('INVALID_CODE');
      expect(parseClaim('null').outcome).assertEqual('INVALID_CODE');
      expect(parseClaim(`{"device_id":"x","token":"${TOKEN}"}`).outcome).assertEqual('INVALID_CODE');
      expect(parseClaim(`{"device_id":"bad id; drop","token":"${TOKEN}"}`).outcome).assertEqual('INVALID_CODE');
      expect(parseClaim('{"device_id":"watch-abc","token":"short"}').outcome).assertEqual('INVALID_CODE');
    });

    it('shortensDeviceIds', 0, () => {
      expect(shortId('3f2a9c1e-7b4d-4e8a')).assertEqual('3f2a9c1e');
      expect(shortId('demo')).assertEqual('demo');
    });
  });
}
