import contractSmokeTest from './ContractSmoke.test';
import agentSafetyTest from './AgentSafety.test';
import agentCoreTest from './AgentCore.test';
import voiceTest from './Voice.test';
import medicineScanTest from './MedicineScan.test';
import drugCheckerTest from './DrugChecker.test';
import alarmRulesTest from './AlarmRules.test';
import sosControllerTest from './SosController.test';
import doctorPrepTest from './DoctorPrep.test';
import utilsTest from './Utils.test';
import boxCatalogTest from './BoxCatalog.test';
import cardLinkTest from './CardLink.test';
import restingTrendTest from './RestingTrend.test';
import watchCloudSourceTest from './WatchCloudSource.test';
import watchDataClientTest from './WatchDataClient.test';
import watchPairingTest from './WatchPairing.test';

export default function testsuite() {
  contractSmokeTest();
  agentSafetyTest();
  agentCoreTest();
  voiceTest();
  medicineScanTest();
  drugCheckerTest();
  alarmRulesTest();
  sosControllerTest();
  doctorPrepTest();
  utilsTest();
  boxCatalogTest();
  cardLinkTest();
  restingTrendTest();
  watchCloudSourceTest();
  watchDataClientTest();
  watchPairingTest();
}
