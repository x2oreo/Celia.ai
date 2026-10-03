// AgentCore end-to-end without a backend (LocalConfig is empty in tests): the deterministic paths must work.

import { describe, it, expect } from '@ohos/hypium';
import { AgentCore } from '../main/ets/agent/AgentCore';
import { AgentReply, UiAction, VerdictCardPayload } from '../main/ets/model/AgentTypes';
import { LocalStore } from '../main/ets/data/LocalStore';
import { Medication } from '../main/ets/model/Medication';

function find(reply: AgentReply, type: string): UiAction | undefined {
  return reply.actions.find((a: UiAction) => a.type === type);
}

export default function agentCoreTest() {
  describe('AgentCoreOffline', () => {
    it('drugQuestionGetsDeterministicVerdictCard', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('Can I take clarithromycin?');
      expect(r.fallback).assertTrue();
      const a: UiAction | undefined = find(r, 'SHOW_VERDICT');
      expect(a !== undefined).assertTrue();
      const v: VerdictCardPayload = JSON.parse((a as UiAction).payload) as VerdictCardPayload;
      expect(v.risk).assertEqual('KNOWN_RISK');
      expect(r.text.includes('known-risk list')).assertTrue();
      expect(r.text.toLowerCase().includes(' safe')).assertFalse();
    });

    it('unknownDrugIsNeverReportedSafe', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('Can I take zorblax?');
      const v: VerdictCardPayload =
        JSON.parse((find(r, 'SHOW_VERDICT') as UiAction).payload) as VerdictCardPayload;
      expect(v.risk).assertEqual('UNKNOWN_DRUG');
      expect(r.text.includes('pharmacist')).assertTrue();
    });

    it('emergencyBypassesModel', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('I just passed out');
      expect(find(r, 'START_EMERGENCY') !== undefined).assertTrue();
    });

    it('emptyInputIsHandled', 0, async () => {
      const r: AgentReply = await AgentCore.get().send('   ');
      expect(r.actions.length).assertEqual(0);
    });

    it('unknownConfirmIdWritesNothing', 0, async () => {
      const before: number = (await LocalStore.get().listMeds()).length;
      const expired: AgentReply = await AgentCore.get().resolveAction('missing-id', true);
      expect(expired.text.includes('expired')).assertTrue();
      const after: Medication[] = await LocalStore.get().listMeds();
      expect(after.length).assertEqual(before);
    });
  });
}
