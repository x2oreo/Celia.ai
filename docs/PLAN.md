# 24h plan and checkpoints

> **Planning document from the hackathon; status as of 4 Oct 2026.** This is the plan we made at kickoff on
> 3 Oct, kept for the record. Ticks below are set from the code in `app/`, `watch/` and `backend/`. What is built
> now: [PRODUCT.md](PRODUCT.md); how to verify it: [README](../README.md#how-to-verify-each-feature-emulator).

## Summary

| Area | Status |
|---|---|
| Checkpoints T+2h .. T+14h (skeleton, vertical slice, OCR, emergency, intents, tests) | Done |
| Feature freeze (T+16h) | Not kept: Workstream B (accounts, onboarding v2, doctor visits, notifications, widgets) was added on 4 Oct |
| Watch on a real device | Replaced by a wearable app on the wearable emulator (see decisions log) |
| Mentor questions | Answers were not written down here |
| Submission checklist | Mostly done; see the checklist at the end |

Times are hours from kickoff (T0). Aim was a complete submission uploaded **3 h before** the deadline, then improve.

## Checkpoints (all 3 people, 10 min, standing)

| When | Must be true | If not | Status |
|---|---|---|---|
| **T+2h** | App skeleton builds and runs on the emulator from `main`; Supabase project live; agent function answers "hello"; mentor answers collected | Cut scope, not sleep | Done (mentor answers not recorded) |
| **T+6h** | **Vertical slice:** type a drug in chat → agent → `check_drug` → verdict card. Simulated HR scenario fires an alert | Drop voice + A2A | Done |
| **T+10h** | Box photo OCR works; emergency card + SOS; onboarding saves to RDB; watch data on a real device (or decision: simulated only) | Drop widget / continuation | Done; watch = wearable emulator + phone-side simulation |
| **T+14h** | Intents Kit `CheckDrugSafety` works or is dropped; proactive agent message on a vitals alert; tests for DrugChecker / AlarmRules / ResponseValidator green | Freeze features | Done; intents built, routing from Celia unverified |
| **T+16h** | **Feature freeze.** Only bugfix and polish from here | - | Not kept (Workstream B) |
| **T+18h** | Demo video recorded; `.hap` built and attached to a GitHub release; README build steps tested on a clean clone | - | Video and deck in progress (`video/`, `deck/`); release and clean-clone test not confirmed from the repo |
| **T+20h** | `AI_WORKFLOW.md` + `AI_FEATURES.md` + architecture description final; **submission uploaded** | - | Docs exist and are kept updated |
| Deadline -1h | Final re-upload; no new code | - | - |

## Ask Huawei mentors in the first hour

1. Can we **borrow a HarmonyOS phone (API 20+)** for the demo? Will it pair with our **GT5 Pro / GT6 Pro**?
2. **Wear Engine** needs approval in AppGallery Connect (HEALTH_SENSOR is restricted). Can they fast-track it?
3. **Intents Kit / Agent Framework (HMAF) / Celia** - do they work outside China, on the emulator, in English? Do we
   need a Xiaoyi Open Platform agentId?
4. Does **Core Vision text recognition** and **Core Speech (English)** work on the emulator?
5. Is the name "Celia.ai" a problem (it is their assistant's name)?

Answers were not recorded in this file. What the code reflects: no real phone or watch was used for the build
(Wear Engine not wired, intents unverified), and research notes are in [research/](research/).

## Decisions log

- T0: Condition = LQTS only; Brugada / CPVT = slide. Verdicts deterministic. Backend = Supabase EU.
- Mark: the GT 6 Pro (lite wearable) has no network API and we only have iPhones → the watch app is an **ArkTS
  wearable app on the wearable emulator** (`watch/`, scripted HR scenarios), uploading metrics to Supabase. Vitals
  metrics (numbers + device id, no personal data) go to the backend; the phone reads them.
- During the build: the in-app assistant is called "the agent" in the UI; "Celia" stays Huawei's assistant (Intents Kit).
- 4 Oct: optional accounts (Supabase Auth); profile and medicines backed up per user, app stays offline-first (D6 in
  [PRODUCT.md](PRODUCT.md#1-decisions)).
- 4 Oct: the watch links to the phone with a 6-digit pairing code; watch rows are readable by their owner only (RLS).

## Submission checklist (HackTribe + task deliverables)

- [x] Public GitHub repo, `main` builds
- [x] README: prerequisites, build, sign, install, launch, emulator notes, how to verify each feature, what needs a
      real device ([REAL_DEVICE.md](REAL_DEVICE.md))
- [ ] Working **.hap** as a GitHub release asset (not confirmed from the repo)
- [ ] Recorded demo (URL), simulated parts labelled (film in `video/`, landing page `site/`; URL not in the repo yet)
- [x] Architecture + implementation description ([ARCHITECTURE.md](ARCHITECTURE.md))
- [x] [AI_WORKFLOW.md](../AI_WORKFLOW.md)
- [x] [AI_FEATURES.md](../AI_FEATURES.md)
- [x] Tests run + results shown in README
- [ ] No secrets: run `git log -p | grep -i key` once more before submitting
- [ ] HackTribe form: title of 5 words or fewer, description of 500 words or fewer, at least 1 image, PDF of 10
      slides or fewer (`deck/`), team names and emails
- [x] Third-party components and data sources cited (README, `AI_WORKFLOW.md`)
