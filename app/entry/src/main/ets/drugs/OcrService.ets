// OWNER: Kaloyan — on-device text recognition (Core Vision Kit). The photo never leaves the phone on this path.
// Returns '' when OCR is unavailable (e.g. not supported on the emulator) so callers fall back gracefully.

import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('OcrService');

export class OcrService {
  private static instance: OcrService | undefined = undefined;
  private ready: boolean = false;

  static get(): OcrService {
    if (OcrService.instance === undefined) {
      OcrService.instance = new OcrService();
    }
    return OcrService.instance;
  }

  async recognize(pixelMap: image.PixelMap): Promise<string> {
    try {
      if (!this.ready) {
        this.ready = await textRecognition.init();
        if (!this.ready) {
          log.warn('textRecognition.init returned false');
          return '';
        }
      }
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const config: textRecognition.TextRecognitionConfiguration = { isDirectionDetectionSupported: true };
      const result: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(visionInfo, config);
      log.info(`OCR read ${result.value.length} chars`);
      return result.value;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`OCR unavailable: ${err.code} ${err.message}`);
      return '';
    }
  }

  async release(): Promise<void> {
    if (this.ready) {
      try {
        await textRecognition.release();
      } catch (e) {
        log.warn(`OCR release failed: ${String(e)}`);
      }
      this.ready = false;
    }
  }
}
