// Emergency number by region (ISO 3166-1 alpha-2). 112 works across the EU and on most GSM phones,
// so it is the default. Never hardcode 911 (HeartBeat lesson).

import { i18n } from '@kit.LocalizationKit';

const NUMBERS: Record<string, string> = {
  'US': '911',
  'CA': '911',
  'MX': '911',
  'GB': '999',
  'AU': '000',
  'NZ': '111',
  'IN': '112',
  'CN': '120',
  'JP': '119',
  'KR': '119'
};

export class EmergencyNumbers {
  static forRegion(region: string): string {
    const n: string | undefined = NUMBERS[region.toUpperCase()];
    return n !== undefined ? n : '112';
  }

  static current(): string {
    try {
      return EmergencyNumbers.forRegion(i18n.System.getSystemRegion());
    } catch (e) {
      return '112';
    }
  }

  static locale(): string {
    try {
      return `${i18n.System.getSystemLanguage()}-${i18n.System.getSystemRegion()}`;
    } catch (e) {
      return 'en-GB';
    }
  }
}
