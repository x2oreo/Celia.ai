# T3 - Screens: log

> Status (4 Oct 2026): working log, merged into `main` and folded into `AI_WORKFLOW.md`.

Branch `kaloyan/t3-screens`. Session of 4 October 2026 (emulator "Pura 90", 127.0.0.1:5555).

## Asked

`T3_screens.md`: A5 (UX pass, structure only, over nine pages and twelve components) and A6 (Trends with real data).
The look is out of scope: no new colours, sizes, radii or spacing tokens.

## Produced

### Shared header: `ScreenHeader` (`components/Common.ets`)

```ts
ScreenHeader({ title: $r('app.string.x') })                // pushed page: back, title, settings
ScreenHeader({ title: $r('app.string.x'), back: false })   // tab page: large title, settings
ScreenHeader({ title: ..., settings: false })              // no gear (e.g. the Settings page itself)
ScreenHeader({ title: ..., onDark: true })                 // scan surface
```

It takes `navStack` through `@Consumer('navStack')`, so back pops and the gear opens `Routes.SETTINGS` without any
callback. Built from what the pages already drew (`BackHeader` for pushed pages, `PageTitle` and the Home gear for
tabs). Used on all nine T3 pages. `BackHeader` and `PageTitle` stay for the pages that still call them (Emergency,
SOS). **T1 can use it as is.**

Pushed pages that used the system title bar (History, Symptom log, Reminders, Trends) now use `hideTitleBar(true)`
plus this header, like Check result and Chats already did.

### A5 per page

| Page | Structure changes |
|---|---|
| Heart | Header with gear. Chips under the ring: Log a symptom, Trends, Doctor prep (the three rows under the alerts are gone). |
| Medicines | Header with gear. Chips under the search: Reminders, History (the row under the grid is gone). |
| Check result | Header. "Try again" now reruns the check (it used to go back); "Check another medicine" also shown on failure. |
| History | Header. Empty: "Check a medicine" button. Filter with no match: "Show all checks". |
| Reminders | Header. No medicines: card with "Add a medicine" that opens the Medicines tab. |
| Symptom log, Chats, Scan | Header (Scan: on the dark surface, back instead of the close circle). |
| Trends | Header. Offline: "Try again". Watch sent no rows: plain message, never demo data. `WATCH` badge for real rows. |

Tap counts from Home:

| Feature | Before | After |
|---|---|---|
| Doctor prep | 2 + scroll (Heart tab, scroll, row) | 2 (Heart tab, chip) |
| Symptom log | 2 + scroll | 2 |
| Trends | 2 + scroll | 2 |
| Reminders | 2 + scroll (Medicines tab, scroll, row) | 2 (Medicines tab, chip) |
| Check history | 2, only when "Recently checked" is shown | 2, always |
| Settings | 1 from Home only | 1 from every T3 page |

### Bugs found and fixed on the way

- **Trends:** after switching 14 → 30 days the four tiles and the left date on the axis kept the 14-day values
  (`@Builder` arguments are passed by value). Tiles are now a small component, axis text is plain `Text`.
  Seen on the emulator before the fix ("of 14 days" and `21.09` on the 30-day view); `a5-trends-30.jpeg` shows the
  fixed state (`05.09`, "of 30 days").
- **Heart:** the Resting HR / HRV / Rhythm tiles had the same by-value problem; now a component.
- **Reminders:** the "Other" time chip never showed as selected (same cause). `a5-reminders-custom.jpeg`.

### Accessibility

- A verdict is read by its word: `RiskShape` speaks its risk label; where the shape sits next to its own word or is
  only a warning mark it is hidden from the screen reader. Medicine cards, history rows, recent-check chips, reminder
  rows and the add-medicine suggestions read "name, Known risk, …" as one sentence.
- One sentence per card: heart ring ("69, bpm · resting, SIMULATED"), heart chart (range in words), trend chart
  (days with a reading, range, dose and symptom days), stat tiles, alert rows ("Urgent alert, 165 beats per minute"),
  verdict header, interaction rows, info rows, chat rows, the reminder summary.
- Selected state on filter chips, symptom and activity chips, span chips, medicine and time choices.
- Long-press-only actions (rename / delete chat, delete reminder) are announced as a hint.
- Helpers in `Common.ets`: `resText`, `fmtText`, `strText` (resource → plain string for these sentences).

### Strings

37 new keys in `string.json`, each inserted next to related keys. Moved to resources: rhythm words, "N bpm",
"My medicines · N", "✓ Found: …", "… · interaction", "N / 5", message counts, barcode lines, expanded / collapsed,
"Not available yet", the "ask about this medicine" prompt. `trends_offline` copy now says "try again".

### A6 - Trends data path

- Path before: `loadTrends` → `Config.hasWatchCloud()` → false whenever `BACKEND_URL` is `127.0.0.1` → demo data.
  Requests used `Config.BACKEND_URL` + `Config.SUPABASE_ANON_KEY` (`'local-dev'` with the local AI proxy).
- Now: `trendsRoute()` in `vitals/Trends.ets` (pure, 3 new unit tests) picks
  `BACKEND` (app backend is the Supabase project), `SHARE` (AI backend is local: read
  `Config.SHARE_BACKEND_URL` with `LocalConfig.SHARE_ANON_KEY`) or `DEMO` (no backend, or no project key).
  The AI proxy stays on `127.0.0.1:8000`.
- To use it locally: put the project's public client key in the gitignored `LocalConfig.ets` as `SHARE_ANON_KEY`.
  In this worktree I copied `SUPABASE_PUBLISHABLE_KEY` from the gitignored `backend/supabase/functions/.env`
  (public client key, RLS applies). Nothing with a key is committed.
- **What is in the deployed project (read-only query, 4 Oct 05:00):** `demo-watch-1` (the watch this emulator reads)
  has one day, 2026-10-03, marked `simulated: true`, and one insight, also simulated. One other device id has one
  non-simulated day; the emulator is not paired with it. **So there are no real watch rows for the demo watch.** The
  page shows what the project returns and is labelled `SIMULATED`. Nothing was seeded.

## Validated (emulator, screenshots in `docs/handoff/tracks/shots/t3/`)

| What | Shot |
|---|---|
| Before: Home, Medicines, Heart, Heart scrolled | `before-*.jpeg` |
| Heart: header, chips visible without scrolling | `a5-heart.jpeg` |
| Doctor prep opened from the Heart chip | `a5-doctor-prep-from-heart.jpeg` |
| Medicines: header, Reminders and History chips | `a5-medicines.jpeg` |
| History, filter | `a5-history.jpeg`, `a5-history-filter.jpeg` |
| Check result reopened from history | `a5-check-result.jpeg` |
| Reminders, custom time selected | `a5-reminders.jpeg`, `a5-reminders-custom.jpeg` |
| Symptom log, Chats, Scan | `a5-symptom-log.jpeg`, `a5-chats.jpeg`, `a5-scan.jpeg` |
| Trends demo data 14 / 30 days, `SIMULATED` | `a5-trends-14.jpeg`, `a5-trends-30.jpeg` |
| Trends from the deployed project, 14 / 30 days, 13 and 29 empty days, insight list, `SIMULATED` (rows are marked simulated) | `a6-trends-real-14.jpeg`, `a6-trends-real-30.jpeg`, `a6-trends-real-30-insights.jpeg` |
| Trends offline (project URL pointed at a closed port), no badge, "Try again" stays on the same state | `a6-trends-offline.jpeg` |

`app/scripts/test.sh`: 214 tests pass (211 + 3 new). `assembleHap` builds.

The layout dump (`uitest dumpLayout`) confirms the grouped text of the medicine cards ("Known risk, Cipralex,
Depression and anxiety").

## Not validated

- **No screen reader run.** `accessibilityText` overrides, selected states and hints are in the code but were not
  heard with the screen reader on. The layout dump shows grouped child text only, not the overrides.
- Trends with real (non-simulated) watch rows and the `WATCH` badge: no such rows for the demo watch.
- Trends "watch sent no rows" card: no device without rows to read from.
- Trends offline was simulated with an unreachable URL, not by cutting the emulator's network.
- History empty states, Reminders "no medicines" card, Check result failure with retry: built, not triggered (the
  emulator profile has data and checks do not fail offline).
- Scan with a real barcode after the header change (the system scanner opens; no box in front of the emulator).
- Symptom-log red-flag SOS, medicine detail sheet, teach-box and box-candidate sheets: compile, not re-walked.

## For the design pass (left as is)

- Numeric font sizes with no token: `TimePicker` selected text `size: 22` (`RemindersPage`); `RiskShape` "?" is
  `dim * 0.55`. No other numeric `.fontSize(n)` in T3 files.
- Literal `lineHeight`, widths and radii in T3 files were not touched (21 literal line heights).
- Filter chips in History and Symptom log are about 36 vp tall, under the 48 vp touch minimum.
- Scan: the system status bar text is dark on the dark scan surface (was already so).
- Heart quick links wrap to two rows at this width; a designer may prefer another form.
- Still hard-coded: "Today" / "Yesterday" in `chatWhen` and `common/Format.ets`, activity names and symptom labels
  (`model/SymptomEntry.ets`), demo scenario names, the copied doctor question (`doctorQuestion`, text that leaves the
  app), the recent-symptom line in Symptom log.

## DESIGN.md §10.2, structure only (for the integrator; I did not edit DESIGN.md)

- Every screen: `ScreenHeader`: back (pushed pages), title, settings gear. Tab pages: large title, gear.
- Heart, top to bottom: header, ring, quick links (Log a symptom, Trends, Doctor prep), last minutes + three vitals,
  alerts, demo controls.
- Medicines: header, search + scan, quick links (Reminders, History), recently checked, my medicines grid.
- Every empty, error and offline state has one action (see table above).

## README verify-table rows

| Feature | How to check |
|---|---|
| One header on every screen | Open Medicines, Heart, History, Reminders, Symptom log, Trends, Chats, Check result, Scan: each has the title and a settings gear; pushed pages have a back arrow. |
| Heart quick links | Heart tab → chips under the ring: Log a symptom, Trends, Doctor prep. No scrolling. |
| Medicines quick links | Medicines tab → chips under the search: Reminders, History. |
| Trends (demo data) | No backend or local AI backend without `SHARE_ANON_KEY`: Heart → Trends shows 16 demo days, badge `SIMULATED`; 14 / 30 days switch updates chart, dates and tiles. |
| Trends (deployed project) | `LocalConfig.SHARE_ANON_KEY` = project public key, AI backend may stay on `127.0.0.1`: Heart → Trends shows the rows of `watch_daily_summary` for the paired watch, gaps as empty days, "What stands out" from `watch_insights`. `SIMULATED` shows when a row or insight is marked simulated. **Unverified with real watch rows.** |
| Trends offline | No connection → "Couldn't load your watch history" with "Try again". |

## Needs from other tracks / owner

- **Integrator:** `data/WatchDataClient.ets` is outside the T3 list; I added an optional `target` argument to
  `dailySummary` and `insights` (other callers unchanged). `LocalConfig.example.ets` could say that
  `SHARE_ANON_KEY` also feeds Trends; I did not edit it.
- **T1:** `ScreenHeader` is ready for `HomePage` / `AgentPage`. `MainTabs`, `HomePage`, `VoiceOrb` and `AgentCards`
  still have no `accessibilityText` (not T3 files). The "Morning at 01:10" greeting is in `HomePage`.
- **Workstream B:** Emergency, SOS, Settings, Doctor prep and the other B pages still use `BackHeader` / their own
  headers; switching is one line each.
- **Owner:** nothing to deploy. For Trends with real rows a watch must upload non-simulated days for the paired
  device id.
