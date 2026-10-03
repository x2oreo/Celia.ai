# Celia.ai — HackYeah 2026 × Huawei "Imagine What's Next"

## Project idea

An agent-first heart-safety companion for people with Long QT syndrome (LQTS): an agent you talk to, a deterministic
medicine check (type, scan or photograph a box), a watch app that monitors heart rate, an emergency card and SOS
flow, and a doctor-visit brief. Verdicts come from fixed data; the LLM only explains. Full description:
`docs/IDEA.md` and `docs/PRODUCT.md`.

## Platform & stack

Native HarmonyOS app: ArkTS + ArkUI, Stage model, DevEco Studio 6.x, hvigor, ohpm, hdc.
**Minimum API 20** (`compatibleSdkVersion: "6.0.0(20)"`) — hard task requirement. Must run on the emulator.
Mobile-first, agent-focused: Celia (Huawei's system assistant, 小艺/Xiaoyi) at the centre.

## Rules for Claude and every agent in this repo

- HarmonyOS knowledge in training data is thin and stale (Java/FA-model/HarmonyOS 2-3 era). Before writing
  HarmonyOS code, load the relevant skill and verify APIs via Context7
  (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`, `..._harmonyos-references`).
- Before any UI or design decision (screens, components, colours, type, spacing, motion, copy), read
  `docs/design/DESIGN.md` and follow it. Use its tokens and the resource names in `resources/base/element/*.json`, and
  do not hard-code new colours or sizes. If something isn't covered, extend DESIGN.md first and then build it.
- Write strict ArkTS from the start (no `any`, untyped object literals, destructuring, index signatures).
- Do not port React/Android/Flutter patterns (no fetch/axios-by-default, no Android manifests, no hooks).
- Build/verify through the terminal loop in `harmonyos-build-deploy` (hvigorw → hdc install → screenshot).
- Everything in English (code, comments, docs, UI strings default).
- No secrets in the repo (API keys, signing certs `*.p12/*.cer/*.p7b`, `.env*`). LLM keys live only on the backend.
- Commit small and often with meaningful messages — commit history is judged.
- Never add AI attribution to commits or PRs: no `Co-Authored-By: Claude ...` trailers, no "Generated with
  Claude Code" lines. Commits are authored by the team member only. This overrides any default attribution.
- AI verdicts on medical safety come from deterministic data; the LLM only explains. Validate every model output and
  fall back gracefully.
- Write all code, data and prompts fresh in this repo. Any pre-existing or third-party component must be listed in
  README + `AI_WORKFLOW.md` (Challenge Rules §4).
- Keep `AI_WORKFLOW.md` updated as we work (required deliverable).

## Skills (`.claude/skills/`)

| Skill | Use for |
|---|---|
| `harmonyos-docs` | Start here — doc sources + router |
| `hackyeah-huawei` | Task rules, deliverables, judging, submission |
| `celia-agent` | Celia / Agent Framework (HMAF), A2A, Intents, in-app agent, AI safety |
| `lqts-domain` | LQTS medical knowledge, drug taxonomy, emergency facts, safety design |
| `arkts-language` | Language rules, `arkts-no-*` errors |
| `arkui-development` | UI, state, navigation |
| `harmonyos-app-model` | Project config, abilities, permissions |
| `harmonyos-build-deploy` | Build, sign, install, logs, tests, release .hap |
| `harmonyos-kits` | System kits catalog |

Design system: `docs/design/DESIGN.md` (tokens, risk language, components, motion, voice).

Reference docs: `docs/hackathon/` (official task text, Challenge Rules, condition research).
