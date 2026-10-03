import alarmRulesTest from './AlarmRules.test';
import metricOutboxTest from './MetricOutbox.test';
import scenariosTest from './Scenarios.test';
import sessionStatsTest from './SessionStats.test';

export default function testsuite() {
  alarmRulesTest();
  sessionStatsTest();
  scenariosTest();
  metricOutboxTest();
}
