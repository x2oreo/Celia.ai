// Tool plumbing shared by the text loop (/agent relay) and the realtime voice session.

import { Genotype } from '../model/Profile';
import { UiAction, UiActionType, VerdictCardPayload } from '../model/AgentTypes';

// Write actions proposed by the model and waiting for the user's tap (confirm cards).
export type PendingKind = 'ADD_MED' | 'SHARE_EMERGENCY_CARD' | 'LOG_DOSE';

export interface PendingAction {
  id: string;
  kind: PendingKind;
  name: string;
  ingredient: string;
  dose: string;
  reminderId: number;   // LOG_DOSE: the DoseReminder to mark, otherwise -1
  createdAt: number;
}

// Per-turn state the executors read and write. AgentCore turns it into the AgentReply.
export class TurnState {
  genotype: Genotype = 'UNKNOWN';
  emergencyNumber: string = '112';
  actions: UiAction[] = [];
  verdicts: VerdictCardPayload[] = [];
  pending: PendingAction[] = [];
  emergencyStarted: boolean = false;
  toolsUsed: string[] = [];
  // start_new_chat: AgentCore saves the current chat (optionally renamed) and opens a new one when the turn ends,
  // so the reply already lands in the new chat.
  newChatRequested: boolean = false;
  newChatTitle: string = '';
}

export interface AgentTool {
  name: string;
  // args: parsed JSON object from the model. Returns the JSON string sent back to the model.
  execute(args: Record<string, Object>, turn: TurnState): Promise<string>;
}

export interface ToolError {
  error: string;
}

export function toolError(message: string): string {
  const e: ToolError = { error: message };
  return JSON.stringify(e);
}

export function action(type: UiActionType, payload: Object): UiAction {
  const a: UiAction = { type: type, payload: JSON.stringify(payload) };
  return a;
}
