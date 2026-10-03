// Celia → "Add a medicine": opens Medicines, where the user adds and confirms it (scan or type). Adding a medicine
// changes the data every check relies on, so it is never done silently from a voice command. No LLM.

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { TabRequest } from '../common/TabRequest';
import { TabIndex } from '../common/Routes';

class OpenResult {
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'AddMedication',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Add a medicine',
  displayDescription: 'Opens My medicines to add a medicine you take (checked for QT risk as you add it)',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens the user\'s medicine list so they can add a medicine they take; it is checked against QT-risk lists when added. Utterances: "add a medicine", "I started a new medicine".',
  keywords: ['add medicine', 'new medicine', 'my medicines', 'Long QT'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: {
    'type': 'object',
    'properties': {}
  }
})
export default class AddMedicationIntent extends InsightIntentEntryExecutor<OpenResult> {
  async onExecute(): Promise<insightIntent.IntentResult<OpenResult>> {
    TabRequest.open(TabIndex.MEDICINES);
    const r: insightIntent.IntentResult<OpenResult> = {
      code: 0, result: { message: 'Opening your medicines. Scan the box or type the name to add it.' }
    };
    return r;
  }
}
