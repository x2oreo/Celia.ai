# Watch data for the phone and the agent

> Status (4 Oct 2026): current reference. The views are in `backend/supabase/migrations/`; per the README, `watch_vitals_daily` is not deployed to the live project yet.

The watch (`watch/`) uploads to `watch_metrics`. These read-only Supabase views turn it into something the phone
and the agent can use with one GET each (anon key, filter by `device_id`, demo device `demo-watch-1`). Rows with
`simulated = true` are demo data: label them in the UI.

| View | Use it for |
|---|---|
| `watch_status` | `ON_WRIST` / `OFF_WRIST` / `OFFLINE`. Show "Watch off wrist" instead of a disconnect alert. |
| `watch_doses` | "Took nadolol" taps on the watch (`name`, `taken_at`, `day`). |
| `watch_symptoms` | "How do you feel?" answers (`kind`, `bpm`, `recorded_at`). `fine` = check-in OK. |
| `watch_daily_summary` | One row per day: doses, symptoms (+ kinds), alerts, falls, SOS, resting HR. Doctor report. |
| `watch_insights` | Fixed-rule findings with a ready-made `message` and `severity` (see below). |
| `watch_resting_daily` | Daily resting HR (input of the missed beta-blocker check). |
| `watch_vitals_daily` | One row per day from the `vitals` snapshots: heart-rate average / lowest / highest, HRV, SpO2, breathing rate, sleep minutes, stress minutes, steps. The Health tab's metric cards and charts. HRV, SpO2 and breathing are simulated on the watch, so the phone always labels them SIMULATED. |

## `watch_insights` rules

| kind | severity | When |
|---|---|---|
| `SYMPTOM_AFTER_RISKY_DRUG` | WARN (CRITICAL if fainting) | Symptom within 24 h after `watch_context.risky_drug_at` |
| `FAINTING_REPORTED` | CRITICAL | "Fainting" answer in the last 7 days |
| `REPEATED_SYMPTOMS` | WARN | 2+ symptoms in the last 24 h |
| `NO_DOSE_LOGGED` | INFO | The person logs doses on the watch, but none in the last 26 h |

The texts are fixed in SQL (`20261003250000_watch_insights.sql`). The agent may explain them but must not change
the verdict or severity.

## Phone (Georgi) - suggested wiring

1. **Heart tab:** poll `watch_status`; on `OFF_WRIST` show "Watch off wrist" and don't raise `WATCH_DISCONNECTED`.
2. **Dose log:** for each `watch_doses` row whose `name` matches a med's ingredient or brand, store a `DoseLog`
   `{ status: 'TAKEN', day }` for that med's reminder. `RestingTrend` then words the beta-blocker question as
   "you logged every dose, so it may be something else" instead of "did you miss a dose?".
3. **Symptom log + doctor report:** add `watch_symptoms` rows (with HR) to the symptom log; use
   `watch_daily_summary` for the report's last 28 days (dose adherence = days with `doses_taken > 0`).
4. **Insights:** show `watch_insights` as cards (CRITICAL first). CRITICAL → offer "Call my cardiologist" / 112.

## Agent (Kaloyan) - suggested tools

- `get_watch_summary(days)` → `watch_daily_summary` rows, so "how was my week?" has real numbers.
- `get_watch_insights()` → `watch_insights`; on a CRITICAL insight start the conversation proactively
  ("You said you fainted earlier today…").

## SOS

The `sos` Edge Function already adds the last watch dose ("Last nadolol dose today 08:02" / "No nadolol dose logged
for 30 h") and any symptom from the last hour ("Reported dizziness at 17:58 (HR 142)") to the SMS and the call.
