import { describe, it, expect } from '@ohos/hypium';
import { cardSpeech } from '../main/ets/emergency/CardSpeech';
import { nearbySearchUrl } from '../main/ets/emergency/NearbyHelp';
import { cardText as cardTextFor } from '../main/ets/common/CardStrings';
import { Profile as SpeechProfile } from '../main/ets/model/Profile';
import { CARD_VIEWER_URL, CardPayload, cardLink, decodePayload, parseCardLink } from '../main/ets/emergency/CardLink';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';

function profile(name: string, notes: string): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: true, notes: notes, name: name,
    contacts: [{ name: 'Мария', phone: '+359 88 123 4567', relation: 'mother' }]
  };
  return p;
}

function med(id: number, name: string, ingredient: string, dose: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: dose, addedAt: 0 };
  return m;
}

export default function cardLinkTest() {
  describe('CardLink', () => {
    it('linkPointsToViewerWithoutPlainUrlsInside', 0, () => {
      const link: string = cardLink(profile('Georgi', ''), [med(1, 'Concor', 'bisoprolol', '5 mg')], 'PL');
      expect(link.startsWith(CARD_VIEWER_URL + '#')).assertTrue();
      // The fragment is base64url only - no second URL a camera could jump to.
      expect(/^[A-Za-z0-9_-]+$/.test(link.substring(link.indexOf('#') + 1))).assertTrue();
    });

    it('roundTripKeepsCyrillicAndContacts', 0, () => {
      const link: string = cardLink(profile('Георги', 'Носи ICD'), [med(1, 'Concor', 'bisoprolol', '5 mg')], 'bg');
      const p: CardPayload | undefined = parseCardLink(link);
      expect(p !== undefined).assertTrue();
      expect(p?.n).assertEqual('Георги');
      expect(p?.g).assertEqual('LQT2');
      expect(p?.i).assertEqual(1);
      expect(p?.cc).assertEqual('BG');
      expect(p?.o).assertEqual('Носи ICD');
      expect(p?.c[0][0]).assertEqual('Мария');
      expect(p?.m[0]).assertEqual('Concor (bisoprolol) 5 mg');
    });

    it('longCardsAreTrimmedToFitTheQr', 0, () => {
      const meds: Medication[] = [];
      for (let i = 0; i < 60; i++) {
        meds.push(med(i, `Medicine number ${i}`, 'paracetamol', '500 mg'));
      }
      const link: string = cardLink(profile('Georgi', 'x'.repeat(500)), meds, 'PL');
      const p: CardPayload | undefined = parseCardLink(link);
      expect(link.length < CARD_VIEWER_URL.length + 1 + 900).assertTrue();
      expect(p !== undefined && p.x > 0 && p.m.length + p.x === 60).assertTrue();
    });

    it('rejectsForeignOrBrokenLinks', 0, () => {
      expect(parseCardLink('https://example.com/card/#abc') === undefined).assertTrue();
      expect(parseCardLink(CARD_VIEWER_URL + '#not-base64!') === undefined).assertTrue();
      expect(decodePayload('') === undefined).assertTrue();
    });
  });

  describe('CardSpeech', () => {
    it('speaksMedicalPartNeverNameOrContacts', 0, () => {
      const p: SpeechProfile = { name: 'Anna Kowalska', condition: 'LQTS', genotype: 'LQT2', hasIcd: true,
        notes: 'Allergic to latex', contacts: [{ name: 'Marek', relation: 'husband', phone: '+48600100200' }] };
      const pl: string = cardSpeech(cardTextFor('pl'), p, []);
      expect(pl.includes(cardTextFor('pl').avoid)).assertTrue();
      expect(pl.includes('Anna')).assertFalse();
      expect(pl.includes('Marek')).assertFalse();
      expect(pl.includes('+48600100200')).assertFalse();
      expect(pl.includes('latex')).assertFalse();
      expect(cardSpeech(cardTextFor('en'), p, []).includes('L Q T 2')).assertTrue();
    });

    it('nearbySearchIsAKeylessMapLinkWithoutLocation', 0, () => {
      const u: string = nearbySearchUrl('AED');
      expect(u.startsWith('https://www.google.com/maps/search/?api=1&query=')).assertTrue();
      expect(u.includes('AED')).assertTrue();
      expect(u.includes('lat=') || u.includes('ll=') || u.includes('@')).assertFalse();   // no coordinates
    });
  });
}
