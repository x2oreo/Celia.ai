# T2 log — Agent brain

Branch `kaloyan/t2-agent-brain`. Newest entry last. The integrator folds this into `AI_WORKFLOW.md` and `README.md`.

## 1. New tools (brief §1)

**Asked:** tools so the agent reaches every screen: `open_symptom_log`, `open_reminders`, `open_responder` (only if
`Routes.RESPONDER` exists); offline path; step labels; accessibility in `AgentCards.ets`; tests; eval.

**Produced**

- `open_symptom_log` (read-only): the user's own entries of the last 30 days (symptom, severity, activity, days
  ago; newest five) and an `OPEN_PAGE` tile. The free-text note and the heart-rate range stay on the phone.
- `open_reminders` (read-only): the reminders that are set (medicine, time) and an `OPEN_PAGE` tile. The tool output
  tells the model it cannot add, change or delete a reminder.
- `open_responder`: **not added.** `Routes.RESPONDER` is not on `origin/main` (checked 2026-10-03 22:40).
- Names match in the three places: `agent/ToolRegistry.ets`, `_shared/tools.ts`, `BACKEND_TOOLS` in
  `AgentSafety.test.ets` (17 tools).
- Prompt rule 7c (which screen tool to use; never claim a reminder or dose was written; never interpret numbers,
  symptoms or missed doses). `PROMPT_VERSION` `2026-10-03.4` → `2026-10-03.5`.
- `ToolUi` icons and step labels for both tools; strings `tool_open_reminders(_done)`, `tool_open_symptom_log(_done)`
  inserted after `tool_get_dose_status_done`.
- `AgentCards.ets` accessibility: tool step, confirm header, medicine rows, alternative chips and action tiles are
  grouped; "Open SOS" has its own label.
- `OfflineAgent`: new intents `SYMPTOM_LOG`, `DOSES`, `REMINDERS`, `TRENDS`, matched before the medicine patterns,
  answered with fixed sentences and the same tile. Doctor-visit prep has no offline intent (needs the specialty).
- Eval: cases 18-22 and fixtures for the five page tools and `log_symptom`. The eval now serves on `EVAL_PORT`
  (8010), so it runs while `dev-backend.ts` holds `:8000`.

**Page values for T1** (`OPEN_PAGES` in `model/AgentTypes.ets`): `DOCTOR_PREP`, `REMINDERS`, `TRENDS`, and the new
`SYMPTOM_LOG` → `Routes.SYMPTOM_LOG`. Until the thread has a tile for `SYMPTOM_LOG`, the agent's sentence is shown
without a button (the action is ignored, nothing breaks).

**Validated**

- `app/scripts/test.sh`: 218 tests pass (211 before; 7 new in `AgentSafety.test.ets`: `OfflineAgent` ×3,
  `PageTools` ×4).
- `deno test backend/supabase/functions/`: 68 pass.
- `assembleHap`: builds.
- `backend/eval/agent-eval.ts`, prompt `2026-10-03.5`, 22 cases, real model: **21 PASS, 1 SAFE (caught), 0 FAIL**,
  $1.28. Case 16 turn 2 said "does not establish that the combination is safe"; the device validator replaced it
  with the deterministic verdict text, so the user would have seen the fixed sentence. Cases 18-22 all PASS.
  Results file: `backend/eval/out/agent-eval-2026-10-03T20-47-42-780Z.json` (gitignored).

**Not validated**

- Nothing in this section has been seen on the emulator yet (no tile for `SYMPTOM_LOG` until §2).
- The accessibility grouping was not checked with a screen reader.
- The `log_symptom` eval fixture was added after the run above and has not been exercised.
