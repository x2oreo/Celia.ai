# T1 - Agent home (A3 → A1 → A2)

> Status (4 Oct 2026): historical track brief; done and merged into `main`. Outcome in [`T1_LOG.md`](T1_LOG.md).

Read `docs/handoff/tracks/TRACKS.md` first (scope change, rules, emulator lock), then sections 3-7 of
`docs/handoff/KALOYAN_agent_and_ui.md`. Tasks A3, A1 and A2 there are yours, in the order below.

## Files you own

`pages/AgentPage.ets`, `components/agent/*` (new), `components/MainTabs.ets`, `pages/HomePage.ets`,
`pages/Index.ets` (only the agent route and tab wiring; Workstream B adds its own routes there),
`components/VoiceOrb.ets`, `components/AgentAvatar.ets`, `common/Motion.ets`, `common/TabRequest.ets`,
`docs/design/DESIGN.md`. Tests for anything pure you extract go in `app/entry/src/test/`.

Not yours: `agent/*`, `voice/*`, `backend/*`, `components/AgentCards.ets` (T2); every other page and
`components/Common.ets` (T3). You may call them, not edit them.

## 1. A3 - split `AgentPage.ets` (do this first, ask for a merge as soon as it is green)

Pure refactor, behaviour unchanged. Target shape in `components/agent/`:

- `VoiceStage.ets`: orb, state label, demo badge.
- `AgentThread.ets`: turns, live turn, bubbles, tool steps, starters.
- `ActionCards.ets`: the `actionView` switch (verdict card, confirm cards, tiles, `OPEN_PAGE`).
- `AgentDock.ets`: voice dock and chat bar.
- The page keeps state, subscriptions and the voice / send / scan logic.

Must still hold: `onMic()` order (live session, then tap-to-talk), `OPEN_PAGE` tiles, the demo badge, the "type
instead" strip, restored chats keeping display cards only (`model/Chat.ets` `keepOnRestore`), verdict colour taken
from the deterministic payload. Keep `OPEN_PAGE` handling in one obvious place: T2 adds page values there right
after your merge.

Check: 211 tests pass, the app builds, and one text turn plus one demo-voice turn look the same on the emulator.

## 2. A1 - the agent is tab 0

Write the layout into DESIGN.md first (new subsection under §10, structure only), and state there that the bar keeps
four tabs with Emergency. Then build:

- Tab 0 renders the agent conversation itself. Top to bottom: status strip (heart-rate chip with source badge,
  "N to review" chip, chats, settings gear), the orb with its state label, the thread or the welcome with starter
  chips, a quick-action row (Scan a box, Log how I feel, Doctor prep, Trends), the dock.
- Greeting, tip of the day and travel banner move into one collapsible strip or agent-voiced lines. Nothing the old
  Home offered may become unreachable. Fix the greeting that says "Morning" at 01:10.
- `Routes.AGENT_CHAT` has callers that open the chat with a question (`AskParam`). Keep them working: either the
  route stays as a thin wrapper around the same component, or callers switch tab and hand the question to
  `AgentPrompt`. One conversation state, not two.
- The embedded agent no longer gets `aboutToDisappear` on a tab switch. End the live session when the tab changes
  or a page is pushed over it. The microphone never opens by itself.
- Saved chats one tap away. The SOS pill stays always tinted.
- `accessibilityText` on every control in `MainTabs`, `VoiceOrb` and the new components. Replace the numeric
  `.fontSize(10)` in `MainTabs` with the existing token of the same value if there is one; otherwise leave it and
  note it.

Acceptance: cold start lands on the orb; one tap starts talking; every row of the "Known UX problems" table in the
workstream brief is reachable in at most 2 taps or one sentence. Put the before / after tap counts in your log.

## 3. A2 - the orb as a stage (behaviour only, not the look)

- Full-height voice stage while a session is live and nothing has been said; compact when a thread exists (today's
  168 → 84 step). Layout and sizes from existing tokens.
- Halos already follow `level`. Confirm on the emulator that listening / hearing use `RealtimeSession.onLevel` and
  speaking uses the playback level; fix the wiring if a state has no level signal.
- Reduced motion: `Motion.reduced` is hard-coded `false`. Find the system setting in Context7, read it at start and
  on change, drop loops to static when it is on. If API 20 exposes no such setting, say so in DESIGN.md §8 and your
  log; do not invent one.
- Every state keeps its text label. No waveform or pulse line.
- Do not change gradients, colours, halo opacities or sizes: the owner's Claude Design pass decides those.

Acceptance: with `DEMO_VOICE_INPUT` on, screenshots of connecting → listening → hearing → thinking → speaking →
listening, saved under `docs/handoff/tracks/shots/t1/` and listed in your log.

## When the owner brings the Claude Design output

Apply it to the agent home and orb in one commit per component, tokens into `color.json` / `float.json` and
DESIGN.md first. Until then, no visual changes.
