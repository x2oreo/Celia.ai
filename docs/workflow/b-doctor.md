# S5 doctor

## AI_WORKFLOW entry
### 2026-10-03 — Georgi + Claude Code: doctor visits with questions (B6) and feeling diary (B15) (branch `georgi/b-doctor`)
- Asked: saved doctor visits (specialty, date, reason, worries → deterministic brief → AI summary), names and
  contacts stripped from free text before it leaves the phone, request validation in `/doctor-summary` extended
  with the banned-word / dose rejection kept, agent tile still opening prep on a specialty; a "How are you feeling?"
  diary stored as an `AppEvent` and a pure per-day count for Trends.
- Produced:
  - `doctor/Visit.ets` (model, clip, date check, upsert/remove/sort, tolerant parse), `doctor/VisitStore.ets`
    (setting `doctor_visits`), `doctor/Redact.ets` (`personalTerms(profile)`, `redactPersonal(text, terms)`).
  - `doctor/DoctorPrep.ets`: `buildBrief(..., visit?)` adds "This visit" and "What worries me"; diary moods as
    counts ("How I felt"); `visitDay()`. `doctor/DoctorSummary.ets`: `summaryFields(..., visit?, personal)` sends
    `reason` and `worries` redacted.
  - `pages/VisitsPage.ets` (list, upcoming first, add form, delete with confirm), `pages/DoctorPrepPage.ets` (opens a
    visit by id, specialty fixed, summary kept with the visit and re-checked on reopen, "My visits" row).
  - `diary/Diary.ets`, `diary/DailyCounts.ets` (`dailyCounts`), `diary/DiaryStore.ets`, `pages/FeelingPage.ets`,
    `widget/pages/FeelingCard.ets` (2×2 card → Feeling page).
  - `backend/supabase/functions/doctor-summary`: `reason` / `worries` optional strings (other types → 400),
    clipped to 300, e-mails / links / phones scrubbed again, `<` `>` removed, quoted to the model inside
    `<patient_words>` as data only. Reply checks unchanged.
- Validated: phone unit tests 227/227 (16 new: Redact, Visit, VisitBrief, Diary, DailyCounts), backend Deno 71/71
  (3 new), `deno check` of the function, phone build. Emulator: see screenshots below.
- Not validated: the AI summary with visit answers needs the function deployed (coordinator); until then the
  summary button on the emulator shows the existing failure line and the deterministic brief. The home-screen
  widget was built but not placed on the emulator home screen.

## README "How to verify" rows
| Doctor visits (B6) | Heart → Doctor report → My visits → Add a visit → pick Dentist, a date, a reason and a worry → Save. The brief opens with "This visit" and "What worries me". Back → the visit is listed under UPCOMING; tap it to reopen, bin icon → Delete. AI summary: needs the deployed `/doctor-summary` (built, unverified until deployed). |
| Redaction before the AI summary | Unit tests `Redact` / `summarySendsRedactedAnswersOnly`: names of the patient, contacts, cardiologist, hospital, phone numbers, e-mails and links become `[removed]`; Privacy ledger shows `reason`, `worries` field names only. |
| Feeling diary (B15) | Route `feeling` (agent home tile from Workstream A, or the "How are you feeling?" widget): pick a mood, optional note, Save → listed under RECENT. Low / Unwell offers "Log a symptom". |

## DESIGN.md subsection (new screens only)
- **Doctor visits** (pushed page, route `visits`; also "My visits" `NavRow` at the top of Doctor report): intro in
  `body` `ink_3`, primary `Add a visit` (plus icon), then `UPCOMING` / `PAST` caps headers and one card per visit
  (`surface`, 1 vp `border`, `radius_m`, 14 padding): specialty in `headline`, date in `body-sm` (`brand_text` when
  upcoming, `ink_3` when past), reason in `ink_2` (2 lines), "AI summary saved" caption, a 48 vp bin button in
  `ink_3` (asks first; Delete in `danger`). Empty: dashed card with `Add a visit`.
  Add form (same page): `title-3` "New visit", specialty chips (6.3, selected = ink), a 48 vp date row (date in
  `headline`, "Change date" in `brand_text`, opens the system date picker), reason input and worries area on
  `surface_alt`, privacy caption in `ink_3`, primary `Save and build the brief`, quiet `Cancel`.
- **Doctor report on a visit**: title "{Specialty} · {date}", no specialty chips, the visit sections first; the AI
  block caption says the summary is saved with the visit.
- **How are you feeling?** (route `feeling`): intro, five mood chips (44 vp, pill, ink when selected — moods are
  not verdicts, never risk colours), a neutral `surface` card offering `Log a symptom` for Low / Unwell, note
  area on `surface_alt`, primary `Save to diary` (inactive until a mood is picked), `RECENT` rows like the symptom log.
- **Feeling widget (2×2)**: `surface` card, `CELIA` caption in `ink_3`, "How are you feeling?" in `headline`, ink
  pill "Add entry" with plus icon.

## ARCHITECTURE notes
- Visits: JSON list under the encrypted RDB setting `doctor_visits`; no schema change. A checked AI summary is
  stored with its visit and re-checked with `parseSummary` before display.
- What leaves the phone for a visit summary: the same fields as before plus `reason` and `worries`, after
  `redactPersonal` (patterns + the profile's own names, numbers, e-mails, hospital as literal strings, whole-word,
  any script). The server scrubs patterns again. Free-text names of people not in the profile (e.g. "my aunt Ewa")
  are not detectable by rules and can still pass; the caption on the form says what is removed. Field names pass
  `FORBIDDEN_FIELDS` and show in the ledger.
- Diary: `AppEvent` kind `FEELING`, detail `{mood, note}`; notes never leave the phone and are not in the brief
  (only mood counts).

## For Workstream A (routes, functions, contracts)
- Routes: `visits` (saved visits), `feeling` (diary entry). `doctorPrep` with `new DoctorPrepParam(specialty)`
  works as before; `new DoctorPrepParam(specialty, visitId)` opens a saved visit.
- Trends: `DiaryStore.dailyCounts(days: number): Promise<DiaryDay[]>` (or pure
  `dailyCounts(events: AppEvent[], now: number, days: number): DiaryDay[]` from `diary/DailyCounts.ets`),
  `DiaryDay { day: 'YYYY-MM-DD'; feelings: number; lowFeelings: number; symptoms: number }`, one row per day,
  oldest first, same day key as `TrendDay.day`.

## Coordinator actions
- Deploy `doctor-summary` (request now accepts `reason` / `worries`; old requests without them still work).
