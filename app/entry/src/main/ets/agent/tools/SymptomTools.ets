// log_symptom (T27): the user describes a symptom in chat ("I felt dizzy after the alarm") and the model logs it.
// Validation is deterministic: unknown symptom → error back to the model (it asks the user), severity clamped,
// heart-rate window attached on the phone. A red-flag symptom (fainting, chest pain, severe breathlessness) also
// starts the emergency flow — decided by isRedFlag(), never by the model.

import { AgentTool, TurnState, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { StartEmergencyTool } from './ActionTools';
import { LocalStore } from '../../data/LocalStore';
import { VitalsService } from '../../vitals/VitalsService';
import {
  buildSymptomEntry, isRedFlag, NOTE_MAX, parseSymptom, Symptom, SymptomEntry, SYMPTOMS, symptomLabel
} from '../../model/SymptomEntry';

interface LoggedOutput {
  status: string;
  symptom: string;
  severity: number;
  heartRate: string;
  emergencyStarted: boolean;
  note: string;
}

export class LogSymptomTool implements AgentTool {
  name: string = 'log_symptom';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const symptom: Symptom | undefined = parseSymptom(argString(args, 'symptom', 40));
    if (symptom === undefined) {
      return toolError(`symptom must be one of ${SYMPTOMS.join(', ')}; ask the user which fits`);
    }
    const raw: Object | undefined = args['severity'];
    const severity: number = typeof raw === 'number' && Number.isFinite(raw) ? raw : 3;
    const entry: SymptomEntry = buildSymptomEntry(symptom, severity, argString(args, 'activity', 40),
      argString(args, 'note', NOTE_MAX), VitalsService.get().history(), Date.now());
    await LocalStore.get().logEvent('SYMPTOM', JSON.stringify(entry));

    const red: boolean = isRedFlag(entry.symptom, entry.severity);
    if (red) {
      const reason: Record<string, Object> = { 'reason': `${symptomLabel(entry.symptom)} (logged in chat)` };
      await new StartEmergencyTool().execute(reason, turn);
    }
    const out: LoggedOutput = {
      status: 'LOGGED',
      symptom: symptomLabel(entry.symptom),
      severity: entry.severity,
      heartRate: entry.hrMin < 0 ? 'no reading in the last 10 minutes' : `${entry.hrMin}-${entry.hrMax} bpm (wrist, not ECG)`,
      emergencyStarted: red,
      note: red ? 'This is a red-flag symptom: the emergency countdown has started. Tell the user to sit or lie down.'
        : 'Saved to the symptom log; it appears in the doctor brief. Do not interpret the heart rate.'
    };
    return JSON.stringify(out);
  }
}
