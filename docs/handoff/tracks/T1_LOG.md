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

## Needs from other tracks

None.
