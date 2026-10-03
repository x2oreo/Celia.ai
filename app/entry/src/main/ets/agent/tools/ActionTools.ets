// scan_medicine, show_emergency_card, start_emergency, add_med, share_emergency_card, log_dose, start_new_chat.
// UI tools return an action for the chat UI. Write tools never write: they create a confirm card and report
// AWAITING_USER_CONFIRMATION; the user's tap goes through AgentCore.resolveAction().

import { TITLE_MAX_CHARS } from '../../model/Chat';
import { AgentTool, PendingAction, PendingKind, TurnState, action, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { DrugChecker } from '../../drugs/DrugChecker';
import { ComboVerdict, DrugVerdict, RiskLevel } from '../../model/DrugVerdict';
import { escalate } from '../../safety/ComboRules';
import { LocalStore } from '../../data/LocalStore';
import {
  AddMedPayload, ConfirmPayload, EmergencyCardPayload, EmergencyPayload, LogDosePayload, UiAction
} from '../../model/AgentTypes';
import { ReminderService } from '../../reminders/ReminderService';
import { DoseLog, DoseReminder, nextDoseToTake, timeLabel } from '../../reminders/DoseSchedule';

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
    return status('SCAN_OFFERED',
      'A scan button is on screen. The user taps it and picks a photo of the box; the app reads and confirms the ' +
        'name, then shows the verdict card.');
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
      `A ${EMERGENCY_COUNTDOWN_SEC}-second countdown is on screen. When it ends the phone shows one-tap buttons ` +
        `to call ${turn.emergencyNumber} and to send the SOS message to the emergency contacts. Nothing is dialled ` +
        'or sent without a tap. Tell them to stay seated or lie down and to tap Call if they can.');
  }
}

function pending(kind: PendingKind, name: string, ingredient: string, dose: string,
  reminderId: number = -1): PendingAction {
  const p: PendingAction = {
    id: newActionId(),
    kind: kind,
    name: name,
    ingredient: ingredient,
    dose: dose,
    reminderId: reminderId,
    createdAt: Date.now()
  };
  return p;
}

interface AddMedOutput {
  status: string;
  ingredient: string;
  verdict: string;
  interactions: string[];   // with the medicines already saved; deterministic (DrugChecker.checkCombos)
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
    const combos: ComboVerdict[] = DrugChecker.get().checkCombos(v, await LocalStore.get().listMeds());
    const combined: RiskLevel = combos.length > 0 ? escalate(v.risk) : v.risk;
    const p: PendingAction = pending('ADD_MED', name, v.ingredient, dose);
    turn.pending.push(p);
    const payload: AddMedPayload = {
      actionId: p.id,
      name: name,
      ingredient: v.ingredient,
      dose: dose,
      risk: combined
    };
    turn.actions.push(action('ADD_MED', payload));
    const out: AddMedOutput = {
      status: 'AWAITING_USER_CONFIRMATION',
      ingredient: v.ingredient,
      verdict: combined,
      interactions: combos.map((c: ComboVerdict) => c.reason),
      note: 'Nothing is saved until the user taps Confirm. Say that a confirmation card is on screen.' +
        (combos.length > 0 ? ' Tell the user about the interactions first, in plain words.' : '')
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

// Words that mean "my medicine" without naming one.
const GENERIC_MED: RegExp = /^(medicine|medicines|medication|medications|meds|pill|pills|tablet|tablets|dose|beta[ -]?blocker)$/;

// The dose a "I took my nadolol" refers to: the one due now, else the earliest missed one today, among the
// reminders for that medicine (all reminders when no medicine is named). Never an upcoming dose.
export function doseToLog(reminders: DoseReminder[], logs: DoseLog[], now: number,
  medicine: string): DoseReminder | undefined {
  const m: string = medicine.trim().toLowerCase().replace(/^(my|the)\s+/, '');
  const named: boolean = m.length > 0 && !GENERIC_MED.test(m);
  const pool: DoseReminder[] = !named ? reminders : reminders.filter((r: DoseReminder) => {
    const n: string = r.medName.trim().toLowerCase();
    return n.length > 0 && (n.includes(m) || m.includes(n));
  });
  return nextDoseToTake(pool, logs, now);
}

// "I took my nadolol." The phone picks the dose (never the model) and nothing is written until the user confirms.
export class LogDoseTool implements AgentTool {
  name: string = 'log_dose';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const medicine: string = argString(args, 'medicine', 80);
    const reminders: DoseReminder[] = await ReminderService.list();
    if (reminders.length === 0) {
      return status('NO_REMINDERS', 'No reminders are set, so there is no dose to mark. Nothing was logged. ' +
        'Reminders are added on the reminders screen (open_reminders).');
    }
    const r: DoseReminder | undefined = doseToLog(reminders, await ReminderService.doseLog(), Date.now(), medicine);
    if (r === undefined) {
      return status('NO_DOSE_DUE', 'No dose of that medicine is due or missed today (it may already be marked, ' +
        'or the next one is still upcoming). Nothing was logged. A dose cannot be logged before it is due.');
    }
    if (turn.pending.some((x: PendingAction) => x.kind === 'LOG_DOSE' && x.reminderId === r.id)) {
      return status('AWAITING_USER_CONFIRMATION', 'The confirmation card for this dose is already on screen.');
    }
    const p: PendingAction = pending('LOG_DOSE', r.medName, '', timeLabel(r), r.id);
    turn.pending.push(p);
    const payload: LogDosePayload = { actionId: p.id, medicine: r.medName, time: timeLabel(r) };
    turn.actions.push(action('LOG_DOSE', payload));
    const out: LogDoseOutput = {
      status: 'AWAITING_USER_CONFIRMATION',
      medicine: r.medName,
      time: timeLabel(r),
      note: 'Nothing is logged until the user taps Confirm. Say that a confirmation card for this dose is on ' +
        'screen. Do not say the dose was logged, and do not comment on timing.'
    };
    return JSON.stringify(out);
  }
}

interface LogDoseOutput {
  status: string;
  medicine: string;
  time: string;
  note: string;
}

// "Save this chat and start a new one." Nothing is lost: every chat is already saved on the phone. The optional
// title renames the chat being saved. The switch happens when the turn ends (AgentCore.finish).
export class StartNewChatTool implements AgentTool {
  name: string = 'start_new_chat';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    turn.newChatRequested = true;
    turn.newChatTitle = argString(args, 'title', TITLE_MAX_CHARS);
    return status('NEW_CHAT_STARTED',
      'The current chat is saved on this phone (open it again from Chats). Reply with one short sentence; the reply ' +
        'starts the new chat.');
  }
}
