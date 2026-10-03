// Scan Kit camera / album scan → GTIN → ingredient (F-36). The system scan UI needs no camera permission and
// can read a barcode from a photo in the gallery (works on the emulator).

import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { GtinEntry, lookupGtin, parseGs1 } from './Gs1';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Barcode');

export class BarcodeResult {
  raw: string;
  gtin: string;            // '' if the code is not a valid GTIN
  entry: GtinEntry | undefined;

  constructor(raw: string, gtin: string, entry: GtinEntry | undefined) {
    this.raw = raw;
    this.gtin = gtin;
    this.entry = entry;
  }
}

export function resolveBarcode(raw: string): BarcodeResult {
  const gtin: string | undefined = parseGs1(raw);
  return new BarcodeResult(raw, gtin ?? '', gtin === undefined ? undefined : lookupGtin(gtin));
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
    return resolveBarcode(result.originalValue);
  } catch (e) {
    log.warn(`scan cancelled or failed: ${JSON.stringify(e)}`);
    return undefined;
  }
}
