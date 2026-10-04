# Mark: early watch & Long QT context notes

> Status (4 Oct 2026): early background notes, kept for the hardware findings and LQTS background. See the warning below.

> ⚠️ **Written before the team plan existed.** `docs/ARCHITECTURE.md`, `docs/IDEA.md` and `docs/PLAN.md` win on
> architecture and scope: phone-side Wear Engine, on-device data, Supabase Edge Functions, no custom watch app,
> no NestJS and no `metrics` table. Use this file for the **hardware findings (§3–4)**, the **Long QT background (§2)**
> and the **future-conditions ideas (§8)**.

This is the background document for anyone working on this repo, people or AI agents. It records what we're building, the hardware we actually have, what's real and what's mocked, and the decisions made so far. Read it before writing code.

> Written 2026-10-03, before the team plan was pushed.

---

## 1. What we're building

**Celia.ai is a companion app for people living with Long QT Syndrome (LQTS).** It has a Huawei watch app and a phone app, connected through our own backend.

The watch collects what it can (mainly heart rate and quick inputs from the user) and sends **small computed metrics** to the server. The phone app **fetches** them from the server and shows them together with medication tracking, QT-drug safety checks and history.

**Long-term vision:** the watch → server → phone pipeline is a **platform**. Long QT is the first condition. Later the same platform can support other conditions such as Parkinson's, Huntington's and MS, using movement tests (accelerometer and gyroscope) instead of heart rate. Design the data model and API so that a new condition means adding new metric types, not rewriting the pipeline (see §7).

### Not in scope
- Diagnosing Long QT, or measuring the QT interval from the watch. It's impossible (see §3).
- Medical-device claims. We're a wellness and companion tool for **already-diagnosed** patients (see §10).

---

## 2. Long QT background (what the team needs to know)

- **What it is:** a heart rhythm disorder where the heart takes longer than normal to recharge between beats, shown as a long QT interval on an ECG. It can trigger a dangerous arrhythmia (**torsades de pointes**, TdP), which causes fainting, seizures or sudden cardiac death.
- **Congenital vs. acquired:**
  - *Congenital:* genetic. The main types are:
    - **LQT1** (KCNQ1): events triggered by **exercise**, especially **swimming**.
    - **LQT2** (KCNH2): events triggered by **sudden noise** (alarm clock, phone ringing), emotional stress and the postpartum period.
    - **LQT3** (SCN5A): events during **rest or sleep**, often with a **slow heart rate**.
  - *Acquired:* caused by **QT-prolonging drugs**, low potassium or magnesium (vomiting, diarrhoea, diuretics), or other conditions.
- **QTc** is the QT interval corrected for heart rate. Bazett's formula: `QTc = QT / sqrt(RR)` (RR in seconds). Rough thresholds: prolonged above about 470 ms (men) or 480 ms (women); **high risk at 500 ms or more**.
- **Management:**
  - **Beta-blockers** (nadolol, propranolol). **Taking them every day matters.**
  - **Avoid QT-prolonging drugs.**
  - Keep electrolytes normal ("sick-day rules": if vomiting or diarrhoea, call the doctor).
  - Avoid known triggers for the patient's type.
  - Sometimes an ICD (implanted defibrillator).
  - **Family screening**, since it's genetic.
- **Drug lists:** CredibleMeds (crediblemeds.org) classifies drugs as *Known Risk of TdP*, *Possible Risk*, *Conditional Risk* and *Drugs to Avoid in Congenital LQTS*. ⚠️ **Licensing:** CredibleMeds data has terms of use. Check them before shipping beyond a hackathon demo.

> The team already has a **drug-safety scanner and database** with these risk categories (for example, domperidone is `KNOWN_RISK`). Where it lives and its exact schema aren't recorded here yet. **TODO: link it and describe its schema in this file.**

---

## 3. What the hardware can actually do

### Devices we have
| Device | Notes |
|---|---|
| **Huawei Watch GT 6 Pro** | A **lite wearable**. See below. |
| **iPhones** (several) | The GT 6 Pro pairs with them through the Huawei Health iOS app. |
| **No Huawei or Android phone** | So the HarmonyOS phone app runs **only in the DevEco Previewer or emulator**. |
| Mac with **DevEco Studio** | Used for HarmonyOS and lite wearable development. |

### Lite wearable vs. full wearable (important)
- The **Watch GT series runs "lite wearable" HarmonyOS**. Apps are written in **JS + HML + CSS** (a lite JS project in DevEco), with a small API set.
- Only the full-HarmonyOS watches (**Watch 5, Watch Ultimate**) run ArkTS "wearable" apps. **ArkTS wearable code does not run on the GT 6 Pro.**
- The lite API covers sensors (accelerometer, gyroscope, heart rate, depending on model and API level), vibration, storage, timers, device and battery info, and location. It does **not** appear to include an HTTP or network API.

### Health signals: real vs. impossible
| Signal | On the GT 6 Pro for our app? |
|---|---|
| Heart rate (PPG, BPM) | ✅ Live through the lite sensor API, while our app is open |
| Accelerometer / gyroscope | ✅ Live, up to about 50 Hz, while our app is open |
| Taps and button input | ✅ |
| Vibration alerts | ✅ |
| Running in the background all day | ❌ Effectively no. Lite apps record only while open. |
| **QT interval / QTc** | ❌ **Impossible.** PPG can't measure QT; that needs an ECG. |
| ECG (raw or reports) | ❌ Even if the GT 6 Pro has Huawei's own ECG feature (check by model and region), third-party apps can't access it. |
| HRV / RR intervals, raw PPG | ❌ |
| SpO2, sleep, skin temperature, stress | ❌ live. ⚠️ Only after the fact through Huawei Health. With iPhones, part of it syncs to Apple Health. |
| Irregular rhythm / AFib alerts | ❌ Huawei's own apps only |

**So for Long QT, the watch is a heart rate monitor, an alert device and a quick input device.** QTc values come from **manual entry** (from a clinic ECG or the Huawei ECG app's report) or from **mock data**.

---

## 4. Known blockers and risks (check these first)

1. **Watch → server networking.** Lite wearable apps appear to have **no HTTP API**. Huawei's documented route is **watch → Wear Engine (Bluetooth) → phone app → internet**. Huawei also says a GT watch paired with an **iPhone can't use the phone's network over Bluetooth**. Our phone app runs only in the Previewer, which can't pair with a watch.
   → The planned "watch POSTs metrics to the server" may **not work on real hardware**. See the fallbacks in §6.
2. **Installing on the GT 6 Pro.** Lite apps are installed through the **DevEco Assistant** app on an **Android or Huawei phone** (build the .hap in DevEco, transfer it to the phone, install it on the watch). **We only have iPhones**, so we may not be able to install on the watch at all.
   → Ask the hackathon organizers whether they lend **Huawei or Android phones**.
3. **API level mismatch.** If the project's API level is higher than the watch firmware supports, install fails with "Error 40". Match the GT 6 Pro's supported API level.
4. **Wear Engine access.** We don't have it yet. You apply for it in the Huawei developer console / AppGallery Connect, and it needs a real Android or Huawei phone.
5. **The Previewer is limited.** It shows UI and can call HTTP (`localhost` is the Mac), but has no sensors, push notifications, background tasks or Huawei kits.

**First task of the hackathon:** a 30-minute smoke test. A hello-world lite JS app that reads heart rate and shows it, installed on the GT 6 Pro. If it fails, switch to the "watch simulator" fallback straight away.

---

## 5. Architecture

```
┌──────────────────────┐   POST /api/metrics    ┌────────────────────┐        ┌──────────┐
│ GT 6 Pro (lite JS)   │ ─────────────────────▶ │ Backend (REST API) │ ─────▶ │ Postgres │
│ HR monitor, alerts,  │   (or via fallback)    │ validation, rules, │        │ Supabase │
│ symptom/med buttons  │                        │ seeding            │ ◀───── │ + RLS    │
└──────────────────────┘                        └────────────────────┘        └──────────┘
                                                          ▲
                                     GET /api/metrics ... │
                                                          │
                                   ┌──────────────────────┴──┐
                                   │ Phone app (HarmonyOS,   │
                                   │ ArkTS, DevEco Previewer)│
                                   │ dashboard, meds, QT drug│
                                   │ checker, history charts │
                                   └─────────────────────────┘
```

- **The watch sends small computed metrics, not raw sensor streams.** Example: average and max heart rate over a window, not every sample.
- **The phone only fetches**: on open, on pull-to-refresh, or by polling every few seconds during the demo. No push notifications (they don't work in the Previewer).
- **The server is the single source of truth**: real watch metrics plus **seeded mock history**, labelled as mock.

### Suggested stack (based on what the team already knows)
These come from the team's earlier HarmonyOS fitness project, which used the same pattern:
- **Phone:** HarmonyOS ArkTS/ArkUI app in DevEco Studio. Shared HTTP client; base URL `http://localhost:<port>/api` in the Previewer and `http://10.0.2.2:<port>/api` in the emulator.
- **Watch:** a DevEco **Lite Wearable JS project** (HML/CSS/JS).
- **Backend:** NestJS (TypeScript) REST API. Vercel, Render, Railway or Fly.io later; local for the demo.
- **Database and auth:** Supabase (Postgres, Row Level Security, Supabase Auth with a JWT as `Authorization: Bearer`).

### Suggested repo layout
```
phone/        HarmonyOS phone app (ArkTS) – DevEco project
watch/        Lite wearable app (JS/HML/CSS) – DevEco lite project
backend/      REST API (NestJS)
supabase/     migrations, RLS policies, seed SQL
docs/         this file, API notes, pitch material
```

---

## 6. What's real vs. mocked (hackathon scope)

### Watch (GT 6 Pro)
| Feature | Real/Mock | Notes |
|---|---|---|
| Live heart rate display | ✅ Real | Lite sensor API |
| **Heart rate limit alert** (vibrate above the user's limit, important for LQT1 during exercise on beta-blockers) | ✅ Real | Limit set on the phone; watch compares live HR |
| **Low heart rate alert** (relevant to LQT3) | ✅ Real while the app is open | Not overnight; no background running |
| **"I feel unwell" button** (palpitations / dizziness / fainting) | ✅ Real | Creates a `symptom` metric with the current HR |
| **Beta-blocker reminder + "taken" button** | ✅ Real (timer-based) | Creates a `medication_taken` metric |
| Session summary (avg/max/min HR over a session) | ✅ Real | Computed on the watch, sent as one metric |
| Overnight or all-day HR | ❌ Mock | Needs background running / Health Kit |

### Phone (Previewer)
| Feature | Real/Mock | Notes |
|---|---|---|
| Dashboard: latest HR, alerts, symptoms from the watch | ✅ Real (fetched) | `GET /api/metrics` |
| **QT drug checker** (search or scan a drug → risk category) | ✅ Real | The team's existing scanner and database |
| Medication schedule + adherence chart | ✅ Real logic, history seeded | |
| **Interaction warning:** a new drug is `KNOWN_RISK`, or several QT drugs are combined | ✅ Real | Rule on the backend |
| **QTc log** (manual entry from an ECG report) + trend chart | ✅ Real entry, history seeded | Bazett calculator if the user enters QT and HR |
| Sick-day / electrolyte warning (vomiting, diarrhoea, new diuretic) | ✅ Real (rule + UI) | |
| LQT type profile (1/2/3) → trigger tips (swimming, alarms, sleep) | ✅ Real (static content) | |
| Emergency card ("I have Long QT; avoid these drugs") | ✅ Real | |
| 2-week HR, sleep and symptom history | ⚠️ Mock (seeded) | Label it "from Huawei Health (after Huawei approval)" |
| ECG / QT from the watch | ❌ Not possible | Say so in the pitch |

### Fallbacks for the watch → server link (see §4)
Keep the server and phone code identical in every mode:
1. **Best case:** the watch reaches the server directly, or through Wear Engine and a borrowed Android or Huawei phone.
2. **Watch works, no network:** the watch shows results on screen, and the phone has a hidden **"simulate watch upload"** button that POSTs the same metric.
3. **Can't install on the watch:** run the lite app in DevEco's **lite wearable simulator** with simulated HR, and present real hardware as the next step.

---

## 7. Data model and API (platform-friendly)

All measurements go into one generic **metrics** table, keyed by `type`. A new condition means new metric types and new UI, not new tables or endpoints.

### Table `metrics`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK → auth.users | RLS: users see only their own rows |
| `type` | text | e.g. `hr_session`, `hr_alert`, `symptom`, `medication_taken`, `qtc_entry` (later `tremor_test`, `tap_test`, …) |
| `values` | jsonb | Payload specific to the type (see below) |
| `recorded_at` | timestamptz | When it happened on the device |
| `source` | text | `watch` \| `phone` \| `mock` \| `simulated` |
| `created_at` | timestamptz default now() | |

Other tables: `medications` (user's drugs, dose, schedule), `profiles` (LQT type, sex, HR limits, emergency contact), and the existing **drug risk database**.

### Metric payloads (`values`)
```jsonc
// hr_session: summary of a watch session
{ "avgBpm": 78, "maxBpm": 131, "minBpm": 61, "durationSec": 900 }

// hr_alert: limit crossed
{ "bpm": 152, "limitBpm": 140, "direction": "high" }   // or "low"

// symptom: "I feel unwell" button
{ "kind": "palpitations", "bpm": 118 }                  // palpitations | dizziness | fainting | other

// medication_taken
{ "medicationId": "uuid", "name": "nadolol", "scheduledFor": "2026-10-03T08:00:00Z" }

// qtc_entry: manual entry from an ECG report
{ "qtMs": 440, "rrMs": 800, "qtcMs": 492, "method": "bazett", "origin": "clinic_ecg" }
```

### Endpoints (REST, JSON, `Authorization: Bearer <jwt>`)
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/metrics` | Watch or phone sends one metric `{ type, values, recordedAt, source }` |
| `GET` | `/api/metrics?type=&from=&to=` | Phone fetches the list, newest first |
| `GET` | `/api/metrics/latest` | Latest metric of each type, for the dashboard |
| `GET` | `/api/drugs/search?q=` | Drug risk lookup |
| `POST` | `/api/medications/check` | Check a drug against the user's current meds → warnings |
| `GET/PUT` | `/api/profile` | LQT type, HR limits, etc. |
| `POST` | `/api/dev/seed` | Dev only: seed 2 weeks of mock data for the current user |

**Auth on the watch:** a lite watch can't easily do a full login. For the hackathon, use a **long-lived device token** created on the phone and typed in or hard-coded on the watch, or a single demo user. Keep that path separate from real user auth.

---

## 8. Future platform: other conditions

Same pipeline, new metric types, computed on the watch from the accelerometer and gyroscope (~50 Hz, active tests while the app is open):

| Condition | Watch tests (realistic on GT) | Metric types |
|---|---|---|
| Parkinson's | Resting / postural tremor test (dominant frequency 4–6 Hz + strength), finger tapping (speed, rhythm, slowdown), arm swing while walking | `tremor_test`, `tap_test`, `gait_test` |
| Huntington's | "Hold still" test (chorea = irregular movement), tapping-rhythm irregularity | `stillness_test`, `tap_test` |
| MS | 2-minute walk (steps, cadence), finger-to-nose (intention tremor), phone-based thinking-speed test | `walk_test`, `intention_tremor_test`, `sdmt_test` |

Notes for later:
- Do frequency analysis cheaply on the watch (zero-crossings or autocorrelation), or send a short raw burst (15 s × 50 Hz × 6 axes ≈ 30 KB JSON) for the server to analyse if the network allows.
- With iPhones, the **iPhone** (CoreMotion at ~100 Hz, HealthKit walking metrics, ResearchKit tremor and tapping tasks) is a stronger movement sensor than the GT watch. Apple Watch has a **Movement Disorder API** for Parkinson's. Keep this in mind if the platform goes cross-platform.
- The drug-safety engine generalises too: add disease-specific "avoid" lists (e.g. tetrabenazine and deutetrabenazine for Huntington's; fingolimod and siponimod for MS).

---

## 9. Development notes

- **Previewer networking:** `localhost` = the Mac, so the backend must run locally (`npm run start:dev`). Allow cleartext HTTP for local URLs.
- **Emulator networking:** the Mac is reachable at `10.0.2.2`.
- **Real devices:** use the Mac's Wi-Fi IP, or the deployed HTTPS URL.
- **The Previewer has no sensors.** Use mock data or the "simulate watch upload" button.
- **Lite wearable apps:** use the DevEco lite wearable simulator for UI. On real hardware, install through DevEco Assistant on an Android or Huawei phone.
- **Debug-signed apps on real devices** need Huawei ID automatic signing (File → Project Structure → Signing Configs). The certificate expires; reinstall when it does.
- **Always label mock data** (`source: "mock"`) and show a small "demo data" badge in the UI.

---

## 10. Regulatory and privacy (pitch and future)

- Software that **diagnoses or monitors a disease** is a **medical device** (EU MDR, US FDA software as a medical device). For now: a **companion and wellness app for diagnosed patients**, with no diagnosis claims, and **always "talk to your cardiologist"**.
- Drug warnings are **information, not prescribing advice**.
- Health data is **special-category data under GDPR**: explicit consent, a data protection impact assessment, EU hosting, RLS on every table, no health data in logs.
- Check CredibleMeds licensing before any non-demo use (§2).
- Huawei Health Service Kit / Health Kit and Wear Engine require **applying for and getting Huawei's approval for each data type**. We don't have these, which is why that data is mocked.

---

## 11. Demo script (draft)

1. Phone: profile "LQT1, on nadolol, HR limit 140".
2. Watch: start a session and show live HR. Raise HR (stairs or jumping) until the watch **vibrates with a high-HR alert**. The phone refreshes and shows the alert.
3. Watch: press **"I feel unwell → palpitations"**. It appears on the phone with the HR at that moment.
4. Phone: the doctor prescribes **domperidone** → the drug checker flags **KNOWN_RISK**, plus a combination warning.
5. Phone: QTc trend (seeded) with a newly entered reading of **492 ms** → shown as "above 480", with a sick-day / electrolyte tip.
6. Pitch: "Same pipeline next supports Parkinson's (tremor), Huntington's and MS," shown as the roadmap.

---

## 12. Open questions / TODO

- [ ] Can the organizers lend a **Huawei or Android phone**? This decides the Wear Engine and install path.
- [ ] Smoke test: does a lite JS app with heart rate install and run on the **GT 6 Pro**? Which API level?
- [ ] Does the lite runtime on the GT 6 Pro have **any** network API? If not, use fallback 2 or 3.
- [ ] Where is the **existing drug-safety database and scanner**? Link it and describe its schema here.
- [ ] Final stack choice (NestJS + Supabase suggested). Create the Supabase project.
- [ ] Hackathon task description and rules: check the scope against them.
- [ ] Decide the watch auth approach (device token vs. demo user).
