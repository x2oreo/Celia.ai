// Scan Kit camera / album scan → GTIN → box details (F-36). The system scan UI needs no camera permission and
// can read a barcode from a photo in the gallery (works on the emulator).
//
// A GTIN is resolved in this order: boxes the user taught us (any country) → Polish register (bundled) → demo
// codes. Unknown boxes can be taught once ("type the name on the box"), stored on device only.

import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { gtinCountry, lookupDemoGtin, parseGs1 } from './Gs1';
import { GtinCatalog } from './GtinCatalog';
import { BoxInfo } from '../model/BoxInfo';
import { LocalStore } from '../data/LocalStore';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Barcode');

const LEARNED_PREFIX: string = 'gtin.';

export class BarcodeResult {
  raw: string;
  gtin: string;            // '' if the code is not a valid GTIN
  box: BoxInfo | undefined;

  constructor(raw: string, gtin: string, box: BoxInfo | undefined) {
    this.raw = raw;
    this.gtin = gtin;
    this.box = box;
  }
}

async function learnedBox(gtin: string): Promise<BoxInfo | undefined> {
  const json: string = await LocalStore.get().getSetting(LEARNED_PREFIX + gtin, '');
  if (json.length === 0) {
    return undefined;
  }
  try {
    return JSON.parse(json) as BoxInfo;
  } catch (e) {
    return undefined;
  }
}

export async function lookupBox(gtin: string): Promise<BoxInfo | undefined> {
  return (await learnedBox(gtin)) ?? (await GtinCatalog.get().lookup(gtin)) ?? lookupDemoGtin(gtin);
}

export async function resolveBarcode(raw: string): Promise<BarcodeResult> {
  const gtin: string | undefined = parseGs1(raw);
  if (gtin === undefined) {
    return new BarcodeResult(raw, '', undefined);
  }
  return new BarcodeResult(raw, gtin, await lookupBox(gtin));
}

// "Teach this barcode": remember what the user typed for a box we don't know (e.g. Bulgarian boxes).
export async function learnBox(gtin: string, name: string, ingredients: string, strength: string): Promise<BoxInfo> {
  const box: BoxInfo = {
    gtin: gtin,
    brand: name,
    substance: ingredients,
    ingredients: ingredients,
    strength: strength,
    form: '',
    pack: '',
    atc: '',
    holder: '',
    rxCategory: '',
    leafletUrl: '',
    country: gtinCountry(gtin),
    source: 'LEARNED',
    sourceDate: new Date().toISOString().substring(0, 10)
  };
  await LocalStore.get().setSetting(LEARNED_PREFIX + gtin, JSON.stringify(box));
  return box;
}

// A box /box-identify found and the user confirmed ("Yes, this is my box"). Stored on this phone like a taught
// box, so the next scan resolves instantly and offline.
export async function learnOnlineBox(gtin: string, brand: string, ingredients: string[], strength: string,
  form: string, sourceName: string, sourceUrl: string): Promise<BoxInfo> {
  const box: BoxInfo = {
    gtin: gtin,
    brand: brand,
    substance: ingredients.join(' + '),
    ingredients: ingredients.join(' + '),
    strength: strength,
    form: form,
    pack: '',
    atc: '',
    holder: '',
    rxCategory: '',
    leafletUrl: '',
    country: gtinCountry(gtin),
    source: 'ONLINE',
    sourceDate: new Date().toISOString().substring(0, 10),
    sourceName: sourceName,
    sourceUrl: sourceUrl
  };
  await LocalStore.get().setSetting(LEARNED_PREFIX + gtin, JSON.stringify(box));
  return box;
}

export async function forgetBox(gtin: string): Promise<void> {
  await LocalStore.get().setSetting(LEARNED_PREFIX + gtin, '');
}

export async function scanBox(ctx: common.Context): Promise<BarcodeResult | undefined> {
  try {
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.ALL],
      enableMultiMode: false,
      enableAlbum: true
    };
    const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(ctx, options);
    log.info(`scanned ${result.scanType}`);
    return await resolveBarcode(result.originalValue);
  } catch (e) {
    log.warn(`scan cancelled or failed: ${JSON.stringify(e)}`);
    return undefined;
  }
}
