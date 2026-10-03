import heartRulesTest from './HeartRules.test';
import syncEngineTest from './SyncEngine.test';
import pairingFlowTest from './PairingFlow.test';
import sosFlowTest from './SosFlow.test';
import watchControllerTest from './WatchController.test';
import alarmRulesTest from './AlarmRules.test';
import doseNudgeTest from './DoseNudge.test';
import limitsTest from './Limits.test';
import pairingTest from './Pairing.test';
import metricOutboxTest from './MetricOutbox.test';
import motionAnalyzerTest from './MotionAnalyzer.test';
import scenariosTest from './Scenarios.test';
import sessionStatsTest from './SessionStats.test';
import trackersTest from './Trackers.test';
import drugBadgeTest from './DrugBadge.test';

export default function testsuite() {
  alarmRulesTest();
  sessionStatsTest();
  scenariosTest();
  metricOutboxTest();
  motionAnalyzerTest();
  limitsTest();
  trackersTest();
  doseNudgeTest();
  pairingTest();
  drugBadgeTest();
  watchControllerTest();
  sosFlowTest();
  pairingFlowTest();
  syncEngineTest();
  heartRulesTest();
}
