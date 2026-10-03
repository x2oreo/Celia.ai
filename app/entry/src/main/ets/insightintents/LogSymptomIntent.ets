// Celia → "Log that I felt dizzy": saves a symptom to the on-device log with the recent heart rate attached.
// Deterministic (model/SymptomEntry.ets), no LLM. A red-flag symptom gets the emergency number read out — the
// intent runs in the background, so it never starts the SOS countdown itself.

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { VitalsService } from '../vitals/VitalsService';
import { Profile } from '../model/Profile';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import {
  buildSymptomEntry, isRedFlag, parseSymptom, Symptom, SymptomEntry, symptomLabel
} from '../model/SymptomEntry';

class LogSymptomResult {
  public symptom?: string = '';
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'LogSymptom',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Log a symptom',
  displayDescription: 'Saves a symptom (dizziness, palpitations, fainting…) to the Long QT symptom log',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Saves a heart symptom the user had (dizziness, palpitations, fainting, chest pain, shortness of breath) with its severity 1-5 to their Long QT symptom log. Utterances: "log that I felt dizzy", "note palpitations, severity 3".',
  keywords: ['symptom', 'log symptom', 'felt dizzy', 'palpitations', 'fainted', 'Long QT'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'properties': {
      'symptom': {
        'type': 'string',
        'enum': ['DIZZINESS', 'PALPITATIONS', 'FAINTING', 'CHEST_PAIN', 'SHORTNESS_OF_BREATH', 'OTHER'],
        'description': 'Closest symptom category'
      },
      'severity': { 'type': 'number', 'minimum': 1, 'maximum': 5, 'description': '1 mild to 5 severe' }
    },
    'required': ['symptom']
  }
})
export default class LogSymptomIntent extends InsightIntentEntryExecutor<LogSymptomResult> {
  public symptom: string = '';
  public severity: number = 3;

  async onExecute(): Promise<insightIntent.IntentResult<LogSymptomResult>> {
    const s: Symptom | undefined = parseSymptom(this.symptom);
    if (s === undefined) {
      const bad: insightIntent.IntentResult<LogSymptomResult> = {
        code: -1, result: { symptom: '', message: 'Which symptom: dizziness, palpitations, fainting, chest pain or breathlessness?' }
      };
      return bad;
    }
    const entry: SymptomEntry = buildSymptomEntry(s, this.severity, '', '', VitalsService.get().history(), Date.now());
    await LocalStore.get().logEvent('SYMPTOM', JSON.stringify(entry));
    let message: string = `Logged ${symptomLabel(s).toLowerCase()}, severity ${entry.severity} of 5.`;
    if (isRedFlag(entry.symptom, entry.severity)) {
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      const number: string = emergencyFor(profile?.country ?? systemCountry()).general;
      message = `${message} This can be serious with Long QT. If it is happening now, call ${number}.`;
    }
    const ok: insightIntent.IntentResult<LogSymptomResult> = { code: 0, result: { symptom: s, message: message } };
    return ok;
  }
}
