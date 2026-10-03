import contractSmokeTest from './ContractSmoke.test';
import agentSafetyTest from './AgentSafety.test';
import agentCoreTest from './AgentCore.test';

export default function testsuite() {
  contractSmokeTest();
  agentSafetyTest();
  agentCoreTest();
}
