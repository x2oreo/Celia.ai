import { describe, it, expect } from '@ohos/hypium';
import { confirmStateOf, stagePhase, verdictOf } from '../main/ets/components/agent/AgentLogic';
import { VerdictCardPayload } from '../main/ets/model/AgentTypes';

export default function agentLogicTest() {
  describe('AgentLogic', () => {
    it('confirmCardStaysOpenUntilAnswered', 0, () => {
      expect(confirmStateOf([], [], 'a1')).assertEqual('OPEN');
      expect(confirmStateOf(['a2'], ['a2'], 'a1')).assertEqual('OPEN');
    });

    it('confirmCardKeepsTheAnswer', 0, () => {
      expect(confirmStateOf(['a1', 'a2'], ['a1'], 'a1')).assertEqual('ACCEPTED');
      expect(confirmStateOf(['a1', 'a2'], ['a1'], 'a2')).assertEqual('DECLINED');
    });

    it('verdictComesFromThePayload', 0, () => {
      const p: VerdictCardPayload = JSON.parse('{"query":"zofran","ingredient":"ondansetron","risk":"POSSIBLE_RISK",' +
        '"combinedRisk":"KNOWN_RISK","reason":"r","source":"s","findings":[]}') as VerdictCardPayload;
      expect(verdictOf(p).risk).assertEqual('KNOWN_RISK');
      expect(verdictOf(p).query).assertEqual('Zofran');
      expect(verdictOf(p).ingredient).assertEqual('ondansetron');
    });

    it('orbThinksWhileATypedTurnRuns', 0, () => {
      expect(stagePhase(true, 'OFF')).assertEqual('THINKING');
      expect(stagePhase(true, 'LISTENING')).assertEqual('THINKING');
      expect(stagePhase(true, 'SPEAKING')).assertEqual('SPEAKING');
      expect(stagePhase(false, 'OFF')).assertEqual('OFF');
      expect(stagePhase(false, 'HEARING')).assertEqual('HEARING');
    });
  });
}
