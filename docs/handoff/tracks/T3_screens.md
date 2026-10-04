# T3 - Screens (A5, then A6)

> Status (4 Oct 2026): historical track brief; done and merged into `main`. Outcome in [`T3_LOG.md`](T3_LOG.md).

Read `docs/handoff/tracks/TRACKS.md` first (scope change, rules, emulator lock), then sections 3-7 of
`docs/handoff/KALOYAN_agent_and_ui.md`. Tasks A5 and A6 there are yours.

## Files you own

Pages: `MedicinesPage`, `HeartPage`, `ScanPage`, `CheckResultPage`, `HistoryPage`, `RemindersPage`,
`SymptomLogPage`, `ChatsPage`, `TrendsPage`. Components: `Common.ets`, `VerdictCard`, `HrRing`, `HrChart`,
`TrendChart`, `MedicineDetailSheet`, `MedicineInfoCard`, `IntakeCard`, `AddMedForm`, `TeachBoxForm`,
`BoxCandidateSheet`, `CheckInSheet`. Also `vitals/Trends.ets` and its test.

Not yours: `AgentPage`, `components/agent/*`, `MainTabs`, `HomePage`, `VoiceOrb`, `Index.ets` (T1);
`AgentCards.ets`, `agent/*`, `voice/*`, `backend/*` (T2); every page owned by Workstream B (Onboarding, Emergency,
Responder, Settings, Privacy, Doctor prep, SOS, Bystander, Pharmacy card, Pair watch, Lock screen).

## 1. A5 - UX pass, structure only

The look is out of scope (see the scope change in the README): same tokens, same components, no restyle. Per page:

- **One header.** Back (on pushed pages), title, settings. If `Common.ets` has no shared header, add one built from
  what the pages already draw and use it on all nine pages. T1 will reuse it; keep its API small and tell the owner
  its name.
- **One primary action** per screen, and no dead ends: every empty, error and offline state has a way forward.
- **Buried links move up.** Doctor prep and Symptom log sit at the bottom of Heart; Reminders at the bottom of
  Medicines. Put them where they are seen without scrolling, as rows or chips that already exist in `Common.ets`.
- **Accessibility:** `accessibilityText` on every control in `HeartPage`, `CheckResultPage`, `HistoryPage`,
  `SymptomLogPage`, `ChatsPage`, `VerdictCard`, `HrRing`, `HrChart`, `MedicineDetailSheet`, `IntakeCard`, then the
  rest of your files. Group decorative parts so a screen reader hears one sentence per card. A verdict is announced
  with its word (Known risk, Possible risk…), never by colour.
- **Numeric `.fontSize(n)`** in your files → the existing token of the same value. No token with that value: leave
  it and list it in your log for the design pass.
- **Hard-coded UI strings** in your files → `string.json` (insert next to related keys).

Go page by page: change, build, look at it on the emulator, commit. Screenshots under
`docs/handoff/tracks/shots/t3/`. Put the before / after tap counts for Doctor prep, Symptom log and Reminders in
your log.

## 2. A6 - Trends with real data

`Config.SHARE_BACKEND_URL` already defaults to the deployed Supabase project; `LocalConfig.BACKEND_URL` points at
`127.0.0.1` for the AI proxy. Find out which URL and key the Trends data path uses (`vitals/Trends.ets`,
`vitals/RestingHistory.ets`, `data/WatchDataClient.ets`) and make Trends read the real project while the AI proxy
stays local. `LocalConfig.ets` is gitignored and holds keys: change it locally if needed, never commit it, and ask
the owner for the anon key if it is missing.

Confirm on the emulator and record in your log: 14 and 30 days, days with gaps, the insights list, the offline
empty state, and the `SIMULATED` badge showing only when the data is demo data. If there are no real watch rows in
the project, say so plainly and leave the page labelled as demo data; do not seed fake rows into the shared
database.
