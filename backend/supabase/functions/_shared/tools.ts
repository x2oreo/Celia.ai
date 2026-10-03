// Tool schemas for the Celia.ai agent — single source of truth for /agent and /realtime-session.
// The tools are EXECUTED ON THE DEVICE (AgentCore → ToolRegistry). The backend only advertises them to the model.
// Every name here must have an executor in app/entry/src/main/ets/agent/tools/. Keep both lists in sync.
//
// Strict mode: every property is listed in `required`; optional values are nullable instead.

export interface FunctionTool {
  type: 'function';
  name: string;
  description: string;
  parameters: Record<string, unknown>;
  strict: boolean;
}

function tool(name: string, description: string, properties: Record<string, unknown>): FunctionTool {
  return {
    type: 'function',
    name,
    description,
    parameters: {
      type: 'object',
      properties,
      required: Object.keys(properties),
      additionalProperties: false,
    },
    strict: true,
  };
}

const nullableString = (description: string) => ({ type: ['string', 'null'], description });

export const TOOLS: FunctionTool[] = [
  tool(
    'check_drug',
    'Look up the QT-risk verdict for ONE medicine (brand or generic name) against the curated on-device list, ' +
      "including interactions with the user's current medicines. Always call this before saying anything about " +
      'whether a medicine is risky. The verdict in the result is final.',
    {
      name: { type: 'string', description: 'Medicine name as the user said it, brand or generic, e.g. "Klacid".' },
      dosage: nullableString('Dose if the user mentioned one, e.g. "500 mg", otherwise null.'),
    },
  ),
  tool('get_my_meds', "List the user's current medicines with their QT-risk category.", {}),
  tool(
    'get_vitals_summary',
    'Get a short summary of recent heart-rate readings and alerts from the watch or the simulator.',
    {},
  ),
  tool(
    'explain_condition',
    'Get verified, plain-language facts about Long QT syndrome for one topic. Use this to ground explanations.',
    {
      topic: {
        type: 'string',
        enum: ['overview', 'genotype', 'triggers', 'sick_day', 'emergency', 'beta_blockers'],
        description: "Topic to explain. 'genotype' returns facts for the user's own genotype.",
      },
    },
  ),
  tool(
    'suggest_alternatives',
    'List medicines from the same class that are NOT on QT-risk lists, from the curated list only. ' +
      'Never suggest alternatives that did not come from this tool.',
    {
      drug_name: { type: 'string', description: 'The risky medicine to find alternatives for.' },
    },
  ),
  tool(
    'scan_medicine',
    'Open the camera so the user can photograph a medicine box. The app reads the name on-device and asks the ' +
      'user to confirm it, then the verdict is shown.',
    {},
  ),
  tool(
    'add_med',
    "Propose adding a medicine to the user's list. The user must confirm on screen; the result says whether " +
      'they confirmed.',
    {
      name: { type: 'string', description: 'Medicine name, brand or generic.' },
      dose: nullableString('Dose and frequency if known, e.g. "40 mg twice daily", otherwise null.'),
    },
  ),
  tool(
    'show_emergency_card',
    "Open the user's emergency card (for doctors, pharmacists, paramedics).",
    {
      language: { type: ['string', 'null'], enum: ['en', 'pl', null], description: 'Card language, null = app language.' },
    },
  ),
  tool(
    'start_emergency',
    'Start the emergency flow: a cancellable countdown, then calling the emergency number and alerting the ' +
      'emergency contacts. Use when the user reports fainting, chest pain, a seizure, severe dizziness or ' +
      'palpitations, or asks for help.',
    {
      reason: { type: 'string', description: 'Short reason in the user\'s words, e.g. "felt faint after alarm".' },
    },
  ),
  tool(
    'share_emergency_card',
    'Share the emergency card through the system share sheet. The user must confirm.',
    {},
  ),
  tool(
    'log_symptom',
    'Save a symptom the user describes (e.g. "I felt dizzy after the alarm") to their symptom log, with the heart ' +
      'rate of the last minutes attached on the phone. A red-flag symptom also starts the emergency flow on the ' +
      'phone. Only log what the user actually reported.',
    {
      symptom: {
        type: 'string',
        enum: ['DIZZINESS', 'PALPITATIONS', 'FAINTING', 'CHEST_PAIN', 'SHORTNESS_OF_BREATH', 'OTHER'],
        description: 'Closest symptom category.',
      },
      severity: { type: 'integer', minimum: 1, maximum: 5, description: 'How bad, 1 (mild) to 5 (severe). Use 3 if unsure.' },
      activity: {
        type: ['string', 'null'],
        enum: ['resting', 'sleeping', 'exercise', 'swimming', 'sudden noise / stress', 'other', null],
        description: 'What the user was doing, if they said; otherwise null.',
      },
      note: nullableString('A few of the user\'s own words (max 120 characters), otherwise null.'),
    },
  ),
  tool(
    'start_new_chat',
    'Save the current conversation and start a new, empty one. Use when the user asks for a new chat, to start ' +
      'over, or to save this chat. Every chat is already kept on the phone, so nothing is lost.',
    {
      title: nullableString('Name for the chat being saved if the user gave one, e.g. "ibuprofen questions", otherwise null.'),
    },
  ),
];

export const TOOL_NAMES: string[] = TOOLS.map((t) => t.name);
