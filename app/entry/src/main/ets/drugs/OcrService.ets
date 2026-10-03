// OWNER: Kaloyan — STUB. Replace with Core Vision Kit text recognition (on-device).

import { image } from '@kit.ImageKit';

export class OcrService {
  private static instance: OcrService | undefined = undefined;

  static get(): OcrService {
    if (OcrService.instance === undefined) {
      OcrService.instance = new OcrService();
    }
    return OcrService.instance;
  }

  async recognize(pixelMap: image.PixelMap): Promise<string> {
    return '';
  }
}
