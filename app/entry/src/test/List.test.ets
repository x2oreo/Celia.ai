import contractSmokeTest from './ContractSmoke.test';
import agentSafetyTest from './AgentSafety.test';
import agentCoreTest from './AgentCore.test';
import voiceTest from './Voice.test';
import medicineScanTest from './MedicineScan.test';

export default function testsuite() {
  contractSmokeTest();
  agentSafetyTest();
  agentCoreTest();
  voiceTest();
  medicineScanTest();
}
