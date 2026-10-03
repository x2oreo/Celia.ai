// scan_medicine, show_emergency_card, start_emergency, add_med, share_emergency_card.
// UI tools return an action for the chat UI. Write tools never write: they create a confirm card and report
// AWAITING_USER_CONFIRMATION; the user's tap goes through AgentCore.resolveAction().

import { AgentTool, PendingAction, PendingKind, TurnState, action, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { DrugChecker } from '../../drugs/DrugChecker';
import { DrugVerdict } from '../../model/DrugVerdict';
import {
  AddMedPayload, ConfirmPayload, EmergencyCardPayload, EmergencyPayload, UiAction
} from '../../model/AgentTypes';

import { COUNTDOWN_S } from '../../emergency/SosController';

// Same countdown the SOS screen runs, so what Celia says matches what happens.
export const EMERGENCY_COUNTDOWN_SEC: number = COUNTDOWN_S;

let nextActionSeq: number = 1;

function newActionId(): string {
  return `act-${Date.now()}-${nextActionSeq++}`;
}

interface StatusOutput {
  status: string;
  note: string;
}

function status(s: string, note: string): string {
  const out: StatusOutput = { status: s, note: note };
  return JSON.stringify(out);
}

export class ScanMedicineTool implements AgentTool {
  name: string = 'scan_medicine';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const open: UiAction = { type: 'OPEN_MED_SCAN', payload: '{}' };
    turn.actions.push(open);
    return status('CAMERA_OPENED',
      'The user photographs the box; the app reads and confirms the name, then shows the verdict card.');
  }
}

export class ShowEmergencyCardTool implements AgentTool {
  name: string = 'show_emergency_card';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const lang: string = argString(args, 'language', 4);
    const payload: EmergencyCardPayload = { language: lang === 'en' || lang === 'pl' ? lang : '' };
    turn.actions.push(action('SHOW_EMERGENCY_CARD', payload));
    return status('CARD_SHOWN', 'The emergency card is on screen.');
  }
}

export class StartEmergencyTool implements AgentTool {
  name: string = 'start_emergency';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    if (!turn.emergencyStarted) {
      const payload: EmergencyPayload = {
        reason: argString(args, 'reason', 200),
        emergencyNumber: turn.emergencyNumber,
        countdownSec: EMERGENCY_COUNTDOWN_SEC
      };
      turn.actions.push(action('START_EMERGENCY', payload));
      turn.emergencyStarted = true;
    }
    return status('COUNTDOWN_STARTED',
      `In ${EMERGENCY_COUNTDOWN_SEC} seconds the phone calls ${turn.emergencyNumber} and alerts the emergency ` +
        'contacts unless the user cancels. Tell them to stay seated or lie down and that help is coming.');
  }
}

function pending(kind: PendingKind, name: string, ingredient: string, dose: string): PendingAction {
  const p: PendingAction = {
    id: newActionId(),
    kind: kind,
    name: name,
    ingredient: ingredient,
    dose: dose,
    createdAt: Date.now()
  };
  return p;
}

interface AddMedOutput {
  status: string;
  ingredient: string;
  verdict: string;
  note: string;
}

export class AddMedTool implements AgentTool {
  name: string = 'add_med';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const name: string = argString(args, 'name', 80);
    if (name.length === 0) {
      return toolError('name is required');
    }
    const dose: string = argString(args, 'dose', 80);
    // Resolve first so the saved medicine carries its ingredient (HeartBeat stored unknown brands as "safe").
    const v: DrugVerdict = await DrugChecker.get().check(name);
    const p: PendingAction = pending('ADD_MED', name, v.ingredient, dose);
    turn.pending.push(p);
    const payload: AddMedPayload = {
      actionId: p.id,
      name: name,
      ingredient: v.ingredient,
      dose: dose,
      risk: v.risk
    };
    turn.actions.push(action('ADD_MED', payload));
    const out: AddMedOutput = {
      status: 'AWAITING_USER_CONFIRMATION',
      ingredient: v.ingredient,
      verdict: v.risk,
      note: 'Nothing is saved until the user taps Confirm. Say that a confirmation card is on screen.'
    };
    return JSON.stringify(out);
  }
}

export class ShareEmergencyCardTool implements AgentTool {
  name: string = 'share_emergency_card';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const p: PendingAction = pending('SHARE_EMERGENCY_CARD', '', '', '');
    turn.pending.push(p);
    const payload: ConfirmPayload = { actionId: p.id };
    turn.actions.push(action('SHARE_EMERGENCY_CARD', payload));
    return status('AWAITING_USER_CONFIRMATION', 'The user chooses where to share it on screen.');
  }
}
