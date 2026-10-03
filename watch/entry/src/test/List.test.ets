import alarmRulesTest from './AlarmRules.test';
import limitsTest from './Limits.test';
import metricOutboxTest from './MetricOutbox.test';
import motionAnalyzerTest from './MotionAnalyzer.test';
import scenariosTest from './Scenarios.test';
import sessionStatsTest from './SessionStats.test';
import trackersTest from './Trackers.test';

export default function testsuite() {
  alarmRulesTest();
  sessionStatsTest();
  scenariosTest();
  metricOutboxTest();
  motionAnalyzerTest();
  limitsTest();
  trackersTest();
}
