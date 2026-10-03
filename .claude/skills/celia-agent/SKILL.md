---
name: celia-agent
description: Making the app agent-native on HarmonyOS so Celia (Huawei's system assistant; 小艺/Xiaoyi in China) is the centre of the experience — Agent Framework Kit (HMAF) FunctionComponent/FunctionController to open an agent from our UI, AgentExtensionAbility + createA2AServer to expose our app as an A2A agent with an agent card, Intents Kit @InsightIntentEntry so Celia/search can call our features ("Celia, can I take ibuprofen?"), plus the in-app LLM-agent fallback and AI-safety rules. Use when designing or coding anything agent/assistant/voice/intent related.
---

# Celia at the centre — agent integration

**Celia** = international name of Huawei's system AI assistant (Chinese docs: **小艺 / Xiaoyi**, "小艺开放平台" =
Xiaoyi Open Platform). HarmonyOS 6 ships **HMAF** (HarmonyOS Agent Framework). Docs are CN-first → search
Context7 with both "Celia" and "Xiaoyi/小艺". Verify every signature in Context7
(`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`, slugs `hmaf-introduction`, `hmaf-function`,
`hmaf-a2a-dev-guide`, `agent-extension-ability`, `agent-extension-configuration`,
`insight-intent-decorator-development`, `intents-local-rec-access-programme`).

## Availability risk — decide in the first hours

- Agents for FunctionComponent must be **created and published on the Xiaoyi Open Platform** (gives `agentId`).
  EU/overseas account access, emulator support, and Celia's language support for these flows are **unconfirmed** →
  ask Huawei mentors at T0. Check at runtime with `controller.isAgentSupport(ctx, agentId)`.
- Architecture rule: **all agent features run through our own `AgentCore` service in the app**. System entry points
  (Celia via Intents/A2A, FunctionComponent) are *adapters* on top. If Celia isn't reachable on the demo
  device/emulator, the in-app agent UI still works and the demo explains the system path. Never let the demo depend
  on an unverified system path.

## Three integration levels (from cheapest to most "wow")

### 1. Intents Kit — Celia calls our features (`@kit.AbilityKit`)

Declare capabilities with an LLM description + JSON-schema params; system assistant/search matches the user's
utterance and runs our executor, then turns the result into natural language.

`entry/src/main/resources/base/profile/insight_intent.json`:
```json
{ "insightIntentsSrcEntry": [ { "srcEntry": "./ets/insightintents/CheckDrugIntent.ets" } ] }
```
`entry/src/main/ets/insightintents/CheckDrugIntent.ets`:
```ts
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';

class CheckDrugResult {
  public verdict?: string = '';
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'CheckDrugSafety',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Check medicine safety',
  displayDescription: 'Checks if a medicine is safe for the user\'s heart condition',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Given a medicine name, returns whether it is safe, risky or dangerous for a person with Long QT syndrome',
  keywords: ['medicine', 'drug check', 'can I take'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'properties': { 'drugName': { 'type': 'string', 'description': 'Medicine name, brand or generic', 'minLength': 1 } },
    'required': ['drugName']
  }
})
export default class CheckDrugIntent extends InsightIntentEntryExecutor<CheckDrugResult> {
  public drugName: string = '';                       // filled by the framework from parameters
  onExecute(): Promise<insightIntent.IntentResult<CheckDrugResult>> {
    // call AgentCore / deterministic lookup here; never let an LLM decide the verdict
    const r: insightIntent.IntentResult<CheckDrugResult> = { code: 0, result: { verdict: 'AVOID', message: '...' } };
    return Promise.resolve(r);
  }
}
```
Execute modes: `UI_ABILITY_FOREGROUND` (open a page), `UI_ABILITY_BACKGROUND` (answer without UI).
Older non-decorator style: `InsightIntentExecutor.onExecuteInUIAbilityForegroundMode(name, param, pageLoader)`.
Test locally: DevEco has intent debugging; also call the same executor logic from a unit test.

### 2. Expose the app as an agent — A2A server (`AgentExtensionAbility`)

`module.json5`:
```json5
"extensionAbilities": [{
  "name": "AgentExtAbility", "type": "agent", "exported": true,
  "srcEntry": "./ets/agentextability/AgentExtAbility.ets",
  "metadata": [{ "name": "ohos.extension.agent", "resource": "$profile:agent_config" }]   // name is mandatory (hvigor 00303289)
}]
```
`resources/base/profile/agent_config.json` → `{ "agentCards": [{ agentId, name, description, provider, version,
capabilities, defaultInputModes, defaultOutputModes, skills: [{ id, name, description, tags, examples, inputModes,
outputModes }], type: "APP", appInfo: { deviceTypes: ["phone","tablet"] } }] }`. Skills + English examples are what
Celia uses to route ("Can I take ibuprofen?", "Show my emergency card").

Ability skeleton:
```ts
import { common, Want, AgentExtensionAbility } from '@kit.AbilityKit';
import { RequestContext, createA2AServer, Server, TaskState, Role } from '@kit.AgentFrameworkKit';

export default class AgentExtAbility extends AgentExtensionAbility {
  private server: Server | null = null;
  private onAgentData = (method: string, ctx: RequestContext) => {
    const taskId: string = ctx.getTaskId() ?? '';
    if (method === 'Execute') {
      this.server?.updateStatus(taskId, { state: TaskState.WORKING,
        message: { messageId: 'm1', role: Role.AGENT, parts: [{ mediaType: 'text/plain', text: 'Checking…' }] } });
      this.server?.addArtifact(taskId, { artifactId: 'result',
        parts: [{ mediaType: 'application/json', text: '{"verdict":"AVOID"}' }] });
      this.server?.updateStatus(taskId, { state: TaskState.COMPLETED,
        message: { messageId: 'm2', role: Role.AGENT, parts: [{ mediaType: 'text/plain', text: 'Done' }] } });
    }
    // also: 'Cancel', 'PerceptionSuggest' (agent chips: return suggestionCandidates)
  };
  async onCreate(want: Want) { this.server = createA2AServer(this.context.agentCard, this.onAgentData, want); }
  onConnect(want: Want, proxy: common.AgentHostProxy) { this.server?.start(); }
  async onData(proxy: common.AgentHostProxy, data: string) {
    this.server?.onMessage(data, (resp: string) => { proxy.sendData(resp); });
  }
  onDisconnect(want: Want, proxy: common.AgentHostProxy) { this.server?.stop(); }
  onDestroy() { this.server?.stop(); }
}
```
(Docs sample passes `want=want` — that's a typo in the doc; pass `want`. Confirm param list in references.)

### 3. Open an agent inside our UI — FunctionComponent (`@kit.AgentFrameworkKit`)

```ts
import { FunctionComponent, FunctionController } from '@kit.AgentFrameworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
private controller: FunctionController = new FunctionController();
// aboutToAppear: this.isSupported = await this.controller.isAgentSupport(ctx, AGENT_ID)
FunctionComponent({
  agentId: AGENT_ID,                       // from Xiaoyi Open Platform — not a secret but keep in config
  onError: (err: BusinessError) => { /* fall back to in-app agent */ },
  options: { title: 'Ask Celia', queryText: 'Is ibuprofen safe for me?' },
  controller: this.controller
})
// controller.on('agentDialogOpened' | 'agentDialogClosed', cb) — remove with off() in aboutToDisappear
```

## In-app agent (always-works path)

- `AgentCore` = tool-calling loop: tools are our deterministic services (drug lookup, med list, emergency card,
  doctor report, vitals summary). LLM picks tools + writes explanations only.
- LLM runs on **our backend** (key never in the HAP); app calls it with `@kit.NetworkKit` http (SSE for streaming).
  Optional on-device pieces: Core Speech (ASR/TTS), Core Vision OCR for box photos, MindSpore Lite.
- Same tool definitions back the Intents executors and the A2A server → one brain, three entry points.

## AI safety rules (also scored under "technical execution")

1. **Verdicts (safe / caution / avoid) come from deterministic data**, never from the model. LLM explains and drafts questions.
2. Validate every model output against a typed schema; on parse failure, timeout, or unknown drug → deterministic
   fallback + "ask your doctor/pharmacist", logged with hilog. Show this in the demo.
3. Ground prompts in looked-up facts; temperature 0; cite source of each fact (e.g. CredibleMeds category).
4. Minimise data sent off-device (drug names + genotype, not identity); document in the AI feature doc.
5. Medical disclaimer in UI and docs: decision support, not a medical device.
