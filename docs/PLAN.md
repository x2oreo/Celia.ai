# 24h plan & checkpoints

Times are hours from kickoff (T0). **Confirm the exact submission deadline on Discord** and write it here: `____`.
Aim to have a complete submission uploaded **3 h before** the deadline, then improve.

## Checkpoints (all 3 people, 10 min, standing)

| When | Must be true | If not |
|---|---|---|
| **T+2h** | App skeleton builds & runs on emulator from `main`; Supabase project live; agent function answers "hello"; mentor answers collected (see below) | Cut scope, not sleep |
| **T+6h** | **Vertical slice:** type drug in chat → agent → `check_drug` → verdict card in UI. Simulated HR scenario fires alert in app | Drop voice + A2A |
| **T+10h** | Med photo OCR works; emergency card + SOS; onboarding saves to RDB; watch data on real device (or decision: simulated only) | Drop widget/continuation |
| **T+14h** | Intents Kit "CheckDrugSafety" works or is dropped; proactive agent message on vitals alert; tests for DrugChecker / AlarmRules / ResponseValidator green | Freeze features |
| **T+16h** | **Feature freeze.** Only bugfix + polish from here | — |
| **T+18h** | Demo video recorded (emulator + real device clips); `.hap` built + attached to GitHub release; README build steps tested on a clean clone by someone who didn't write them | — |
| **T+20h** | AI_WORKFLOW.md + AI_FEATURES.md + architecture description final; **submission uploaded** | — |
| Deadline −1h | Final re-upload; no new code | — |

## Ask Huawei mentors in the first hour (Kaloyan asks, writes answers here)

1. Can we **borrow a HarmonyOS phone (API 20+)** for the demo? Will it pair with our **GT5 Pro / GT6 Pro**
   (Huawei Health app on the phone)?
2. **Wear Engine** needs approval in AppGallery Connect / developer console (HEALTH_SENSOR is restricted).
   Can they fast-track it for the hackathon? Which permissions are realistic today (device info, monitor, notify, sensor)?
3. **Intents Kit / Agent Framework (HMAF) / Celia** — do they work outside China, on the emulator, in English?
   Do we need a Xiaoyi Open Platform agentId?
4. Does **Core Vision text recognition** and **Core Speech (English)** work on the emulator?
5. Is the name "Celia.ai" a problem for them (it's their assistant's name)?

Answers:
- 1: 
- 2: 
- 3: 
- 4: 
- 5: 

## Decisions log (append; one line each)

- T0: Condition = LQTS only for build; Brugada/CPVT = slide. Verdicts deterministic. Backend = Supabase EU.
- Mark: GT 6 Pro (lite wearable) has no network API and we only have iPhones → watch app is an **ArkTS wearable app on
  the wearable emulator** (`watch/`), uploading metrics to Supabase `watch_metrics`; real GT 6 Pro HR via BLE
  broadcast → Mac bridge (`tools/hr-bridge`). Vitals metrics (numbers + device id, no personal data) now go to the
  backend; phone app reads `watch_metrics_latest`. Team: confirm this is OK vs. the on-device-only data rule.
-

## Submission checklist (HackTribe + task deliverables)

- [ ] Public GitHub repo, `main` builds
- [ ] README: prerequisites (DevEco version, SDK API 20, Node/ohpm), build, sign, install (`hdc install`), launch,
      emulator notes, how to verify each feature, what needs a real device
- [ ] Working **.hap** (GitHub release asset)
- [ ] Recorded demo (URL) — label simulated parts
- [ ] Architecture + implementation description (`docs/ARCHITECTURE.md` cleaned up)
- [ ] `AI_WORKFLOW.md` (tools, models, MCP servers, skills, main prompts, workflow, validation, lessons, failures)
- [ ] `AI_FEATURES.md` (model/service, inference flow, data handling, limitations, validation, privacy)
- [ ] Tests run + results shown in README
- [ ] No secrets (`git log -p | grep -i key` sanity check)
- [ ] HackTribe: title ≤ 5 words, description ≤ 500 words, ≥ 1 image, PDF ≤ 10 slides, team names/emails
- [ ] Third-party components & data sources (CredibleMeds, libs) cited
