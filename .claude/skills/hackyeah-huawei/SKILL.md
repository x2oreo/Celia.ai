---
name: hackyeah-huawei
description: HackYeah 2026 (Kraków, 3-4 Oct 2026) Huawei partner task "Imagine What's Next" (25 000 PLN) - official task text, Challenge Rules (scoring 1-10 per criterion, 50% prize threshold, IP licence, pre-existing-code disclosure), hard technical requirements (API 20+, emulator, .hap), the 7 required deliverables incl. AI_WORKFLOW.md, judging weights and what scores, HackTribe submission form, 24h plan. Use when planning scope, choosing features, writing README/architecture/AI docs/pitch, committing, or checking whether something is "allowed" or "required".
---

# HackYeah 2026 × Huawei "Imagine What's Next"

Primary sources (in repo, re-read when in doubt - they win over this summary):
- `docs/hackathon/huawei-task.txt` (+ `.pdf`) - task description, technical requirements, deliverables, criteria.
- `docs/hackathon/huawei-challenge-rules.txt` (+ `.pdf`) - legal Challenge Rules (Huawei Polska / PROIDEA).
- `docs/hackathon/conditions-research.md` - our LQTS/condition research + watch API reality check.

## Event facts

- HackYeah 2026, Tauron Arena Kraków, **Sat 3 – Sun 4 Oct 2026**, 24h. Teams 1–6 registered participants.
- Prize pool **25 000 PLN**: 1st 12 000 · 2nd 8 000 · 3rd 5 000 (split equally among team members, minus tax).
- Results announced **4 Oct** at the closing ceremony. Jury may invite teams to present/demo live (one presenter).
- **Everything in English**: code comments, README, docs, slides, video, description.
- Submission on **HackTribe** before the official deadline (late = not considered). FAQ says Sun ~23:00 - confirm on Discord.
- Huawei mentors (Discord task channel + Mentors Village, level 0): Dong Jae Yoon (HarmonyOS platform, EMUI),
  Chen Song (OpenHarmony app dev), Maksim Syramalotau (architecture, pitch). **Mentors have real devices on site.**

## The task (official)

Build an innovative **system feature or mobile app for an OpenHarmony-based device** (HarmonyOS / OpenHarmony / Oniro).
Pitch frame Huawei wrote: HarmonyOS = first credible challenger to iOS/Android, heading to Europe; OpenHarmony is
open (OpenAtom), **Oniro** is its EU distro (Eclipse Foundation) → **European digital sovereignty**, "build without
asking permission". Use this framing in README + slides.

Areas - idea must live in ≥1; combining areas *with purpose* is explicitly a plus:
- **Intelligent Experiences** - agents, contextual awareness, personalization, intelligent interaction, on-device AI.
- **Spatial Experiences** - spatial UI, 3D, immersive media, sensing, positioning, interaction with environment.
- **Human-Centric Technology** - accessibility, digital wellbeing, inclusive design, education, quality of life.

## Hard technical requirements (fail one = weak/invalid)

- [ ] Targets HarmonyOS/OpenHarmony/Oniro. Native ArkTS+ArkUI (our choice) - cross-platform only if it ships a real OHOS package.
- [ ] **API 20+**; declare **API 20 as minimum** → `compatibleSdkVersion: "6.0.0(20)"` in `build-profile.json5`.
- [ ] Runs on **emulator** (judges' default) or physical device.
- [ ] Reproducible setup/build/launch instructions.
- [ ] Uses or improves **≥1 platform/device/system capability** (kits, sensors, agents, system services).
- An "improvement" = installable app/component, **no system modification**. Must explain what it does, how it integrates,
  how to install, **how to verify**.

## Required deliverables (all 7)

1. **Public** source repo (no secrets, no signing certs, no API keys).
2. README: setup, build, install, launch - with exact versions (DevEco Studio, SDK/API, hvigor, Node), emulator config.
3. Working **`.hap`** (attach to GitHub Release or commit to `release/`; say where in README).
4. Brief recorded **demo video** (real running app, not mockups).
5. Concise **architecture + implementation description** (diagram + data flow + which kits and why).
6. **`AI_WORKFLOW.md`** (mandatory - we use AI tools): all models, coding agents, MCP servers (Context7…),
   Agent Skills (`.claude/skills/*`), main prompts/reusable instructions (`CLAUDE.md`), config; workflow
   ideation→architecture→implementation→testing→debugging; how output was reviewed/tested; limitations,
   failed approaches, lessons. Strip keys/credentials/personal data.
7. **AI feature doc** (we ship AI features): model/service, inference flow, data handling, limitations,
   validation approach, privacy. Can be a section in AI_WORKFLOW.md or `docs/AI_FEATURES.md`.

Keep AI_WORKFLOW.md **updated as we go** (log notable prompts, skills used, what failed) - reconstructing at hour 22 is painful.

## Challenge Rules - things that bite

- Scoring: each juror gives **1–10 per criterion**, weighted average, averaged across jurors.
- Jury may **withhold a prize if the solution scores < 50%** of max - a broken demo can forfeit the money.
- Solution must be "created or substantially developed during the Challenge". Pre-existing code, templates, AI
  tools, third-party/OSS are allowed **but must be identified in the submission docs**. → Build everything fresh in
  this repo; list every third-party lib/dataset (e.g. CredibleMeds-derived drug list) in README + AI_WORKFLOW.md.
  Respect licences (CredibleMeds: see `lqts-domain`).
- IP: we keep ownership. Winners grant Huawei a 3-year non-exclusive, royalty-free licence to demo/present/promote
  (not commercial use). All submitters grant Huawei + PROIDEA a licence to use name, description, screenshots, video.
- Disqualification: rule breach, late, false/misleading info (don't claim features that don't work), third-party
  rights infringement.

## Judging - weights and how to score

| Criterion | % | What actually earns points |
|---|---|---|
| Originality | 20 | Fresh take; cross-area combo with purpose (e.g. on-device AI + human-centric health) |
| Demonstrated usefulness | 20 | Concrete user + problem; area visible *in what the app does*; **working narrow > broad slideware** |
| Technical execution | 20 | Works as claimed (backed by code/demo/logs/tests); justified architecture; readable modular code; error handling for API errors, timeouts, missing data, bad input, **wrong AI output**; **some tests**; no secrets, input validation, **minimal permissions**, no risky deps |
| Platform capabilities | 20 | Real system services/kits/agents/sensors/distributed features. App that runs unchanged on any OS scores low |
| Demo quality | 10 | Real app on emulator; clear what was built during hackathon; explain what can't run on emulator (sensors, watch) and how it would |
| Reproducibility | 10 | README alone builds it; versions documented; **commit history shows progress**; AI usage described |

Repos may get an **automated technical pre-review** → keep repo clean: README at root, `.gitignore` for `build/`,
`.hvigor/`, `oh_modules/`, `*.p12/*.cer/*.p7b`, `local.properties`, `.env*`.

Engineering implications for every agent working here:
- **Commit small and often** with meaningful messages (judged!). Never one giant squash.
- Write at least a few **unit tests** (ArkTS `@ohos/hypium` in `entry/src/test` / `ohosTest`) for the core logic
  (e.g. drug-risk lookup, rule engine, AI-output validation).
- Validate **every AI output** against a schema; on invalid/low-confidence output fall back to deterministic
  result + "ask your doctor". Show this fallback in the demo - it's literally a scoring line.
- Request only permissions actually used; prefer pickers/security controls.

## HackTribe submission form

Category: Huawei task · Title: English, **≤5 words** · Description: English, **≤500 words** (problem, solution, how
it works, team names/emails) · Gallery: **≥1 image** · Presentation: **PDF, ≤10 slides** · Video URL · Repo URL.
Upload an early draft (editable until deadline).

## Slide skeleton (≤10)

1 Title + one-liner · 2 Problem/user (LQTS stats) · 3 Solution · 4 Live demo screenshots · 5 Architecture ·
6 HarmonyOS capabilities used (Celia/agent, kits) · 7 AI + safety (deterministic verdict, validation, privacy) ·
8 Digital sovereignty / Oniro / EU angle · 9 What's built vs next · 10 Team.

## 24h plan

- T0–1h: read terms ✔, ask mentors: Celia/Agent Framework availability on EU accounts & emulator? device API level?
  devices to borrow (phone + watch)? Health/Wear Engine access?
- T1–3h: skeleton builds + runs on emulator, repo public, first commits, README stub, AI_WORKFLOW.md started.
- T3–14h: core flow end-to-end on emulator, then the Celia/agent wow-feature.
- T14–18h: error states, AI-output fallbacks, tests, EN strings, polish.
- T18–21h: screenshots, demo video, PDF slides, 500-word description, .hap release. Draft upload to HackTribe.
- T21–24h: buffer, bugfix, final upload ≥30 min before deadline.
