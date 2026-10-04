# B-widgets: home-screen widgets v2

> Status (4 Oct 2026): built and merged into `main` (widgets v2, DESIGN.md section 11).

Branch `georgi/b-widgets`, based on `kaloyan/agent-home`. Spec: DESIGN.md §11 "Home-screen widgets v2".

## Goal

The app had four cards: two static (Can I take this?, How are you feeling?) and two emergency (Medical alert, Medical
ID). None of them showed the user's own day. v2 adds three live cards and makes the two static ones useful, so the
home screen carries the agent, the next dose and the heart without opening the app.

| Card | Status | Data |
|---|---|---|
| The agent (2×2, 2×4, default) | new | HomeBrief line (deterministic, same sentence as Today) |
| Next dose (2×2) | new | reminders + dose log, recomputed by the clock in the form extension |
| Resting heart rate (2×2, 2×4) | new | `loadTrends` 14 days → `Metrics` band/status, last live sample |
| Can I take this? (2×2, 2×4) | redesigned | last three scans with their deterministic risk |
| How are you feeling? (2×2, 2×4) | redesigned | last FEELING event; one-tap moods |
| Medical alert, Medical ID | unchanged | profile + medicines |

## Architecture

- `widget/WidgetModel.ets` (pure, unit-tested): `buildSnapshot(inputs, now)` → `WidgetSnapshot` (flat strings and
  numbers only; cards cannot import app code), and `applyDose(snapshot, reminders, logs, now)` for the clock-driven
  recompute. Uses `DoseSchedule` and `Metrics` (both pure).
- `widget/WidgetData.ets`: snapshot stored as one JSON value in the `widget_snapshot` Preferences file, plus the raw
  reminders and dose log for the extension, plus a form registry `formId → dimension`.
- `widget/WidgetSync.ets`: rebuilds on store changes and on HomeBrief changes, trends at most every 15 min, the
  live sample at most every 5 min; pushes only when the JSON changed. Each form gets the snapshot + `wide`.
- `EntryFormAbility`: `onAddForm` registers id + dimension; `onUpdateForm` (every 30 min, `updateDuration: 1`)
  re-applies the dose state for the clock; `onRemoveForm` unregisters.
- `EntryAbility.handleCardTap`: new targets `agent`, `take`, `reminders`, `heart`, `history`, `feeling:<MOOD>`.
  `take` uses `ReminderService.takeNext` (same rule as the notification's Taken: due, else earliest missed).
- `FeelingPage` reads a one-shot mood prefill (`diary/FeelingPrefill.ets`).

## Tasks

1. DESIGN.md spec (done first, CLAUDE.md rule).
2. WidgetModel + tests.
3. WidgetData storage + form registry.
4. WidgetSync sources and throttling.
5. EntryFormAbility clock recompute + dimension.
6. Cards: AgentCard, DoseCard, HeartCard; CheckCard and FeelingCard 2×4; `form_config.json`; strings.
7. Card tap routing, take-dose, feeling prefill.
8. Build, unit tests, emulator: add each card, screenshots.

## Safety

- No model output on any card. Risk words and shapes come from `ScanRecord.risk`; heart status from `Metrics`.
- Dose card uses neutral dose styling (6.9). `Taken` never logs an upcoming dose.
- Home-screen visibility: only medicine names (dose, recent checks) beyond what Medical ID already shows.
