import { describe, it, expect } from '@ohos/hypium';
import { CatalogIndex, parseCatalog } from '../main/ets/drugs/GtinCatalog';
import { gtinCountry, parseGs1 } from '../main/ets/drugs/Gs1';
import { atcGroup, atcLevel2Codes, isAtcCode } from '../main/ets/drugs/Atc';
import { describeBox, infoRows, kindOf, rxLabel } from '../main/ets/drugs/BoxFacts';
import { DrugChecker } from '../main/ets/drugs/DrugChecker';
import { BoxInfo } from '../main/ets/model/BoxInfo';

// Two real rows in the shape written by data/export_gtins.py.
const FIXTURE: string = '{"source":"test","date":"2026-10-03",' +
  '"forms":["Granules for oral suspension","Film-coated tablets"],' +
  '"holders":["Viatris Healthcare Sp. z o.o.","US Pharmacia Sp. z o.o."],"products":[' +
  '["Klacid","Clarithromycinum","clarithromycin","125 mg/5 ml",0,"J01FA09",0,"100033462",' +
  '"5909990331710|Rp|1 butelka 60 ml;5909990331727|Rp|1 butelka 100 ml"],' +
  '["Apap","Paracetamolum","paracetamol","500 mg",1,"N02BE01",1,"100006494","5909990296026|OTC|6 tabl."]]}';

export default function boxCatalogTest() {
  describe('GtinCatalog', () => {
    it('indexesEveryPack', 0, () => {
      const index: CatalogIndex = parseCatalog(FIXTURE);
      expect(index.size).assertEqual(3);
    });

    it('realPolishBoxResolves', 0, () => {
      const box: BoxInfo | undefined = parseCatalog(FIXTURE).lookup('5909990331727');
      expect(box !== undefined).assertTrue();
      expect(box?.brand).assertEqual('Klacid');
      expect(box?.ingredients).assertEqual('clarithromycin');
      expect(box?.pack).assertEqual('1 butelka 100 ml');
      expect(box?.rxCategory).assertEqual('Rp');
      expect(box?.holder).assertEqual('Viatris Healthcare Sp. z o.o.');
      expect(box?.country).assertEqual('PL');
      expect(box?.leafletUrl.endsWith('/100033462/leaflet')).assertTrue();
    });

    it('barcodeFromBoxScanResolves', 0, () => {
      // EAN-13 printed on the box and the GS1 DataMatrix (FMD) code give the same GTIN.
      expect(parseGs1('5909990331710')).assertEqual('5909990331710');
      expect(parseGs1(']d2010590999033171017280131\u001d10LOT1')).assertEqual('5909990331710');
    });

    it('unknownGtinIsUndefined', 0, () => {
      expect(parseCatalog(FIXTURE).lookup('3800000000003') === undefined).assertTrue();
    });
  });

  describe('BoxFacts', () => {
    it('countryFromPrefix', 0, () => {
      expect(gtinCountry('5909990331710')).assertEqual('PL');
      expect(gtinCountry('3800123456789')).assertEqual('BG');
      expect(gtinCountry('4006381333931')).assertEqual('DE');
      expect(gtinCountry('9990000000000')).assertEqual('');
    });

    it('atcGroups', 0, () => {
      expect(atcGroup('J01FA09')).assertEqual('Antibacterials for systemic use');
      expect(atcGroup('N02BE01')).assertEqual('Analgesics');
      expect(atcGroup('Z99')).assertEqual('');
      expect(atcGroup('')).assertEqual('');
      for (const code of atcLevel2Codes()) {
        expect(isAtcCode(code)).assertTrue();
      }
    });

    it('rxLabels', 0, () => {
      expect(rxLabel('OTC')).assertEqual('Over the counter (no prescription)');
      expect(rxLabel('Rp')).assertEqual('Prescription only');
      expect(rxLabel('Lz')).assertEqual('Hospital use only');
    });

    it('describesKnownBox', 0, () => {
      const box: BoxInfo = parseCatalog(FIXTURE).lookup('5909990331710') as BoxInfo;
      const kind: string = kindOf(box);
      expect(kind).assertEqual(DrugChecker.get().entry('clarithromycin')?.drugClass ?? '');
      const text: string = describeBox(box);
      expect(text.startsWith('Klacid is a')).assertTrue();
      expect(text.indexOf('containing clarithromycin') > 0).assertTrue();
      expect(text.indexOf('Prescription only in Poland.') > 0).assertTrue();
      expect(infoRows(box).length >= 8).assertTrue();
    });
  });
}
