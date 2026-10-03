import { describe, it, expect } from '@ohos/hypium';
import { PairingFlow } from '../main/ets/controller/PairingFlow';
import { PairStatus, PairingApi, PairingCode, RpcResult } from '../main/ets/sync/PairingClient';

class FakeApi implements PairingApi {
  statuses: PairStatus[] = [];
  statusOk: boolean = true;
  startError: string = '';
  statusCalls: number = 0;

  async start(deviceId: string): Promise<RpcResult<PairingCode>> {
    if (this.startError.length > 0) {
      const f: RpcResult<PairingCode> = { ok: false, value: undefined, error: this.startError };
      return f;
    }
    const c: PairingCode = { code: '482913', expiresAtMs: Date.now() + 600000 };
    const r: RpcResult<PairingCode> = { ok: true, value: c, error: '' };
    return r;
  }

  async status(deviceId: string): Promise<RpcResult<PairStatus>> {
    this.statusCalls++;
    const s: PairStatus = this.statuses.length > 0 ? this.statuses.shift() as PairStatus : 'PENDING';
    const r: RpcResult<PairStatus> = { ok: this.statusOk, value: this.statusOk ? s : undefined, error: '' };
    return r;
  }
}

export default function pairingFlowTest() {
  describe('PairingFlow', () => {
    it('shows the code and turns PAIRED when the phone claims it', 0, async () => {
      const api = new FakeApi();
      const flow = new PairingFlow();
      let paired = 0;
      flow.configure(api, () => {
        paired++;
      });
      expect(await flow.start('dev')).assertEqual('');
      expect(flow.pairingOpen).assertTrue();
      expect(flow.pairScreen).assertEqual('CODE');
      expect(flow.pairCode).assertEqual('482913');
      expect(flow.pairSecondsLeft > 590).assertTrue();
      flow.stopPolling();
      api.statuses = ['PENDING', 'PAIRED'];
      await flow.poll('dev');
      expect(flow.pairScreen).assertEqual('CODE');
      await flow.poll('dev');
      expect(flow.pairScreen).assertEqual('PAIRED');
      expect(flow.pairState).assertEqual('PAIRED');
      expect(paired).assertEqual(1);
      flow.close();
      expect(flow.pairingOpen).assertFalse();
    });

    it('polls every other tick and counts the seconds down', 0, async () => {
      const api = new FakeApi();
      const flow = new PairingFlow();
      flow.configure(api, () => {
      });
      await flow.start('dev');
      flow.stopPolling();
      const calls = api.statusCalls;
      flow.tick('dev', Date.now());
      expect(api.statusCalls).assertEqual(calls);
      flow.tick('dev', Date.now() + 1000000);
      expect(api.statusCalls).assertEqual(calls + 1);
      expect(flow.pairSecondsLeft).assertEqual(0);
    });

    it('expires, and a failed poll keeps waiting', 0, async () => {
      const api = new FakeApi();
      const flow = new PairingFlow();
      flow.configure(api, () => {
      });
      await flow.start('dev');
      flow.stopPolling();
      api.statusOk = false;
      await flow.poll('dev');
      expect(flow.pairScreen).assertEqual('CODE');
      api.statusOk = true;
      api.statuses = ['EXPIRED'];
      await flow.poll('dev');
      expect(flow.pairScreen).assertEqual('EXPIRED');
    });

    it('reports server errors and the paired state from Settings', 0, async () => {
      const api = new FakeApi();
      const flow = new PairingFlow();
      flow.configure(api, () => {
      });
      api.statuses = ['NONE'];
      await flow.refresh('dev');
      expect(flow.pairState).assertEqual('NOT_PAIRED');
      api.statuses = ['PAIRED'];
      await flow.refresh('dev');
      expect(flow.pairState).assertEqual('PAIRED');
      api.statusOk = false;
      await flow.refresh('dev');
      expect(flow.pairState).assertEqual('ERROR');
      api.startError = 'No connection';
      expect(await flow.start('dev')).assertEqual('No connection');
      expect(flow.pairScreen).assertEqual('ERROR');
      expect(flow.pairError).assertEqual('No connection');
    });
  });
}
