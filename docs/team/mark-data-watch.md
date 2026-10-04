# Mark - Database, drug data & watch integration

> Status (4 Oct 2026): historical role brief. Built: Supabase backend, drug dataset, `LocalStore`, `DrugChecker`, `SimulatedSource`, `AlarmRules`. Changed: a custom watch app (`watch/`) with a cloud relay replaced phone-side Wear Engine, and the migration and data file names differ from this plan.

**You own:** the Supabase backend (schema, seed, `/drug-check` function, RLS), the curated drug dataset, the
on-device `LocalStore` (RDB), `DrugChecker`, and the whole vitals pipeline: Wear Engine (real watch) +
SimulatedSource (emulator) + AlarmRules.

Skills to load before coding: `harmonyos-kits`, `harmonyos-app-model`, `arkts-language`,
`supabase-postgres-best-practices`.

## First 2 hours (in order) - two clocks are ticking, start them first

1. **⏰ Apply for Wear Engine NOW.** It needs approval and may take hours or days.
   - Huawei developer console → create the app in AppGallery Connect with the agreed **bundle name** (get it from
     Georgie) → apply for Wear Engine access.
   - Permissions to request: device info, **monitor** (wear status, **heart-rate alarm**), **notify** (template
     notification on the watch), and the **HEALTH_SENSOR** human sensors (HR/PPG/ECG; restricted access).
   - Also ask the mentors to fast-track it. The error you'll see until it's approved is: "App has not applied for
     the Wear Engine service".
2. **⏰ Borrow a HarmonyOS phone (API 20+)** from the mentors and pair the GT5 Pro / GT6 Pro to it via the Huawei
   Health app. Check: `wearEngine.getDeviceClient(ctx).getConnectedDevices()` lists the watch.
3. **Supabase project** - **EU region (Frankfurt)**, which supports the sovereignty pitch. Share the URL and anon key
   with the team privately (Discord DM), never in git. Re-enable the Supabase MCP in `.claude/settings.local.json`
   if you want Claude to help.
4. **Schema migration** `backend/supabase/migrations/0001_init.sql`:
   - `drugs(id, ingredient text unique, atc_code, risk text check in ('KNOWN_RISK','POSSIBLE_RISK','CONDITIONAL_RISK'), reason text, source text)`
   - `drug_aliases(alias text primary key, drug_id → drugs)` - brand names (PL/EN/DE), misspellings
   - `agent_logs(id, ts, kind, detail jsonb)` - de-identified, for debugging only
   - RLS: anon may `select` drugs and aliases; nobody may write from the client.
5. **Curated dataset** `data/drugs.csv` (~60–100 common drugs, focusing on things people actually get prescribed:
   macrolide and fluoroquinolone antibiotics, ondansetron, domperidone, citalopram/escitalopram, haloperidol,
   methadone, hydroxychloroquine, some antihistamines, plus common *safe/not listed* ones like paracetamol and
   ibuprofen so the demo shows both outcomes). Include Polish brand names in the aliases. Cite the categories'
   source (CredibleMeds) and note the licensing caveat.
   A script turns the CSV into `seed.sql` **and** `app/entry/src/main/resources/rawfile/drugs.json` (one source of
   truth).

## Then (T+2h → T+16h)

1. **`/drug-check` Edge Function**: normalise the query (lowercase, trim, strip dose/form words like "500 mg",
   "tabletki") → alias match → ingredient match → fuzzy match (trigram `pg_trgm`) → `DrugVerdict`. Unknown →
   `UNKNOWN_DRUG` (never "safe").
2. **`DrugChecker.ets`** in the app: same algorithm on the bundled `drugs.json` (offline), with the online endpoint
   as an optional refresh. Must also find a drug name **inside noisy OCR text** (scan the tokens against aliases).
   **Unit tests:** brand → ingredient, misspelling, OCR blob, unknown drug, dose suffix.
3. **`LocalStore.ets`** (ArkData RDB): profile, meds, events, vitals (keep only the last 24 h of samples).
   Stub it on day 1 with in-memory data so Georgie can build screens.
4. **Vitals pipeline** (`vitals/`):
   - `VitalsSource` interface → `WearEngineSource` (real) and `SimulatedSource` (emulator).
   - `WearEngineSource`: `getConnectedDevices` → pick the device → MonitorClient `subscribeEvent` for
     `EVENT_HEART_RATE_ALARM` + `EVENT_WEAR_STATUS_CHANGED` + connection status; SensorClient for the HR stream if
     HEALTH_SENSOR is approved; NotifyClient to push an alert to the watch.
   - `SimulatedSource`: scripted scenarios - `normal`, `lqt2_startle_tachy` (resting → 165 bpm),
     `lqt3_night_brady` (38 bpm while sleeping), `watch_disconnect`.
   - `AlarmRules`: thresholds per genotype (configurable), debounce (sustained ≥ 15 s), emits `VitalsAlert`.
     **Unit tests** for each scenario.
   - Log every alert to `LocalStore.logEvent`.
5. Document in README which parts need a real device, and how to run the simulated scenarios on the emulator.

## Definition of done

- `drug-check` and `DrugChecker` give the same verdicts (shared test cases).
- The emulator demo runs on SimulatedSource with zero code changes; the real phone switches to WearEngineSource.
- If Wear Engine is never approved: the demo uses simulated data, and the README/video explain the real path and
  show the `WearEngineSource` code. That still scores; the claim just has to be honest.
