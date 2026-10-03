// Shared contract — see docs/ARCHITECTURE.md.

export type ChatRole = 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  text: string;
  ts: number;
  actions?: UiAction[];   // cards shown with the message (restored chats keep display cards only)
}

// UI actions the agent attaches to a reply. The chat UI renders one card per action.
//   SHOW_VERDICT          payload: VerdictCardPayload   — deterministic verdict card (source of truth, not the text)
//   SHOW_EMERGENCY_CARD   payload: EmergencyCardPayload
//   START_EMERGENCY       payload: EmergencyPayload      — cancellable countdown, then call + alert contacts
//   OPEN_MED_SCAN         payload: '{}'                  — scan tile → photo picker → OCR → confirm drug
//   ADD_MED               payload: AddMedPayload         — confirm card; UI calls AgentCore.resolveAction()
//   SHARE_EMERGENCY_CARD  payload: ConfirmPayload        — confirm card; UI calls AgentCore.resolveAction()
//   QUICK_REPLIES         payload: QuickRepliesPayload   — tappable answers; UI sends the tapped text
//   SHOW_MEDS             payload: MedsPayload           — the user's medicines with their deterministic risk
//   SHOW_ALTERNATIVES     payload: AlternativesPayload   — list-verified options to discuss with a doctor
//   OPEN_PAGE             payload: OpenPagePayload       — tile that opens a page (doctor prep, reminders)
export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED' |
  'SHARE_EMERGENCY_CARD' | 'QUICK_REPLIES' | 'SHOW_MEDS' | 'SHOW_ALTERNATIVES' | 'OPEN_PAGE';

export interface UiAction {
  type: UiActionType;
  payload: string;      // JSON string, parsed per type
}

export interface AgentReply {
  text: string;
  actions: UiAction[];
  fallback: boolean;    // true = deterministic reply (model unavailable, invalid or overridden)
}

// ---- Action payloads (JSON.parse(action.payload) as X) ----

export interface InteractionFinding {
  kind: string;         // 'ADDITIVE_QT' | 'CYP_INHIBITION' | 'MANY_QT_DRUGS'
  withDrug: string;     // the current medicine involved, '' for MANY_QT_DRUGS
  detail: string;       // plain-language, deterministic
}

export interface VerdictCardPayload {
  query: string;
  ingredient: string;
  risk: string;         // RiskLevel of the drug alone
  combinedRisk: string; // RiskLevel after interaction rules (never lower than risk)
  reason: string;
  source: string;
  findings: InteractionFinding[];
}

export interface EmergencyCardPayload {
  language: string;     // 'en' | 'pl' | '' (app language)
}

export interface EmergencyPayload {
  reason: string;
  emergencyNumber: string;
  countdownSec: number;
}

export interface ConfirmPayload {
  actionId: string;
}

export interface AddMedPayload {
  actionId: string;
  name: string;
  ingredient: string;   // '' if the drug is not in the list
  dose: string;
  risk: string;         // RiskLevel, shown on the confirm card
}

export interface OpenPagePayload {
  page: string;         // 'DOCTOR_PREP' | 'REMINDERS'
  specialty: string;    // doctor/DoctorPrep Specialty for DOCTOR_PREP, otherwise ''
}

export interface QuickRepliesPayload {
  options: string[];
}

export interface MedLinePayload {
  name: string;
  ingredient: string;
  dose: string;
  risk: string;         // RiskLevel from DrugChecker
}

export interface MedsPayload {
  medicines: MedLinePayload[];
}

export interface AlternativesPayload {
  forDrug: string;
  alternatives: string[];   // every entry re-checked as NOT_LISTED on the device
  note: string;
}

// A tool the agent is running (or has just finished), shown as a step in the conversation.
export interface ToolActivity {
  id: number;
  name: string;
  args: string;         // JSON string from the model
  done: boolean;
}
