// Celia (system assistant) → "Can I take ibuprofen?" answered without opening the app.
// Same deterministic path as the in-app agent (DrugChecker + ComboRules); no LLM involved.

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { checkDrugFull } from '../agent/DrugCheckFlow';
import { verdictText } from '../agent/VerdictText';
import { VerdictCardPayload } from '../model/AgentTypes';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('CheckDrugIntent');

class CheckDrugResult {
  public verdict?: string = '';      // RiskLevel after interaction rules
  public ingredient?: string = '';
  public message?: string = '';      // what Celia reads out
}

@InsightIntentEntry({
  intentName: 'CheckDrugSafety',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Check medicine safety',
  displayDescription: 'Checks whether a medicine is on QT-risk lists for a person with Long QT syndrome',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Given a medicine name (brand or generic), returns whether it is on QT-prolonging risk lists for a person with Long QT syndrome, taking their current medicines into account.',
  keywords: ['medicine', 'drug check', 'can I take', 'is it safe', 'Long QT', 'lek'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'properties': {
      'drugName': {
        'type': 'string',
        'description': 'Medicine name, brand or generic, e.g. "Klacid" or "ibuprofen"',
        'minLength': 1
      }
    },
    'required': ['drugName']
  }
})
export default class CheckDrugIntent extends InsightIntentEntryExecutor<CheckDrugResult> {
  public drugName: string = '';

  async onExecute(): Promise<insightIntent.IntentResult<CheckDrugResult>> {
    const name: string = this.drugName.trim().slice(0, 80);
    if (name.length === 0) {
      const bad: insightIntent.IntentResult<CheckDrugResult> = {
        code: -1,
        result: { verdict: 'UNKNOWN_DRUG', ingredient: '', message: 'Which medicine should I check?' }
      };
      return bad;
    }
    try {
      const card: VerdictCardPayload = await checkDrugFull(name);
      const ok: insightIntent.IntentResult<CheckDrugResult> = {
        code: 0,
        result: { verdict: card.combinedRisk, ingredient: card.ingredient, message: verdictText(card) }
      };
      return ok;
    } catch (e) {
      log.error(`intent failed: ${String(e)}`);
      const failed: insightIntent.IntentResult<CheckDrugResult> = {
        code: -1,
        result: { verdict: 'UNKNOWN_DRUG', ingredient: '',
          message: 'I could not check that medicine right now. Ask a pharmacist before taking it.' }
      };
      return failed;
    }
  }
}
