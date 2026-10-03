// POST /functions/v1/agent — one model step of the Celia.ai agent loop.
//
// The loop itself runs ON THE DEVICE (AgentCore). This function is a thin, stateless relay:
//   request  { context, messages, continuation? }
//   response { promptVersion, responseId, toolCalls: [{callId, name, arguments}], text }
// If toolCalls is non-empty the app executes them locally and calls again with
// continuation = { previousResponseId: responseId, toolOutputs: [...] }.
// No personal identifiers are accepted (see validate.ts); logs carry no message text.

import { buildInstructions, PROMPT_VERSION } from '../_shared/prompt.ts';
import { TOOL_NAMES, TOOLS } from '../_shared/tools.ts';
import { env, json, openaiJson, outputText } from '../_shared/openai.ts';
import { parseAgentRequest } from '../_shared/validate.ts';

const UPSTREAM_TIMEOUT_MS = 18000; // the app gives up at 20 s and falls back

interface OutputItem {
  type: string;
  call_id?: string;
  name?: string;
  arguments?: string;
  content?: { type: string; text?: string }[];
}

interface ResponsesResult {
  id: string;
  status: string;
  output: OutputItem[];
}

interface ToolCall {
  callId: string;
  name: string;
  arguments: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();

  let parsed;
  try {
    parsed = parseAgentRequest(await req.json());
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  const input = parsed.continuation === null
    ? parsed.messages.map((m) => ({ role: m.role, content: m.text }))
    : parsed.continuation.toolOutputs.map((o) => ({
      type: 'function_call_output',
      call_id: o.callId,
      output: o.output,
    }));

  const body: Record<string, unknown> = {
    model: env('OPENAI_MODEL', 'gpt-6.1-sol'),
    reasoning: { effort: env('OPENAI_REASONING_EFFORT', 'low') }, // routing + short explanations need little thought
    instructions: buildInstructions(parsed.context), // not inherited via previous_response_id — always resend
    input,
    tools: TOOLS,
    tool_choice: 'auto',
    parallel_tool_calls: false, // one action at a time keeps confirm cards and voice turns simple
    max_output_tokens: 800,
  };
  if (parsed.continuation !== null) {
    body.previous_response_id = parsed.continuation.previousResponseId;
  }

  try {
    const res = await openaiJson<ResponsesResult>('/responses', body, UPSTREAM_TIMEOUT_MS);
    const toolCalls: ToolCall[] = [];
    for (const item of res.output ?? []) {
      // Unknown tool names are dropped here and again on the device.
      if (item.type === 'function_call' && item.call_id && item.name && TOOL_NAMES.includes(item.name)) {
        toolCalls.push({ callId: item.call_id, name: item.name, arguments: item.arguments ?? '{}' });
      }
    }
    const text = outputText(res);
    console.log(JSON.stringify({
      fn: 'agent',
      promptVersion: PROMPT_VERSION,
      status: res.status,
      tools: toolCalls.map((t) => t.name),
      textChars: text.length,
      continuation: parsed.continuation !== null,
      ms: Date.now() - started,
    }));
    return json(200, { promptVersion: PROMPT_VERSION, responseId: res.id, toolCalls, text });
  } catch (err) {
    console.error(JSON.stringify({ fn: 'agent', promptVersion: PROMPT_VERSION, error: String(err), ms: Date.now() - started }));
    // Always 502: a 4xx here is our upstream problem (key, model, response id), not a bad request from the app.
    return json(502, { error: 'upstream model error' });
  }
});
