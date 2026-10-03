# Edge Functions — Celia.ai agent

| Function | Owner | Purpose |
|---|---|---|
| `agent` | Kaloyan | One model step of the agent loop (OpenAI Responses API). Tools run on the device. |
| `transcribe` | Kaloyan | Push-to-talk speech-to-text fallback: `{audioBase64 (WAV), language}` → `{text}`. |
| `speak` | Kaloyan | Text-to-speech fallback: `{text}` → raw PCM 24 kHz 16-bit mono. |
| `realtime-session` | Kaloyan | `{context}` → short-lived OpenAI Realtime client secret with the same instructions + tools. |
| `vision-extract` | Kaloyan | Box photo → medicine **names only** (`{drugs:[{name,strength,confidence}], imageQuality}`). Never judges risk. |

Shared code lives in `_shared/` (`prompt.ts` system prompt + `PROMPT_VERSION`, `tools.ts` tool schemas,
`openai.ts` fetch client, `validate.ts` request validation).

## Contract: `POST /functions/v1/agent`

```jsonc
// request — first step of a turn
{ "context": { "condition": "LQTS", "genotype": "LQT2", "meds": ["nadolol"],
               "vitals": "HR 72 at rest, no alerts (simulated)", "emergencyNumber": "112", "locale": "en-GB" },
  "messages": [{ "role": "user", "text": "Can I take Klacid?" }] }

// response
{ "promptVersion": "2026-10-03.1", "responseId": "resp_…",
  "toolCalls": [{ "callId": "call_…", "name": "check_drug", "arguments": "{\"name\":\"Klacid\",\"dosage\":null}" }],
  "text": "" }

// request — after the device ran the tools
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
supabase functions deploy agent transcribe speak vision-extract realtime-session
```

Type-check without the Supabase CLI: `cd supabase/functions && npx deno@2 check */index.ts`.
