# Celia.ai — the idea

> Working name. **Naming risk:** "Celia" is the international name of Huawei's own system assistant (小艺 / Xiaoyi).
> Using it for our product is ambiguous (judges are Huawei). Options: keep `Celia.ai` as repo name and give our agent
> its own persona name, *integrating with* Huawei's Celia via Intents Kit. Decide in the first hour.
> Below: **"the agent"** = our in-app agent; **"Celia"** = Huawei's system assistant.

## One-liner

An **agent-first heart-safety companion for people with Long QT syndrome** on HarmonyOS: an AI agent you can talk
to about your syndrome, that checks every medicine before you take it, watches your heart through your Huawei watch,
and takes over in an emergency — with your health data staying on *your* devices.

## Problem

- **Long QT syndrome (LQTS)**: inherited ion-channel disease, ~1 in 2,000 people. Can trigger *torsades de pointes*
  → fainting or sudden cardiac death, often in young people.
- Triggers are known and preventable: **hundreds of common drugs prolong QT** (antibiotics, antiemetics,
  antidepressants, antihistamines…), low potassium/magnesium (vomiting, diarrhoea), and genotype-specific triggers
  (LQT1 exercise/swimming, LQT2 sudden noise/emotion, LQT3 rest/sleep).
- Patients have to remember all this alone, at the pharmacy, abroad, or at the ER — where staff may not know LQTS.

## Solution — an agent at the centre, the ecosystem around it

| Layer | What it does | HarmonyOS capability |
|---|---|---|
| **Agent (chat + voice)** | Talk about your syndrome, meds, symptoms, "can I take this?", "what do I do now?" Agent calls tools; never invents a medical verdict | In-app LLM agent; **Intents Kit** so Celia can call us; (stretch) **Agent Framework Kit A2A** |
| **Medicine check** | Type, say, or **photograph** a box → active ingredient → deterministic QT-risk verdict → agent explains + drafts question for doctor | **Core Vision OCR** (on-device), Scan Kit (barcode) |
| **Watch guard** | Live heart rate + heart-rate alarm events from the Huawei watch; abnormal → agent proactively checks in, watch gets an alert | **Wear Engine Kit** (sensor + monitor + notify clients) |
| **Emergency mode** | Emergency card (diagnosis, drugs to avoid, ICE contacts), one-tap 112, card readable by paramedics | Home **widget (Form Kit)**, notifications, (stretch) Live View |
| **Doctor / caregiver** | Event log + doctor report; (stretch) caregiver tablet gets alerts device-to-device | ArkData RDB, (stretch) distributed data object / continuation |

**Digital sovereignty angle (matches the task's Oniro/Europe framing):** personal health data (profile, meds,
vitals, events) lives **on-device**. The cloud only sees the minimum needed: a drug name for lookup, and a
de-identified context for the LLM. Documented in `AI_FEATURES.md`.

## Who uses it

- **Primary:** person with diagnosed LQTS (and their parents, if the patient is a child/teen).
- **Secondary:** pharmacist/ER staff reading the emergency card; cardiologist reading the report.

## Challenge areas (task asks for ≥1; combining is a plus)

- **Human-Centric Technology** — quality of life, safety for a vulnerable group. *Primary.*
- **Intelligent Experiences** — agent, on-device OCR, contextual (vitals-aware) proactive help. *Primary.*
- **Spatial** — light touch only (location sent with SOS). Don't force it.

## Scope rules (from the judging criteria)

1. "Working narrow solution > broad concept" → **LQTS only** for the build. Brugada/CPVT = one slide "condition
   packs" (architecture supports it, drug list is data).
2. **Verdicts are deterministic** (curated drug list). The LLM explains and chooses tools. Wrong/invalid model output
   → typed validation → safe fallback. We demo this on purpose.
3. **Everything core runs on the emulator** (judges' default). Watch = real-device bonus with a simulated vitals
   source on the emulator, clearly labelled.
4. Everything is built fresh in this repo; third-party data/libraries (e.g. CredibleMeds-derived drug list) are cited
   in README + AI_WORKFLOW.md.

## MVP features (priority)

**P0 — must work in the demo**
1. Onboarding: condition (LQTS + genotype LQT1/2/3/unknown), current meds, ICE contacts, emergency notes.
2. Agent chat (text; voice if Core Speech works in English) with tools: `check_drug`, `get_my_meds`,
   `add_med`, `get_vitals_summary`, `show_emergency_card`, `start_emergency`, `explain_condition`.
3. Medicine check: type name **and** photo of box (on-device OCR) → verdict card (Known risk / Possible risk /
   Conditional / Not listed) + explanation + "ask your doctor" text.
4. Emergency card screen + SOS flow (call 112 / ICE, show card).
5. Vitals: live HR from watch (real device) **or** simulated scenarios (emulator); rules engine → alert → agent
   proactive message.

**P1 — strong extras**
6. **Intents Kit**: `CheckDrugSafety`, `ShowEmergencyCard` — "Celia, can I take ibuprofen?"
7. Home-screen **widget**: emergency card / last med check.
8. Watch notification via Wear Engine on alarm ("Heart rate high — open the app").
9. Doctor report (event log + meds + flagged drugs) as shareable page/PDF.

**P2 — only if ahead**
10. A2A agent (AgentExtensionAbility) so Celia can hold a conversation with our agent.
11. Caregiver tablet: distributed alert / app continuation.
12. Brugada/CPVT condition pack (data + 1 rule).

## Demo story (3 min)

1. Hook: "Hundreds of everyday drugs can stop the heart of 1 in 2,000 people. They usually find out in the ER."
2. **Agent:** "Hi, I've got a sinus infection, the doctor gave me this." → photograph box (clarithromycin) → 🔴
   *Known risk of torsades* → agent explains, suggests asking about alternatives, adds note to doctor report.
3. **Celia (system):** "Celia, can I take ondansetron?" → our intent answers without opening the app.
4. **Watch:** teammate's heart rate (or simulated LQT2 scenario) spikes → watch buzzes → agent: "I noticed your
   heart rate jumped to 165 while resting. Are you OK? Did you faint?" → user: "I feel dizzy" → agent starts
   emergency mode: card + 112.
5. **Robustness:** show the model returning garbage → app falls back to the deterministic answer (tests in repo).
6. Close: on-device data, open platform, condition packs next.

## Judging map

| Criterion (weight) | How we score |
|---|---|
| Originality 20% | Agent-first + watch-aware + system-callable medicine safety; not another symptom tracker |
| Usefulness 20% | Narrow, real user (LQTS), concrete preventable harm, works end-to-end |
| Technical execution 20% | Deterministic verdicts, schema-validated LLM output, error/timeouts handled, unit tests, no secrets |
| Platform capabilities 20% | Wear Engine, Core Vision OCR, Intents Kit (+ HMAF), Form widget, RDB, notifications |
| Demo 10% | Real app on emulator + real watch on borrowed device; label what's simulated |
| Reproducibility 10% | README with versions, `.hap` in releases, frequent commits, AI_WORKFLOW.md |

*Not a medical device. Decision support only; always "ask your doctor or pharmacist".*
