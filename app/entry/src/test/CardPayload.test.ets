import { describe, it, expect } from '@ohos/hypium';
import {
  CARD_PAYLOAD_VERSION, CARD_VIEWER_URL, CardPayload, MAX_PAYLOAD_CHARS, buildPayload, cardLink, decodePayload,
  encodePayload, fitPayload, parseCardLink, parsePayloadJson, payloadDetailRows
} from '../main/ets/emergency/CardLink';
import { base64UrlEncode, utf8Encode } from '../main/ets/common/Base64Url';
import { CardField, Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { cardLabels } from '../main/ets/common/CardStrings';
import { CardRow, detailRows } from '../main/ets/emergency/EmergencyDetails';

function med(id: number, name: string, ingredient: string, dose: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: dose, addedAt: 0 };
  return m;
}

function demo(): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: true, notes: '', name: 'Anna Kowalska',
    contacts: [{ name: 'Marek', phone: '+48600100200', relation: 'husband' }]
  };
  return p;
}

function withDetails(): Profile {
  const p: Profile = demo();
  p.dateOfBirth = '1990-04-12';
  p.sex = 'FEMALE';
  p.bloodType = 'A+';
  p.allergies = ['penicillin', 'latex'];
  p.icdModel = 'Medtronic Visia AF';
  p.cardiologistName = 'Dr Jan Nowak';
  p.cardiologistPhone = '+48 22 569 01 00';
  p.hospital = 'Szpital Bielański, Warszawa';
  p.extra = [{ label: 'Pacemaker', value: 'no' }];
  return p;
}

// Encodes JSON the way the app did before v2 (a link already printed or shared).
function legacyFragment(json: string): string {
  return base64UrlEncode(utf8Encode(json));
}

const MEDS: Medication[] = [med(1, 'Corgard', 'nadolol', '40 mg')];

// Measured sizes of the in-link fallback (base64url characters after '#'):
//   demo card without details: 187 in v1, 187 in v2 (the details add nothing when empty)
//   demo card with every B4 field filled: 435 — the limit stays 900, as in v1.
const DEMO_V1_CHARS: number = 187;
const DEMO_DETAILS_CHARS: number = 435;

export default function cardPayloadTest() {
  describe('CardPayloadV2', () => {
    it('oldV1LinksStillOpen', 0, () => {
      const v1: string = '{"v":1,"n":"Anna","g":"LQT1","i":0,"m":["Concor (bisoprolol) 5 mg"],' +
        '"c":[["Marek","+48600100200","husband"]],"o":"Allergic to latex","cc":"PL","x":0}';
      const p: CardPayload | undefined = parseCardLink(CARD_VIEWER_URL + '#' + legacyFragment(v1));
      expect(p !== undefined).assertTrue();
      expect(p?.v).assertEqual(1);
      expect(p?.n).assertEqual('Anna');
      expect(p?.o).assertEqual('Allergic to latex');
      expect(p?.b === undefined && p?.a === undefined && p?.e === undefined).assertTrue();
      expect(payloadDetailRows(p as CardPayload, cardLabels('en'), 0).length).assertEqual(0);
      // An encrypted card shared before v2 decrypts to the same v1 JSON.
      expect(parsePayloadJson(v1)?.g).assertEqual('LQT1');
      expect(parsePayloadJson('{"v":3,"g":"LQT1","m":[],"c":[]}') === undefined).assertTrue();
    });

    it('detailsRoundTrip', 0, () => {
      expect(CARD_PAYLOAD_VERSION).assertEqual(2);
      const p: CardPayload | undefined = parseCardLink(cardLink(withDetails(), MEDS, 'PL'));
      expect(p?.v).assertEqual(2);
      expect(p?.d).assertEqual('1990-04-12');
      expect(p?.s).assertEqual('F');
      expect(p?.b).assertEqual('A+');
      expect(p?.a?.join()).assertEqual('penicillin,latex');
      expect(p?.k).assertEqual('Medtronic Visia AF');
      expect(p?.r?.[0]).assertEqual('Dr Jan Nowak');
      expect(p?.h).assertEqual('Szpital Bielański, Warszawa');
      expect(p?.e?.[0][0]).assertEqual('Pacemaker');
      // The scanned card shows the same rows, in the same order, as the owner's own card.
      const now: number = new Date(2026, 9, 4).getTime();
      const scanned: string[] = payloadDetailRows(p as CardPayload, cardLabels('en'), now)
        .map((r: CardRow) => `${r.label}=${r.value}`);
      const own: string[] = detailRows(withDetails(), cardLabels('en'), now).map((r: CardRow) => `${r.label}=${r.value}`);
      expect(scanned.join('|')).assertEqual(own.join('|'));
    });

    it('hiddenFieldsNeverEnterThePayload', 0, () => {
      const prof: Profile = withDetails();
      prof.hiddenOnCard = [CardField.NAME, CardField.CONTACTS, CardField.HOSPITAL, CardField.ALLERGIES];
      prof.notes = 'private note';
      prof.hiddenOnCard.push(CardField.NOTES);
      const p: CardPayload = buildPayload(prof, MEDS, 'PL');
      const json: string = JSON.stringify(p);
      expect(p.n).assertEqual('');
      expect(p.c.length).assertEqual(0);
      expect(p.o).assertEqual('');
      expect(json.includes('Anna')).assertFalse();
      expect(json.includes('Marek')).assertFalse();
      expect(json.includes('Bielański')).assertFalse();
      expect(json.includes('penicillin')).assertFalse();
      expect(json.includes('private note')).assertFalse();
      expect(p.b).assertEqual('A+');
    });

    it('icdModelOnlyWithIcd', 0, () => {
      const prof: Profile = withDetails();
      prof.hasIcd = false;
      expect(buildPayload(prof, MEDS, 'PL').k === undefined).assertTrue();
    });

    it('qrFallbackSizeIsMeasured', 0, () => {
      expect(encodePayload(buildPayload(demo(), MEDS, 'PL')).length).assertEqual(DEMO_V1_CHARS);
      expect(encodePayload(buildPayload(withDetails(), MEDS, 'PL')).length).assertEqual(DEMO_DETAILS_CHARS);
      expect(DEMO_DETAILS_CHARS < MAX_PAYLOAD_CHARS).assertTrue();
      expect(MAX_PAYLOAD_CHARS).assertEqual(900);
    });

    it('worstCaseStillFitsAndKeepsEssentials', 0, () => {
      const prof: Profile = withDetails();
      const long: string = 'x'.repeat(300);
      prof.name = long;
      prof.notes = long;
      prof.hospital = long;
      prof.icdModel = long;
      prof.cardiologistName = long;
      prof.allergies = [long, long, long, long, long, long, long, long];
      prof.extra = [{ label: long, value: long }, { label: long, value: long }, { label: long, value: long }];
      prof.contacts = [{ name: long, phone: '+48600100200', relation: long },
        { name: long, phone: '+48600100201', relation: long }, { name: long, phone: '+48600100202', relation: long }];
      const meds: Medication[] = [];
      for (let i = 0; i < 30; i++) {
        meds.push(med(i, `Medicine number ${i}`, 'paracetamol', '500 mg'));
      }
      const encoded: string = fitPayload(buildPayload(prof, meds, 'PL'));
      expect(encoded.length <= MAX_PAYLOAD_CHARS).assertTrue();
      const p: CardPayload | undefined = decodePayload(encoded);
      expect(p?.g).assertEqual('LQT2');
      expect(p?.i).assertEqual(1);
      expect(p?.b).assertEqual('A+');
      expect((p?.a ?? []).length >= 1).assertTrue();
      expect((p?.c ?? []).length >= 1).assertTrue();
    });

    it('badDetailShapesAreDropped', 0, () => {
      const p: CardPayload | undefined = parsePayloadJson(
        '{"v":2,"n":"","g":"LQT1","i":0,"m":[],"c":[],"o":"","cc":"PL","x":0,"s":"Z","a":"latex","e":[["a"]],"b":5}');
      expect(p !== undefined).assertTrue();
      expect(p?.s === undefined && p?.a === undefined && p?.b === undefined).assertTrue();
      expect(p?.e?.length).assertEqual(0);
    });
  });
}
