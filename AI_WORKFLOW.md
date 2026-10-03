# AI workflow

How AI tools were used to build Celia.ai, as required by Challenge Rules §4. Append one entry per session.

## Tools

| Tool | Use |
|---|---|
| Claude Code (Claude Opus 5.5) | Research, architecture planning, code generation, tests, docs |
| Context7 MCP | Up-to-date HarmonyOS docs (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`) and OpenAI API docs (`/websites/developers_openai_api`) |
| Project Agent Skills (`.claude/skills/`) | HarmonyOS/ArkTS rules, LQTS domain facts, Celia/HMAF integration, build loop |
| OpenAI API (in the product) | Agent model behind `/agent` — see `AI_FEATURES.md` |

## Pre-existing work

- **HeartBeat / QTShield** (`github.com/x2oreo/HeartBeat`) is our team's earlier LQTS web app. It was used as
  **design reference only**: Claude Code read it and summarised what worked and what didn't. No code, prompts or data
  were copied. Everything in this repo was written fresh during the challenge.

## Sessions

### 2026-10-03 — AI layer research, plan and first implementation (Kaloyan)

**Prompt (summary):** "Research how we built the AI in HeartBeat, brainstorm a voice-first agent at the centre of
the app that works with the tools (medicine check, emergency card…), then plan and build the AI layer."

**Workflow**
1. Two parallel read-only research agents covered the HeartBeat repo and this repo's docs/skills.
2. Context7 checks:
   - Core Speech Kit: the docs only show `zh-CN`, so English is unverified and voice needs a cloud fallback.
   - OpenAI Responses API function-calling format.
3. Four decisions were made with the developer:
   - the app runs the tool loop;
   - OpenAI as provider, starting with push-to-talk and moving to the Realtime API;
   - on-device OCR first, cloud vision as fallback;
   - write actions need confirm cards.
4. Implementation:
   - the `/agent` relay;
   - `ComboRules` and `SafetyGate`;
   - `AgentCore` with `ToolRegistry`, ten tools, `ResponseValidator` and `OfflineAgent`.

**Lessons from HeartBeat applied**
- The LLM no longer decides combination risk; `ComboRules` does.
- An unknown drug can never become green.
- Alternatives are re-verified against the drug list.
- The emergency number is not hardcoded.
- SOS has a confirm countdown.
- Tool results become UI cards.
- Tests exist.

**Validation**
- Every ArkTS file was compiled with `hvigorw assembleHap`, with strict ArkTS and no warnings.
- `app/scripts/test.sh` passes 37 of 37 tests.
- The Edge Function was type-checked with `deno check` and smoke-tested locally with curl: 400 on a bad request, 502 with no key.

**Issues caught in review**
- The first emergency regex matched "help me find an alternative" and "show my emergency card". It was narrowed and
  tests were added.
- JavaScript `\b` doesn't work next to Polish letters, so the Polish patterns now use substrings.
- The reassurance check would have replaced "your heart rate is fine". It is now scoped to medicine context.
