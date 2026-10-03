# insightintents/ — OWNER: Kaloyan

Intents Kit entry points so Celia (Huawei's system assistant) can call the app:
`CheckDrugSafety` (background, returns verdict text) and `ShowEmergencyCard` (foreground).
Both call `DrugChecker` / pages directly, never the LLM. Not registered yet — add `insight_intent.json` +
`module.json5` config together with the first implementation so the build stays green.
