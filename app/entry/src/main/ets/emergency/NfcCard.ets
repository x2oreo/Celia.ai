// NFC handover of the emergency card (Workstream B14). BUILT, UNVERIFIED: the emulator has no NFC, and no real tag
// has been written yet. Writes the card link (the same one the QR shows) as one NDEF URI record, so any phone that
// taps the tag opens the card viewer.
//
// APIs (checked against the API 20 SDK declarations, @ohos.nfc.tag / tag/nfctech / @ohos.nfc.controller):
//   canIUse('SystemCapability.Communication.NFC.Tag')          - device has NFC tag support
//   nfcController.isNfcOpen()                                 - NFC switched on
//   tag.on('readerMode', element, [NDEF, NDEF_FORMATABLE], cb) - foreground reader mode (ohos.permission.NFC_TAG)
//   tag.getNdef(info) → connect() → isNdefWritable() → writeNdef(msg)
//   tag.getNdefFormatable(info) → connect() → format(msg)      - blank tags
//   tag.ndef.makeUriRecord(uri), tag.ndef.createNdefMessage([record])

import { nfcController, tag } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager, common } from '@kit.AbilityKit';
import { Logger } from '../common/Logger';
import { utf8Encode } from '../common/Base64Url';

const log: Logger = new Logger('NfcCard');

// User memory of the common NFC Forum Type 2 tags (NXP datasheets): NTAG213 144 B, NTAG215 504 B, NTAG216 888 B.
export const NTAG213_BYTES: number = 144;
export const NTAG215_BYTES: number = 504;
export const NTAG216_BYTES: number = 888;

export type NfcAvailability = 'UNSUPPORTED' | 'OFF' | 'READY';
export type NfcWriteResult = 'WRITTEN' | 'READ_ONLY' | 'IO_FAILED' | 'NOT_NDEF' | 'ERROR';

/**
 * Bytes an NDEF message with one URI record takes on a Type 2 tag, including the NDEF TLV and terminator
 * (NFC Forum NDEF 1.0 and URI RTD 1.0): 'https://' and 'http://' are stored as a one-byte prefix code.
 */
export function ndefUriBytes(uri: string): number {
  let rest: string = uri;
  if (uri.startsWith('https://')) {
    rest = uri.substring('https://'.length);
  } else if (uri.startsWith('http://')) {
    rest = uri.substring('http://'.length);
  }
  const payload: number = 1 + utf8Encode(rest).length;          // prefix code + URI bytes
  const header: number = payload < 256 ? 4 : 7;                 // flags, type length, payload length (1 or 4), 'U'
  const message: number = header + payload;
  const tlv: number = message < 255 ? 2 : 4;                    // 0x03 + length (1 or 3 bytes)
  return tlv + message + 1;                                     // + 0xFE terminator
}

/** The smallest common tag the link fits on, as a short name for the UI ('' when it fits none of them). */
export function smallestTagFor(uri: string): string {
  const n: number = ndefUriBytes(uri);
  if (n <= NTAG213_BYTES) {
    return 'NTAG213';
  }
  if (n <= NTAG215_BYTES) {
    return 'NTAG215';
  }
  return n <= NTAG216_BYTES ? 'NTAG216' : '';
}

/** Maps a write failure to what the user can do about it. Pure, for tests. */
export function resultForError(code: number): NfcWriteResult {
  // 3100204 "The tag I/O operation failed" (moved away too early, or the tag is too small) and 3100201 "tag running
  // state is abnormal" (lost contact) - both fixed by holding a big enough tag still and trying again.
  return code === 3100204 || code === 3100201 ? 'IO_FAILED' : 'ERROR';
}

export class NfcCard {
  private static element: bundleManager.ElementName | undefined = undefined;

  static availability(): NfcAvailability {
    if (!canIUse('SystemCapability.Communication.NFC.Tag')) {
      return 'UNSUPPORTED';
    }
    try {
      return nfcController.isNfcOpen() ? 'READY' : 'OFF';
    } catch (e) {
      log.warn(`isNfcOpen failed: ${JSON.stringify(e)}`);
      return 'UNSUPPORTED';
    }
  }

  /**
   * Waits (in the foreground) for one tag and writes `uri` to it. `done` is called once with the outcome. Call
   * stop() when the page goes away or the user cancels.
   */
  static start(ctx: common.UIAbilityContext, uri: string, done: (r: NfcWriteResult) => void): boolean {
    NfcCard.stop();
    const element: bundleManager.ElementName = {
      bundleName: ctx.abilityInfo.bundleName,
      abilityName: ctx.abilityInfo.name,
      moduleName: ctx.abilityInfo.moduleName,
      deviceId: ''
    };
    try {
      tag.on('readerMode', element, [tag.NDEF, tag.NDEF_FORMATABLE], (err: BusinessError, info: tag.TagInfo) => {
        if (err) {
          log.warn(`reader mode error ${err.code}`);
          done('ERROR');
          return;
        }
        NfcCard.write(info, uri).then((r: NfcWriteResult) => {
          NfcCard.stop();
          done(r);
        });
      });
      NfcCard.element = element;
      return true;
    } catch (e) {
      log.warn(`reader mode failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  static stop(): void {
    if (NfcCard.element === undefined) {
      return;
    }
    try {
      tag.off('readerMode', NfcCard.element);
    } catch (e) {
      log.warn(`reader mode off failed: ${JSON.stringify(e)}`);
    }
    NfcCard.element = undefined;
  }

  private static async write(info: tag.TagInfo, uri: string): Promise<NfcWriteResult> {
    const message: tag.NdefMessage = tag.ndef.createNdefMessage([tag.ndef.makeUriRecord(uri)]);
    const techs: number[] = info.technology;
    try {
      if (techs.includes(tag.NDEF)) {
        const ndef: tag.NdefTag = tag.getNdef(info);
        ndef.connect();
        if (!ndef.isNdefWritable()) {
          return 'READ_ONLY';
        }
        await ndef.writeNdef(message);
        return 'WRITTEN';
      }
      if (techs.includes(tag.NDEF_FORMATABLE)) {
        const blank: tag.NdefFormatableTag = tag.getNdefFormatable(info);
        blank.connect();
        await blank.format(message);
        return 'WRITTEN';
      }
      return 'NOT_NDEF';
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`write failed ${err.code} ${err.message}`);
      return resultForError(err.code);
    }
  }
}
