// Celia → "Read my emergency card": opens the Emergency tab and reads the medical part of the card aloud in the
// card's language (emergency/CardSpeech.ets — no name or contacts). Static pre-translated text, no LLM.

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';
import { cardText } from '../common/CardStrings';
import { cardSpeech } from '../emergency/CardSpeech';
import { VoiceOutput } from '../voice/VoiceOutput';
import { Profile } from '../model/Profile';

class ReadCardResult {
  public message?: string = '';
}

@InsightIntentEntry({
  intentName: 'ReadEmergencyCard',
  domain: 'LocalDomain',
  intentVersion: '1.0.0',
  displayName: 'Read emergency card aloud',
  displayDescription: 'Reads the Long QT emergency card aloud in the card language',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens the user\'s Long QT emergency card and reads its medical instructions aloud (in the card language) for a paramedic or bystander. Utterances: "read my emergency card", "tell them about my condition".',
  keywords: ['read emergency card', 'read aloud', 'paramedic', 'Long QT card'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: {
    'type': 'object',
    'properties': {}
  }
})
export default class ReadEmergencyCardIntent extends InsightIntentEntryExecutor<ReadCardResult> {
  async onExecute(): Promise<insightIntent.IntentResult<ReadCardResult>> {
    TabRequest.open(TabIndex.EMERGENCY);
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    if (profile === undefined) {
      const none: insightIntent.IntentResult<ReadCardResult> = {
        code: -1, result: { message: 'There is no emergency card yet. Set up your profile in the app first.' }
      };
      return none;
    }
    const spoken: boolean = await VoiceOutput.get().say(
      cardSpeech(cardText(profile.cardLanguage), profile, await LocalStore.get().listMeds()), cardText(profile.cardLanguage).code);
    const r: insightIntent.IntentResult<ReadCardResult> = {
      code: 0,
      result: { message: spoken ? 'Reading your emergency card.' : 'Here is your emergency card. Show the screen.' }
    };
    return r;
  }
}
