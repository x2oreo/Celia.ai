# Edge Functions - Celia.ai agent

| Function | Owner | Purpose |
|---|---|---|
| `agent` | Kaloyan | One model step of the agent loop (OpenAI Responses API). Tools run on the device. |
| `transcribe` | Kaloyan | Push-to-talk speech-to-text fallback: `{audioBase64 (WAV), language}` → `{text}`. |
| `speak` | Kaloyan | Text-to-speech fallback: `{text}` → raw PCM 24 kHz 16-bit mono. |
| `realtime-session` | Kaloyan | `{context}` → short-lived OpenAI Realtime client secret with the same instructions + tools. |
| `vision-extract` | Kaloyan | Box photo → medicine **names only** (`{drugs:[{name,strength,confidence}], imageQuality}`). Never judges risk. |
| `drug-check` | Georgi | `{query}` → deterministic QT verdict: curated list, then RxNav + openFDA label rule. No AI. |
| `box-identify` | Georgi | `{gtin, stage}` → brand + English ingredients of any box (registries, product DBs, AI web search last). Never a verdict. |
| `med-info` | Georgi | `{medicine, ingredient}` → plain-language explanation (`{recognised,summary,contains,usedFor,tips[]}`). Never judges heart/QT safety or doses; replies with banned words are dropped. |
| `doctor-summary` | Georgi | `{specialty, genotype, medicines, interactions, flagged, heartAlerts, symptoms}` (lists newline-joined) → `{summary}`: 2–3 sentences atop the deterministic doctor brief. No name/notes/contacts are sent. Reassurance ("safe", "no risk"), doses or start/stop advice → `{summary:'', dropped:true}`. |
| `share` | Georgi | End-to-end encrypted card/report links (ciphertext only). See `docs/ARCHITECTURE.md` → share. Deploy with `--no-verify-jwt`. |

Shared code lives in `_shared/` (`prompt.ts` system prompt + `PROMPT_VERSION`, `tools.ts` tool schemas,
`openai.ts` fetch client, `validate.ts` request validation).

## Contract: `POST /functions/v1/agent`

```jsonc
// request - first step of a turn
{ "context": { "condition": "LQTS", "genotype": "LQT2", "meds": ["nadolol"],
               "vitals": "HR 72 at rest, no alerts (simulated)", "emergencyNumber": "112", "locale": "en-GB" },
  "messages": [{ "role": "user", "text": "Can I take Klacid?" }] }

// response
{ "promptVersion": "2026-10-03.4", "responseId": "resp_…",
  "toolCalls": [{ "callId": "call_…", "name": "check_drug", "arguments": "{\"name\":\"Klacid\",\"dosage\":null}" }],
  "text": "" }

// request - after the device ran the tools
{ "context": { … }, "messages": [],
  "continuation": { "previousResponseId": "resp_…",
                    "toolOutputs": [{ "callId": "call_…", "output": "{…tool result JSON…}" }] } }
```

Errors: `400` invalid request, `502` model error/timeout. The app treats any non-200 as "use deterministic fallback".

## Run / deploy

```bash
cp supabase/functions/.env.example supabase/functions/.env   # add OPENAI_API_KEY
supabase functions serve agent --env-file supabase/functions/.env
supabase secrets set OPENAI_API_KEY=sk-... OPENAI_MODEL=gpt-6-astra
supabase functions deploy agent transcribe speak vision-extract med-info doctor-summary realtime-session
```

Type-check without the Supabase CLI: `cd supabase/functions && npx deno@2 check */index.ts`.
Unit tests (pure logic, no network): `npx -y deno test --no-lock backend/supabase/functions/` from the repo root.

Agent tools added on 3 Oct: `log_symptom` (T27; prompt rule 7b, `PROMPT_VERSION` 2026-10-03.4). The device executes it
(`agent/tools/SymptomTools.ets`); redeploy `agent` and `realtime-session` so the model sees it.

Security limits (3 Oct review): `share` creates are rate-limited per client address; `box-identify` shares an AI
web answer only after 2 distinct device confirmations and expires every cached row after 30 days (optional secret
`BOX_VOTE_SALT`); `sos` caps real alert rounds per hour across all devices (`SOS_GLOBAL_MAX_PER_HOUR`, default 10).
