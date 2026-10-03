// Celia → "I took my medicine": marks the dose that is due now (or the earliest missed one today) as taken.
// Deterministic (reminders/DoseSchedule.nextDoseToTake), no LLM; never logs a dose before it is due.

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { ReminderService } from '../reminders/ReminderService';
import { DoseLog, DoseReminder, nextDoseToTake, timeLabel } from '../reminders/DoseSchedule';

class TakeDoseResult {
  public medicine?: string = '';
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'TakeDose',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Mark dose as taken',
  displayDescription: 'Marks the medicine dose that is due now as taken',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Marks the user\'s medicine dose that is due now (or missed earlier today) as taken. Utterances: "I took my medicine", "mark my nadolol as taken".',
  keywords: ['took my medicine', 'dose taken', 'medicine reminder', 'beta blocker'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'properties': {}
  }
})
export default class TakeDoseIntent extends InsightIntentEntryExecutor<TakeDoseResult> {
  async onExecute(): Promise<insightIntent.IntentResult<TakeDoseResult>> {
    const reminders: DoseReminder[] = await ReminderService.list();
    const logs: DoseLog[] = await ReminderService.doseLog();
    const r: DoseReminder | undefined = nextDoseToTake(reminders, logs, Date.now());
    if (r === undefined) {
      const none: insightIntent.IntentResult<TakeDoseResult> = {
        code: 0, result: { medicine: '', message: 'No dose is due right now. Nothing was marked.' }
      };
      return none;
    }
    await ReminderService.mark(r, 'TAKEN');
    const ok: insightIntent.IntentResult<TakeDoseResult> = {
      code: 0, result: { medicine: r.medName, message: `Marked ${r.medName} (${timeLabel(r)}) as taken.` }
    };
    return ok;
  }
}
