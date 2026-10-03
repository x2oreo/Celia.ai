// Shared contract — see docs/ARCHITECTURE.md.

export type ChatRole = 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  text: string;
  ts: number;
}

// UI actions the agent attaches to a reply. The chat UI renders one card per action.
//   SHOW_VERDICT          payload: VerdictCardPayload   — deterministic verdict card (source of truth, not the text)
//   SHOW_EMERGENCY_CARD   payload: EmergencyCardPayload
//   START_EMERGENCY       payload: EmergencyPayload      — cancellable countdown, then call + alert contacts
//   OPEN_MED_SCAN         payload: '{}'                  — open camera → OCR → confirm drug
//   ADD_MED               payload: AddMedPayload         — confirm card; UI calls AgentCore.resolveAction()
//   SHARE_EMERGENCY_CARD  payload: ConfirmPayload        — confirm card; UI calls AgentCore.resolveAction()
//   QUICK_REPLIES         payload: QuickRepliesPayload   — tappable answers; UI sends the tapped text
export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED' |
  'SHARE_EMERGENCY_CARD' | 'QUICK_REPLIES';

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

export interface QuickRepliesPayload {
  options: string[];
}
