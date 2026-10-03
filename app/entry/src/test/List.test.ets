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
import chatHistoryTest from './ChatHistory.test';
import shareTest from './Share.test';
import restingTrendTest from './RestingTrend.test';
import watchCloudSourceTest from './WatchCloudSource.test';
import medInfoTest from './MedInfo.test';
import drugCheckClientTest from './DrugCheckClient.test';
import boxIdentifyTest from './BoxIdentify.test';
import { Config } from '../main/ets/common/Config';

export default function testsuite() {
  // Unit tests never call the network, whatever the developer's LocalConfig points at.
  Config.forceOffline(true);
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
  chatHistoryTest();
  shareTest();
  restingTrendTest();
  watchCloudSourceTest();
  medInfoTest();
  drugCheckClientTest();
  boxIdentifyTest();
}
