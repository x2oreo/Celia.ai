# T1 log — Agent home

## A3 — split `AgentPage.ets` (2026-10-04)

**Asked:** pure refactor of `pages/AgentPage.ets` (1,110 lines) into `components/agent/`, behaviour unchanged.

**Produced:**

| File | Holds |
|---|---|
| `components/agent/VoiceStage.ets` | `VoiceStage`: orb, state label, demo badge; stage sizes (168 / 84, 264 / 124) |
| `components/agent/AgentThread.ets` | `AgentThread` (turns, live turn, bubbles, tool steps), `AgentWelcome` (voice / chat welcome, starters), `ChatItem`, `AgentMode` |
| `components/agent/ActionCards.ets` | `ActionCard`: the action switch. `OPEN_PAGE` lives in one builder, `openPage()`: add new page values there |
| `components/agent/AgentDock.ets` | `VoiceDock`, `ChatBar` |
| `components/agent/AgentLogic.ets` | Pure rules: `confirmStateOf`, `verdictOf` (colour from the deterministic payload), `stagePhase` |
| `pages/AgentPage.ets` (622 lines) | State, subscriptions, voice / send / scan logic, header, status strips |

Components only report taps through `@Event`; the page still owns `onMic()` (order unchanged: live session, then
tap-to-talk), `send`, `resolve`, `pickAndScan`, `openSos`, `loadChat` (`keepOnRestore`). `ActionCard` consumes
`navStack` for its own navigation (check result, tabs, `OPEN_PAGE` routes).

**Validated:**

- `app/scripts/test.sh`: 215 pass (211 + 4 new in `AgentLogic.test.ets`). `assembleHap` builds.
- Emulator, local backend, `DEMO_VOICE_INPUT = 'on'`:
  - Restored chat: compact orb, demo badge, findings box, `OPEN_PAGE` doctor-prep tile —
    `shots/t1/a3_voice_idle.jpeg`
  - Text turn ("Can I take ibuprofen?"): tool step, reply, verdict card, input cleared —
    `shots/t1/a3_text_turn.jpeg`
  - Demo-voice turn (ondansetron clip): user transcript, live agent text, "Speaking" label, halos, Known-risk
    verdict card with findings, dock switches keyboard → end — `shots/t1/a3_voice_live.jpeg`,
    `shots/t1/a3_voice_reply.jpeg`
  - End button returns the stage to "Tap to talk".

**Not validated on the emulator after the split:** mute / unmute, tap-to-talk fallback, the "type instead" strip
(needs a blocked microphone), photo-picker scan and candidate chips, `ADD_MED` / share confirm cards, the SOS
notice, starters on an empty thread, opening with an `AskParam` question. Code paths are moved unchanged.

**README verify-table rows:** none (no new or moved feature).

## A1 — the agent is tab 0 (2026-10-04)

**Asked:** tab 0 renders the agent conversation; old Home content stays reachable; one conversation state; live
voice ends when the tab is left; accessibility texts; greeting fix.

**Produced:**

- `docs/design/DESIGN.md` §10.1a (structure only) and a note in §6.5: the bar keeps four tabs with Emergency.
- `pages/HomePage.ets`: status strip + notes strip + the conversation. `pages/AgentPage.ets`: `AgentConversation`
  (the only conversation, embedded) and `AgentPage`, a see-through redirect that keeps `Routes.AGENT_CHAT` working
  for `MedicinesPage` (`AskParam`) and `ChatsPage` without editing them.
- `components/agent/HomeStatus.ets` (heart-rate chip + source badge, medicines chip, chats, settings),
  `HomeNotes.ets` (collapsible: greeting line, interactions, alarm chip, tip, travel banner), `QuickActions.ets`
  (Scan a box, Log how I feel, Doctor prep, Trends).
- `pages/Index.ets`: "ask the agent" clears the stack and selects tab 0 (not while SOS is on the stack); the
  check-in sheet is skipped when the conversation is in front; `onNavBarStateChange` reports pushed pages.
- `common/TabRequest.ets`: knows the selected tab and whether a page covers the tabs.
- `components/MainTabs.ets`: `accessibilityText` on all four tabs. `.fontSize(10)` on the SOS pill is left: no
  float token has the value 10 (`font_micro` 11, `font_mono` 9).
- Greeting: `dayGreeting()` in `AgentLogic.ets`; 00:00–04:59 says "Hi, {name}." (seen at 04:52 on the emulator).
- Voice welcome: the three starters are now one sideways-scrolling row (wrapped chips did not fit under the
  full-size orb together with the quick-action row).
- 9 new strings, inserted next to related keys.

**Validated** (216 tests pass, `assembleHap` builds; emulator, local backend, demo voice):

- Cold start lands on the orb with the restored chat — `shots/t1/a1_cold_start.jpeg`. Empty chat —
  `shots/t1/a1_empty.jpeg`.
- One tap on the mic starts the session ("Listening…"). The microphone did not open by itself.
- Live session ends on tab switch (Medicines and back: "Tap to talk") and when a page is pushed (Log how I feel
  and back: "Tap to talk").
- Notes strip opens: alarm chip, tip — `shots/t1/a1_notes_open.jpeg`.
- Chats button → Chats → New chat lands on tab 0 with an empty thread (redirect route).
- Medicines → Cipralex → "Ask the agent" lands on tab 0 with the question sent and a verdict card —
  `shots/t1/a1_ask_from_medicine.jpeg`.

**Not validated:** travel banner (needs a foreign location), interaction rows in the notes (profile has none),
settings gear tap, Doctor prep / Trends / Scan chips (same push as the tested one), check-in sheet suppression,
"ask" while SOS is on the stack, chat-mode welcome, screen reader output of the new accessibility texts.

**Known rough edges for the design pass:** the medicines chip is cut at the right edge of the status strip on a
377 vp wide screen (it scrolls sideways); New chat moved from the header to the Chats page (2 taps) or voice.

**Taps from cold start, before → after:**

| Feature | Before | After |
|---|---|---|
| Talk to the agent | 2 | 1 (orb or mic) |
| Doctor visit prep | 2 + scroll | 1 (quick action; swipe the row on a narrow screen), or one sentence |
| Symptom log | 2 + scroll | 1 (quick action) |
| Reminders | 2 + scroll | one sentence ("did I take my medicines?" → Reminders tile); Medicines tab + scroll unchanged |
| Settings | 1 | 1 (gear in the status strip) |
| Full emergency card | 1 + scroll | one sentence ("show my emergency card" → tile); Emergency tab unchanged (Workstream B) |
| SOS | 2 | one sentence ("call for help" → countdown); Emergency tab unchanged (Workstream B) |
| Saved chats | 1 | 1 |
| Trends | 2 + scroll | 1 (quick action; swipe the row) |

**README verify-table rows:**

| Feature | Where | Status |
|---|---|---|
| Agent is the home tab | tab 0 | verified on emulator |
| Quick actions (scan, symptom log, doctor prep, trends) | tab 0, above the dock | symptom log verified; others unverified |
| Notes strip (greeting, tip, alarm, travel) | tab 0, under the status strip | greeting, tip, alarm verified; travel unverified |
| Live voice ends when leaving the agent | tab switch, pushed page | verified on emulator |

## Needs from other tracks

None.
