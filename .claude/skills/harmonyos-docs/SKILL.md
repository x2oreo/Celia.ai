---
name: harmonyos-docs
description: Where and how to pull authoritative HarmonyOS / OpenHarmony / ArkTS / ArkUI documentation. Use BEFORE writing or debugging any HarmonyOS code, whenever an API name, import path (@kit.*), decorator, config key (module.json5, build-profile.json5), CLI flag (hvigorw, hdc, ohpm) or error code is uncertain. Also the router to the other harmonyos-* skills.
---

# HarmonyOS documentation sources

HarmonyOS APIs move fast (API level bumps every few months) and LLM training data is thin and
mixed with legacy Java/HarmonyOS 2-3 (Android-based) material. **Never trust memory for API names,
imports or config keys. Look them up.** Current as of Oct 2026: DevEco Studio 6.1.x, HarmonyOS 6.1.1 = API 24
(6.0.2 = API 22, 6.1.0 = API 23). Ignore anything about Java `Ability`/`AbilitySlice`, FA model,
`config.json`, `.hml` / JS-like web UI, or `@ohos.*` HAP built with Gradle — that is the old era.

## 1. Context7 (fastest, first choice)

Use `mcp__context7__query-docs` directly with these IDs (no resolve step needed):

| Library ID | Content |
|---|---|
| `/websites/developer_huawei_consumer_cn_doc_harmonyos-guides` | Official dev guides (ArkTS, ArkUI, kits, DevEco, hvigor, hdc). ~65k snippets. Best general source. |
| `/websites/developer_huawei_consumer_cn_doc_harmonyos-references` | API reference (every `@kit.*` module, component attributes, error codes). |
| `/linganmin/harmonyos_samples` | Official sample apps — complete working code. |

Snippets come from the CN site: prose may be Chinese, code is the same. One concept per query
(e.g. "Navigation NavPathStack pushPathByName example", not "routing and state and http").

## 2. Official site (WebFetch)

URL pattern — swap `/cn/` ↔ `/en/` for language (EN sometimes lags CN by a release):

- Guides: `https://developer.huawei.com/consumer/en/doc/harmonyos-guides/<slug>`
- API ref: `https://developer.huawei.com/consumer/en/doc/harmonyos-references/<slug>`
- Best practices: `https://developer.huawei.com/consumer/en/doc/best-practices/<slug>`
- Release notes / version map: `https://developer.huawei.com/consumer/en/doc/harmonyos-releases/...`
- Codelabs: `https://developer.huawei.com/consumer/en/codelabsPortal/`
- Design (HarmonyOS Design / UX): `https://developer.huawei.com/consumer/en/design/`

Pages are JS-rendered; WebFetch often returns only the nav shell. If so, fall back to Context7
or the OpenHarmony docs repo below.

Useful slugs (guides): `arkts-get-started`, `typescript-to-arkts-migration-guide`, `arkts-more-cases`,
`arkts-state-management-overview`, `arkts-new-local`, `arkts-new-param`, `arkts-new-event`,
`arkts-navigation-navigation`, `application-models` / `uiability-lifecycle`, `module-configuration-file`,
`ide-hvigor-commandline`, `hdc`, `ide-emulator`, `ide-signing`, `hmaf-function` (Agent Framework),
`insight-intent-decorator-development` (Intents), `hmaf-a2a-dev-guide`, `agent-extension-configuration`, `core-vision-text-recognition`,
`speechrecognizer-guide`, `data-sync-of-distributed-data-object`, `app-continuation-guide`.

## 3. OpenHarmony docs (raw Markdown, greppable)

HarmonyOS = OpenHarmony + Huawei closed kits (HMS-like: Account, Map, Push, Payment, Core Vision/Speech,
Agent Framework...). Basic ArkTS/ArkUI/Ability/ArkData docs are identical in OpenHarmony and are plain Markdown:

- `https://gitcode.com/openharmony/docs` (primary), GitHub mirror `https://github.com/openharmony/docs`
- English: `en/application-dev/` — e.g. `en/application-dev/quick-start/`, `ui/`, `reference/apis-arkui/`
- For heavy lookup: `git clone --depth 1 https://github.com/openharmony/docs` into scratch, then grep.

## 4. Community / third-party

- `https://www.harmony-developers.com` — English community, global-dev workarounds.
- Agent skill packs to mine for pitfalls: `github.com/DengShiyingA/harmonyos-ai-skill`,
  `github.com/FadingLight9291117/arkts_skills`, `skills.sh/openharmonyinsight/openharmony-skills`.
- ohpm package registry: `https://ohpm.openharmony.cn` (3rd-party libs, e.g. `@ohos/axios`, `@ohos/lottie`).
- Huawei mentors at HackYeah (Discord task channel, "Mentors Village" level 0) — ask them first when
  the docs contradict reality on the event devices.

## Lookup protocol

1. Identify exact symbol (component, decorator, `@kit.X` module, config key, CLI flag).
2. Context7 guides → references → samples. 3. Check the API level of the target device
(`hdc shell param get const.ohos.apiversion`) against the doc's "Since API x" note.
4. Copy imports exactly (`import { http } from '@kit.NetworkKit'`), not `@ohos.net.http` unless
the docs for that module only show the legacy path.

## Skill router

- Language rules / compile errors `arkts-no-*` → `arkts-language`
- UI, components, state decorators, navigation → `arkui-development`
- Project files, UIAbility, permissions, module.json5 → `harmonyos-app-model`
- Build, sign, install, emulator, logs → `harmonyos-build-deploy`
- Kits (AI, network, data, distributed, agent, widgets) → `harmonyos-kits`
- Celia / Agent Framework (HMAF) / A2A / Intents → `celia-agent`
- LQTS medical knowledge, drug data, emergency content → `lqts-domain`
- HackYeah Huawei rules, deliverables, judging, submission → `hackyeah-huawei`
