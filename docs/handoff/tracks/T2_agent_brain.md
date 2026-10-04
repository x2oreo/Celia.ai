# T2 - Agent brain (A4, then A10)

Read `docs/handoff/tracks/README.md` first (scope change, rules, emulator lock), then sections 3-7 of
`docs/handoff/KALOYAN_agent_and_ui.md`. Task A4 there is yours, then A10.

## Files you own

`agent/*`, `agent/tools/*`, `model/AgentTypes.ets`, `safety/*`, `voice/*`, `resources/rawfile/voice/*`,
`components/AgentCards.ets`, `backend/supabase/functions/_shared/*`, `backend/supabase/functions/agent/*`,
`backend/supabase/functions/realtime-session/*`, `backend/eval/*`, and the agent tests in `app/entry/src/test/`.

Not yours: `pages/AgentPage.ets` and `components/agent/*` (T1). **Do not edit them until the owner says the A3 split
is merged.** After that you may make small edits in `components/agent/ActionCards.ets` (new `OPEN_PAGE` tiles) and
the scan handler (camera), and you say so in the commit body.

## 1. New tools so the agent reaches everything (no UI needed yet)

- `open_symptom_log`, `open_reminders`, and `open_responder` if `Routes.RESPONDER` exists (Workstream B adds it; check
  `origin/main`. If it is not there, skip the tool and note it in your log).
- Read-only tools push an `OPEN_PAGE` action. Add the `page` values to `OpenPagePayload` in `model/AgentTypes.ets`
  and list them in your log for T1.
- Names must match in three places: `agent/ToolRegistry.ets`, `_shared/tools.ts`, `BACKEND_TOOLS` in
  `app/entry/src/test/AgentSafety.test.ets`. Add step labels to `ToolUi` in `components/AgentCards.ets`, and
  `accessibilityText` to the controls in that file while you are there.
- Offline path: `agent/OfflineAgent.ets` should answer the same intents without the model where it can.
- Unit tests for each tool. Bump `PROMPT_VERSION` when the prompt changes. Run `backend/eval/agent-eval.ts` after
  every prompt or tool change and keep the result in your log.

## 2. After the A3 merge: tiles and camera

- Add the tiles for the new `page` values in `components/agent/ActionCards.ets`.
- The camera button opens the gallery (`PhotoViewPicker`). Verify the system camera picker in Context7
  (`@kit.CameraKit` `cameraPicker`); if it works on API 20, capture with it and keep the gallery as the fallback on
  the emulator. If not, change the icon's label and `accessibilityText` to say "Choose a photo". Icon artwork is not
  ours to redraw; pick an existing one.

## 3. Test the agent by voice

Loop from section 7 of the workstream brief (local backend, `hdc rport`, `DEMO_VOICE_INPUT = 'on'`). Paid OpenAI
calls are approved by the owner.

- New clips for `get_dose_status`, `get_trends` and each new tool (recipe in the brief, A4). Add them to `CLIPS` in
  `voice/DemoVoice.ets`.
- Exercise and record in your log, with a screenshot each: the three existing clips, the new clips, barge-in, mute,
  tap-to-talk fallback when live voice fails.
- Fix what breaks in `voice/*`, the prompt or the tools. A wrong or unsafe answer is a prompt / validator fix with
  an eval case added, never a UI patch.

## 4. A10 - `log_dose` as a confirmed write

Confirm-card pattern only: `PendingKind` in `agent/ToolTypes.ets`, `AgentCore.resolveAction`. The model proposes,
the user confirms on the card, only then the dose is written. Tests for confirm, cancel, and a restored chat not
replaying the write. Then richer quick replies after a verdict (deterministic, from the verdict payload).

## Deploy list

You do not deploy. End your log with the exact functions the owner must redeploy (`agent`, `realtime-session`) and
the prompt version they will carry.
