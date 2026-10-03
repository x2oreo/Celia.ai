# insightintents/ — OWNER: Kaloyan

Intents Kit entry points so Celia (Huawei's system assistant) can call the app. Registered in
`resources/base/profile/insight_intent.json`. Neither intent uses the LLM.

| Intent | Mode | What it does |
|---|---|---|
| `CheckDrugSafety(drugName)` | background | `checkDrugFull()` (DrugChecker + ComboRules) → `{verdict, ingredient, message}`; Celia reads `message` aloud. |
| `ShowEmergencyCard()` | foreground | Opens the app and sets `AppStorage['celia.openTab'] = 'emergency'`. |

**UI contract (Georgi):** the tab container should watch `celia.openTab`
(`@StorageLink('celia.openTab') openTab: string = ''`), switch to the tab it names, then reset it to `''`.

Verification: DevEco Studio → intent debugging, or on a device "Celia, can I take ibuprofen?". Whether Celia
routes to third-party intents outside China / on the emulator is still a mentor question (docs/PLAN.md).
