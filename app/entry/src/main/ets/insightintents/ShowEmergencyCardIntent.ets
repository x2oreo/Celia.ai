// Celia → "Show my emergency card": opens the app on the Emergency tab. No LLM involved.
// Tab switch goes through TabRequest (kept until MainTabs appears on a cold start).

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';

class ShowCardResult {
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'ShowEmergencyCard',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Show emergency card',
  displayDescription: 'Opens the Long QT emergency card for doctors, pharmacists and paramedics',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens the medical emergency card of the user (Long QT syndrome, medicines to avoid, contacts).',
  keywords: ['emergency card', 'medical card', 'Long QT card', 'karta'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: {
    'type': 'object',
    'properties': {}
  }
})
export default class ShowEmergencyCardIntent extends InsightIntentEntryExecutor<ShowCardResult> {
  async onExecute(): Promise<insightIntent.IntentResult<ShowCardResult>> {
    TabRequest.open(TabIndex.EMERGENCY);
    await LocalStore.get().logEvent('EMERGENCY', '{"source":"celia_intent","action":"show_card"}');
    const r: insightIntent.IntentResult<ShowCardResult> = { code: 0, result: { message: 'Here is your emergency card.' } };
    return r;
  }
}
