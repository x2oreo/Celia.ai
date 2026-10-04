# T2 log - Agent brain

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

## 4. A10 - `log_dose` as a confirmed write, quick replies after a verdict (done before §2, which is blocked)

**Asked:** `log_dose` through the confirm-card pattern only; tests for confirm, cancel and a restored chat not
replaying the write; richer quick replies after a verdict, deterministic.

**Produced**

- Tool `log_dose(medicine|null)` (`agent/tools/ActionTools.ets`). The phone picks the dose: the one due now, else the
  earliest missed today, among the reminders for the named medicine only (`doseToLog`). It never picks an upcoming
  dose or another medicine. It pushes a `LOG_DOSE` action (`LogDosePayload`: `actionId`, `medicine`, `time`) and a
  pending entry (`PendingKind` `LOG_DOSE`); nothing is written.
- `AgentCore.resolveAction` writes on Confirm, after re-checking the dose status at tap time (already marked on the
  reminders screen → nothing changes). Cancel, an unknown id and an id older than 10 minutes write nothing.
- Restored chats: `keepOnRestore` drops `LOG_DOSE`, and opening a chat clears pending actions, so an old card cannot
  write.
- Offline: "I took my nadolol" / "mark my nadolol as taken" propose the same card with a fixed sentence.
- Quick replies after a verdict (`VerdictText.verdictQuickReplies`, added in `AgentCore.finish`): chosen by the risk
  level only. Risky → "What can I take instead of X?", "Prepare me for a doctor visit", "Show my medicines". Not
  listed (also with the user's medicines) → "Add X to my medicines", "Show my medicines". Unknown → "Scan the box
  instead", "Show my emergency card". Not added next to a confirm card or an emergency. Online replies only.
- Prompt: rule 6 lists `log_dose`; new rule 7d. `PROMPT_VERSION` → `2026-10-03.6`. 18 tools in the three lists.

**Validated**

- `app/scripts/test.sh`: 228 pass. New: `LogDose` ×6 (dose choice, confirm, cancel, marked elsewhere, restored chat,
  no reminders), `VerdictQuickReplies` ×2, `DemoVoice` ×2.
- `deno test`: 68 pass. `assembleHap`: builds.
- Eval, prompt `2026-10-03.6`, cases 1, 2, 5, 7, 18, 20, 21, 23, 24: 9 PASS (7 and 18 passed on a re-run after an
  upstream timeout, HTTP 502). Cases 3, 4, 6, 8-17, 19, 22 were last run on `2026-10-03.5` (see §1); they were not
  re-run on `.6`. Eval spend so far $1.89 of the harness's $2.50 stop.
- Emulator: verdict quick replies appear under the ondansetron verdict in a voice session
  (`app/build/t2/01-ondansetron.jpeg`).

**Not validated**

- The `LOG_DOSE` confirm card has never been seen on screen: the thread has no branch for it yet (see "Needs").
  By voice, `log_dose` was called and answered "no reminders are set, nothing was logged"
  (`app/build/t2/07-tookdose.jpeg`); the emulator profile has no reminders, so the confirm path ran in unit tests only.
- Quick replies were not tapped on the emulator.

## 3. Agent by voice (emulator, `DEMO_VOICE_INPUT = 'on'`, local backend from this worktree)

**Produced**

- Five clips (`say -v Daniel`, 24 kHz PCM16 mono): `doses`, `trends`, `symptoms`, `reminders`, `tookdose`.
- Session order in `voice/DemoVoice.ets`: ondansetron, dentist, doses, trends, symptoms, reminders, tookdose, dizzy,
  then `ondansetron+doses`, a barge-in session: the second clip is streamed 1.5 s into the agent's spoken answer.
  **The demo order changed:** `dizzy` is now the 8th session, not the 3rd.
- `RealtimeSession` logs `barge-in: user speech while the agent was speaking, playback cleared`.
- The `log_dose` step label read "Dose ready to confirm" when nothing was due; it now reads "Checked for a dose that
  is due".

**Validated** (real Realtime model `gpt-realtime-2.1`, prompt `2026-10-03.6`; screenshots under `app/build/t2/`,
gitignored, on this Mac)

| What | Result | Screenshot |
|---|---|---|
| ondansetron | transcribed, `check_drug`, Known risk card, interaction with escitalopram, quick replies | `01-ondansetron.jpeg` |
| dentist | `prepare_doctor_visit`, "Doctor visit prep" tile | `02-dentist.jpeg` |
| doses | `get_dose_status`, "no reminders are set", reminders tile | `03-doses.jpeg` |
| trends | `get_trends`, said "simulated demo data", Trends tile | `04-trends.jpeg` |
| symptoms | `open_symptom_log`, "no entries in the last 30 days"; **no tile yet** | `05-symptoms.jpeg` |
| reminders | `open_reminders`, reminders tile | `06-reminders.jpeg` |
| tookdose | `log_dose`, "nothing was logged" (no reminders on this profile) | `07-tookdose.jpeg` |
| dizzy | safety gate, SOS countdown page; "I'm OK" cancels and the chat says so | `08-dizzy.jpeg` |
| mute | label "Muted. Tap the mic to unmute."; second tap returns to the live label | `09-muted.jpeg`, `10-unmuted.jpeg` |
| barge-in | playback cleared (log line above), the second question answered with `get_dose_status` | `11-bargein-mid.jpeg`, `12-bargein-end.jpeg` |
| live voice fails (backend stopped) | "Live voice isn't available right now…", next tap starts tap-to-talk ("Listening… tap to send") | `13-live-failed.jpeg`, `14-tap-to-talk.jpeg` |

**Not validated**

- Nothing was heard: the emulator's audio output was not listened to. "Speaking" is the on-screen state and the log.
- Mute with a real microphone (demo input has none, so only the label and state were checked).
- A tap-to-talk recording was started but not sent (no microphone audio to transcribe).
- Barge-in with a human voice. The demo clip proves the `speech_started` → clear-playback path, nothing more.
- Symptom log and reminders with real entries (the emulator profile has none).

## 2. Tiles and camera - BLOCKED

`components/agent/*` exists on `origin/kaloyan/t1-agent-home` but is not merged into `origin/kaloyan/agent-home`
(checked 2026-10-03 23:10). Not started: the `SYMPTOM_LOG` tile, the `LOG_DOSE` card, the camera picker.

Camera, checked in Context7 (harmonyos-references) ahead of the edit: `cameraPicker.pick(context,
[cameraPicker.PickerMediaType.PHOTO], { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK })` from
`@kit.CameraKit` returns `PickerResult.resultUri`. It is the system camera UI, so the app needs no camera
permission. Plan: try it first, fall back to `PhotoViewPicker` when it throws or returns an empty URI (emulator).
Not built, not run.

## Needs from other tracks

- **T1 / integrator:** merge the A3 split, then tell T2. T2 then adds to `components/agent/ActionCards.ets`:
  - `OPEN_PAGE` tile for `SYMPTOM_LOG` → `Routes.SYMPTOM_LOG` (icon `ic_history`, title `sym_title`).
  - A `LOG_DOSE` branch: `ConfirmCard` (icon `ic_bell`, title `agent_log_dose_title`, detail
    `"<medicine> <time>"` from `LogDosePayload`), resolved through the same `onResolve(actionId, accepted)` as
    `ADD_MED`. Until then a `log_dose` proposal shows the sentence but no card, and nothing can be written.
- **Workstream B:** `Routes.RESPONDER`. When it is on `main`, T2 adds `open_responder`.
- **Integrator:** the local backend on `:8000` now runs from the T2 worktree (prompt `.6`, 18 tools). The eval
  harness uses `:8010`.

## README verify-table rows

| Feature | How to verify | Status |
|---|---|---|
| Agent opens the symptom log | Say or type "Show me the symptoms I logged recently" → step "Read your symptom log", the agent reports the entries | Tool verified on the emulator by voice; tile not built yet |
| Agent opens reminders | "Open my medicine reminders" → "Medicine reminders" tile → Reminders page | Verified on the emulator by voice (tile shown; tap not exercised) |
| Agent logs a dose with confirmation | Set a reminder for the current time, say "I just took my nadolol" → confirm card → Confirm → reminder shows Taken | Unit tests only; card not on screen yet |
| Follow-up chips after a verdict | Ask "Can I take ondansetron?" → three chips under the verdict card | Verified on the emulator (shown; not tapped) |
| Demo voice: dose status, trends, symptom log, reminders, log dose, barge-in | `DEMO_VOICE_INPUT = 'on'`, start a voice session nine times | Verified on the emulator |
| Works offline: reminders, doses, symptom log, trends, log dose | Airplane mode, type "open my reminders" | Unit tests only |

## Deploy list (owner)

Redeploy both, they share `_shared/prompt.ts` and `_shared/tools.ts`:

- `agent`
- `realtime-session`

They will carry `PROMPT_VERSION` **`2026-10-03.6`** and 18 tools (new: `open_symptom_log`, `open_reminders`,
`log_dose`). Until they are deployed, the deployed app has the 15 old tools; the three new executors on the phone are
never called, and nothing breaks. No migrations.
