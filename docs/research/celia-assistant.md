# Celia (system assistant) integration — what exists, what access it needs, how to test (A9)

Researched 3 October 2026 from the Huawei developer guides (Chinese edition, read through Context7:
`insight-intent-decorator-development`, `intents-skill-all-rec-content-search`, `agent-extension-ability`,
`hmaf-a2a-dev-guide`, `hmaf-function`). Nothing here has been run on a real phone yet. Until the Sunday 08:00 test,
every row below is **unverified**.

## The three paths

| Path | In the repo | What the docs say it needs | State |
|---|---|---|---|
| **Intents** (`@InsightIntentEntry`) | 7 intents in `app/entry/src/main/ets/insightintents/`, listed in `resources/base/profile/insight_intent.json` (`insightIntentsSrcEntry`) | Declaring an intent needs no account. Whether the assistant *routes a spoken request* to a third-party `LocalDomain` intent is not stated in the guide. The older JSON style says intent names must come from Huawei's preset domains ("仅支持预置垂域意图，不允许自定义") and are tied to an approved plug-in; the decorator style allows custom names in `LocalDomain` | Built and compiled. Routing from Celia unverified |
| **A2A agent** (`AgentExtensionAbility`, `createA2AServer`, agent card) | Not built | **API version 24 or later** ("从API version 24开始"). The client is a system app. An agent card with an `agentId` | Not built. Our minimum is API 20, so this can only be an optional extension on a newer device; it cannot run on an API 20 phone or emulator image |
| **FunctionComponent** (open a platform agent inside our UI) | Not built | An `agentId` issued by the Xiaoyi agent platform when the agent is created there ("由小艺智能体平台在创建智能体时指定"); `controller.isAgentSupport(ctx, agentId)` tells at runtime whether the device supports it | Not built. Blocked on an agent id |

## Access we would need (ask the Huawei mentors)

1. A Xiaoyi Open Platform (小艺开放平台) developer account that can create an agent, and whether that is open to
   accounts outside mainland China.
2. An `agentId` for a "Celia.ai" agent, and how long review takes.
3. Whether the international Celia build routes voice requests to `LocalDomain` intents of a third-party app, or only
   to preset domains with an approved plug-in.
4. The API level of the loan phone. Below 24, `AgentExtensionAbility` is not available.

## Test on the real phone (Sunday 08:00, about 10 minutes)

1. `app/scripts/device.sh check`, set `DEMO_VOICE_INPUT = ''`, install.
2. Open the app once so the intents register. Note the phone's API level (`hdc shell param get const.ohos.apiversion`).
3. Say to the assistant, in English: "Can I take ondansetron?", "Show my emergency card", "Log a symptom: dizzy",
   "I took my beta blocker". Write down for each: did our app answer, did the assistant answer by itself, or nothing.
4. Watch `hdc shell hilog -x | grep CeliaAI` for the executor's log line; that is the proof our code ran.
5. Check system search and suggestions for the intents' display names.

Record the result in the README verify table either way. If nothing routes, the README row stays "built and
compiled; Celia did not route to it on <phone model>, API <n>" and the demo uses the in-app agent only.

## What we say in the demo and documents

The in-app agent is the product. The seven intents are entry points the system may use. Do not say "Celia calls
our app" unless step 3 showed it on the phone.

## Persona name for the in-app agent (A11, proposal only — owner decides)

"Celia" is Huawei's assistant, so the in-app agent needs its own name or none.

| Option | For | Against |
|---|---|---|
| Keep "the agent" | No naming clash with Huawei's Celia; nothing to explain in the pitch | Impersonal |
| "Cor" (Latin for heart) | Short, easy to say to a microphone, fits the orb | Sounds like "core" |
| "Beat" | Friendly, obvious link to heart rate | Could suggest we measure rhythm; we show heart rate only |

Recommendation: keep "the agent" for the submission. The app is already called Celia.ai, and a second name next to
Huawei's Celia adds a third thing to explain in a three-minute demo.
