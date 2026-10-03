// Celia → "Show my pharmacy card": opens the pharmacy card (the medicines I must avoid, for a pharmacist abroad).
// Navigation only, no LLM. The route goes through RouteRequest (kept until the app root appears on a cold start).

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { RouteRequest } from '../common/RouteRequest';
import { Routes } from '../common/Routes';

class OpenResult {
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'ShowPharmacyCard',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Show pharmacy card',
  displayDescription: 'Opens the card to show a pharmacist: Long QT and the medicines to avoid',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens the user\'s pharmacy card, which tells a pharmacist (also abroad, in their language) that the user has Long QT syndrome and which medicines to avoid. Utterances: "show my pharmacy card", "I\'m at the pharmacy".',
  keywords: ['pharmacy card', 'pharmacist', 'apteka', 'travel', 'Long QT'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: {
    'type': 'object',
    'properties': {}
  }
})
export default class ShowPharmacyCardIntent extends InsightIntentEntryExecutor<OpenResult> {
  async onExecute(): Promise<insightIntent.IntentResult<OpenResult>> {
    RouteRequest.open(Routes.PHARMACY_CARD);
    const r: insightIntent.IntentResult<OpenResult> = { code: 0, result: { message: 'Here is your pharmacy card.' } };
    return r;
  }
}
