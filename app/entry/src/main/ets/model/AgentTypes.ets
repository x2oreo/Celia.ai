// Shared contract — see docs/ARCHITECTURE.md.

export type ChatRole = 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  text: string;
  ts: number;
}

export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED';

export interface UiAction {
  type: UiActionType;
  payload: string;      // JSON string, parsed per type
}

export interface AgentReply {
  text: string;
  actions: UiAction[];
  fallback: boolean;
}
