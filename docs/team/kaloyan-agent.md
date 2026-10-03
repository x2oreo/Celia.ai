# Kaloyan — Agent & AI (+ coordination)

**You own:** everything that makes this "agent-first": `AgentCore` in the app, the tool layer, the `/agent` Edge
Function (LLM loop), Intents Kit entry points, OCR service, voice (stretch), A2A (stretch), and the two AI docs.
You also run checkpoints and talk to the Huawei mentors.

Skills to load before coding: `celia-agent`, `harmonyos-kits`, `arkts-language`, `harmonyos-docs`.

## First 2 hours (in order)

1. **Mentor questions** (`docs/PLAN.md` list) — ask in the first hour, write answers into PLAN.md. They decide
   whether Intents/HMAF/Wear Engine are in or out.
2. **Decide the name** (see naming risk in `IDEA.md`) — 5 minutes, don't bikeshed.
3. **`/agent` Edge Function skeleton** in `backend/supabase/functions/agent/` (Mark creates the Supabase project;
   you own this function):
   - **OpenAI** Responses API (model via `OPENAI_MODEL` secret), key in Supabase secrets. Voice later via the
     OpenAI Realtime API with the same tools.
   - Stateless relay: one model step per call. The tool loop runs in the app (`AgentCore`), tools execute
     on-device, so personal data never leaves the phone. Contract: `backend/supabase/functions/README.md`.
   - Return "hello" first, deploy, and give Georgie the URL.
4. **System prompt v1** (`backend/supabase/functions/agent/prompt.ts`): role, LQTS facts by genotype, the rules
   (never give a verdict yourself, always use `check_drug`, always end medical advice with "ask your doctor or
   pharmacist", emergency → `START_EMERGENCY` action), output format.
5. **`AgentCore` stub in the app** (`app/.../agent/AgentCore.ets`): `send(text)` returns a fake `AgentReply`, so
   Georgie can build the chat UI against it right away. Push to `main`.
6. Create `AI_WORKFLOW.md` at the repo root and log this session's prompts.

## Then (T+2h → T+16h)

- `AgentClient` (NetworkKit http, 20 s timeout) → `ResponseValidator` (schema check, drop unknown actions,
  verdict-contradiction check) → fallback reply. **Unit tests** for the validator: valid, malformed JSON, unknown
  action, verdict mismatch, timeout.
- Deterministic emergency pre-filter (keywords → `START_EMERGENCY` with no LLM call).
- **Proactive agent:** subscribe to `VitalsService.onAlert` → build a check-in message ("Your heart rate jumped to 165
  while resting — are you OK?") → push to chat + notification.
- `OcrService` (Core Vision `textRecognition`) → pass OCR text to `DrugChecker.check` (it must find the ingredient
  inside noisy box text; agree the matching approach with Mark).
- **Intents Kit:** `CheckDrugSafety` (background mode, returns verdict text) + `ShowEmergencyCard` (foreground mode).
  Both call the same `DrugChecker` / pages, not the LLM.
- Stretch: Core Speech voice input/output; A2A `AgentExtensionAbility`.
- `AI_FEATURES.md`: model, inference flow diagram, data sent off-device, limitations, validation, privacy.

## Definition of done

- Chat → drug question → correct deterministic verdict + explanation, end-to-end on the emulator.
- Kill the network → the app still answers drug checks (bundled list) and says the agent is offline.
- A broken model reply is shown being caught (log + test).
- Intents either work in the demo or are documented as "built, not verifiable here because …".
