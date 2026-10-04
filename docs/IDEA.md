# Celia.ai - the idea

> **Status (4 Oct 2026, final hackathon day):** built and running on the HarmonyOS emulator (API 20+). Items that
> need a real phone, a watch or a platform approval are marked "built, unverified". The per-feature check list is
> the README table [How to verify each feature](../README.md#how-to-verify-each-feature-emulator); the full product
> description is [PRODUCT.md](PRODUCT.md).

**Naming.** "Celia" is also the international name of Huawei's system assistant (小艺 / Xiaoyi). We keep
`Celia.ai` as the product name, call our in-app assistant **"the agent"** in the UI, and integrate *with* Huawei's
Celia through Intents Kit. Below, "the agent" = our in-app agent; "Celia" = Huawei's system assistant.

## One-liner

An **agent-first heart-safety companion for people with Long QT syndrome** on HarmonyOS: an agent you talk to
about your condition, that checks every medicine before you take it, watches your heart rate through a watch app,
and takes over in an emergency. The safety core (verdicts, emergency card, profile) works fully offline; cloud
features are optional and every request the phone makes is listed in an on-phone ledger.

## Problem

- **Long QT syndrome (LQTS)** is an inherited ion-channel disease in about 1 in 2,000 people. It can trigger
  *torsades de pointes*: fainting or sudden cardiac death, often in young people.
- The triggers are known and mostly preventable: **hundreds of common drugs prolong QT** (antibiotics,
  antiemetics, antidepressants, antihistamines), low potassium or magnesium (vomiting, diarrhoea), and
  genotype-specific triggers (LQT1 exercise and swimming, LQT2 sudden noise and emotion, LQT3 rest and sleep).
- Patients carry all of this alone: at the pharmacy, abroad, at the dentist, or in an ER where staff may not know
  LQTS.

## User story

> Anna, 24, has LQT2. Her dentist prescribes an antibiotic. At the pharmacy she points her phone at the box: the
> app reads the barcode, finds clarithromycin and shows **Known risk** in red, with the reason, safer options to
> ask about, and an interaction warning against the escitalopram she already takes. The agent explains it in plain
> words and adds it to her next doctor visit. That night her watch sees a sudden heart-rate spike at rest: the
> phone asks "Are you OK?" for 30 seconds, then offers to call 112 and her mother, and shows a card that tells the
> paramedic what not to give her.

## Who uses it

| User | What they get |
|---|---|
| Person with diagnosed LQTS (or the parent of a child with LQTS) | Medicine checks, reminders, heart-rate watch, agent, SOS |
| Pharmacist, ER staff, bystander | Emergency card (13 languages, QR link, first-responder view, CPR help) |
| Cardiologist, dentist, GP | Doctor-visit page: "please don't prescribe" list, medicines, symptoms, heart summary |

## Solution - an agent at the centre, the ecosystem around it

| Layer | What it does (as built) | HarmonyOS capability |
|---|---|---|
| **Agent (voice + text)** | Talk or type about your condition, medicines, symptoms and plans. 18 on-device tools (check a drug, log a symptom or dose, open screens, prepare a doctor visit, start SOS). Emergency words skip the model. | In-app agent (OpenAI via our Edge Functions), Intents Kit so Celia can call us |
| **Medicine check** | Type, scan a barcode, or photograph a box → active ingredient → deterministic QT-risk verdict, interactions with my medicines, safer alternatives, "How we know" trace | Scan Kit, Core Vision text recognition (on-device) |
| **Heart watch** | Watch app streams heart rate and simple metrics; fixed rules per genotype raise alerts; the phone checks in | Wearable app (API 20+) → Supabase → phone; phone-side simulation on the emulator, labelled `SIMULATED` |
| **Emergency** | Emergency card, 30 s "Are you OK?" SOS countdown, call 112 / contacts, first-responder view, CPR metronome, pharmacy card, nearby help | Live View, notifications, NFC tag write, Form Kit widgets (incl. lock-screen medical ID) |
| **Daily companion** | Dose reminders, genotype tip of the day, symptom log and feeling diary, travel banner, app lock, privacy ledger | reminderAgentManager, Location Kit, User Authentication Kit |
| **Doctor visits** | Per-visit page for a kind of doctor, encrypted share link, optional validated AI summary | Local storage + Supabase Storage (encrypted on the phone) |

**Digital sovereignty angle** (matches the task's Oniro/Europe framing): the deterministic core (drug verdicts,
emergency card, profile, medicines, chats) runs and is stored on the phone and needs no network. Cloud features
are optional: watch metrics go to our Supabase project (EU), and the agent, voice and photo paths go through our
Edge Functions to OpenAI. With an account, the profile and medicines are backed up to the user's own row,
readable only by that login and deletable from Settings. The full list is in
[AI_FEATURES.md](../AI_FEATURES.md) section 3 and the README "What leaves the phone" table.

## Challenge areas (the task asks for at least one)

- **Human-Centric Technology** - quality of life and safety for a vulnerable group. *Primary.*
- **Intelligent Experiences** - agent with tools, on-device OCR and barcode, vitals-aware proactive help. *Primary.*
- **Spatial** - light touch only (location in the SOS message, travel banner, nearby help).

## Scope rules we kept

1. **Working narrow solution over broad concept:** LQTS only. Brugada / CPVT are a "condition packs" idea, not
   built.
2. **Verdicts are deterministic** (curated drug list + fixed interaction rules). The LLM explains and chooses
   tools. Invalid model output → typed validation → safe fallback. Unit-tested.
3. **Everything core runs on the emulator.** Heart data on the emulator is simulated and labelled so.
4. **Built fresh in this repo.** Third-party data and libraries are cited in README and `AI_WORKFLOW.md`.

## What is built (summary)

| Area | Status |
|---|---|
| Welcome, account (optional), 8-step onboarding | Built, seen on the emulator |
| v2 layout: Today · Medicines · orb (agent stage) · Health · Emergency | Built, seen on the emulator |
| Drug check by name, interactions, alternatives, barcode (Polish register, about 68k packs), teach-a-barcode | Built, seen on the emulator |
| Photo of a box (agent camera button) | Built; gallery fallback seen on the emulator, camera capture unverified |
| Agent: text, voice (live and tap-to-talk), saved chats, page tools, confirm-before-write dose logging | Built; dose confirmation card unit-tested only |
| Health tab: per-metric cards and pages, trends from the cloud | Built; with simulated rows only (no real watch rows yet) |
| SOS countdown, watch SOS, Live View, notifications per kind | Built; Live View and notification buttons unverified on a real phone |
| Emergency card (13 languages, QR link, read aloud, NFC write), first-responder view, pharmacy card, nearby help | Built; NFC unverified (needs hardware) |
| Doctor visits (gallery, visit page, share, AI summary) | Built; gallery cards, share and web block not yet seen on screen |
| Reminders, symptom log, feeling diary, coach tip, travel banner, app lock, privacy ledger | Built |
| Seven home-screen widgets (incl. lock-screen medical ID) | Built; lock-screen placement unverified |
| Seven Celia intents (`insight_intent.json`) | Built and compiled; routing from Celia unverified (needs a real phone with Celia) |
| Watch app (wearable emulator): heart rate, alerts, check-in, fall → SOS, 6-digit pairing | Built, runs on the wearable emulator |

## Not built / next

| Item | Why not / what it needs |
|---|---|
| A2A agent (Agent Framework Kit `AgentExtensionAbility`) so Celia can hold a conversation with our agent | Not built; HMAF availability outside China unclear |
| Wear Engine on a real Huawei watch | Not wired; GT watches have no network API, and the team had no HarmonyOS phone to pair. Wrist alerts fall back to a phone notification + haptic |
| Caregiver tablet (distributed alert / continuation) | Not built |
| Brugada / CPVT condition pack | Not built (the drug list is data, so it is a data task) |
| In-app Map Kit map | Needs a Map Kit key; the app opens a map search instead |
| System reminder "Taken" button | Needs an AppGallery Connect quota; in-app fallback works while the app runs |
| Real SMS / calls from the `sos` function | Needs Twilio secrets on the server; until then it records a test run |
| Sick-day electrolyte guard, QTc log, family screening leaflet | Ideas only |

## Demo story (3 min)

1. **Hook:** "Hundreds of everyday drugs can stop the heart of 1 in 2,000 people. They usually find out in the ER."
2. **Agent:** "The dentist gave me this" → scan or photograph the box (clarithromycin) → **Known risk** → the agent
   explains, offers alternatives to ask about, and the visit page picks it up.
3. **Celia (system):** "Celia, can I take ondansetron?" → our intent answers from the deterministic check (needs a
   real phone with Celia; otherwise shown as built).
4. **Watch:** a simulated LQT2 scenario spikes the heart rate → alert → 30 s "Are you OK?" → call 112 / contacts,
   emergency card and first-responder view.
5. **Robustness:** the model returns garbage or reassurance about a risky drug → the app drops it and shows the
   deterministic answer (unit tests in the repo).
6. **Close:** offline safety core, ledger of what leaves the phone, condition packs next.

## Judging map

| Criterion (weight) | How we score |
|---|---|
| Originality 20% | Agent-first, watch-aware, system-callable medicine safety; not another symptom tracker |
| Usefulness 20% | Narrow real user (LQTS), concrete preventable harm, works end to end |
| Technical execution 20% | Deterministic verdicts, validated LLM output, timeouts and fallbacks, unit tests (app, watch, backend), no secrets |
| Platform capabilities 20% | Intents Kit, Form Kit widgets, Live View, Scan Kit, Core Vision, NFC, reminders, User Authentication, Location, wearable app |
| Demo 10% | Real app on the emulator plus the watch app on the wearable emulator; simulated parts labelled |
| Reproducibility 10% | README with versions and scripts, `.hap`, frequent commits, `AI_WORKFLOW.md` |

*Not a medical device. Decision support only; always "ask your doctor or pharmacist".*
