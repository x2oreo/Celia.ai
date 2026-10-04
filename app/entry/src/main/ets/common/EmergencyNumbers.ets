// Emergency numbers by country (F-26). Two numbers matter: the medical/ambulance line (what to call for a
// cardiac event) and the general emergency number. Sources: EU 112 information pages and national
// regulators - verify locally when travelling. Unknown country → 112 (works in the EU and on most GSM phones).

import { i18n } from '@kit.LocalizationKit';

export interface EmergencyInfo {
  code: string;        // ISO 3166-1 alpha-2
  name: string;
  ambulance: string;
  general: string;
}

function c(code: string, name: string, ambulance: string, general: string): EmergencyInfo {
  const e: EmergencyInfo = { code: code, name: name, ambulance: ambulance, general: general };
  return e;
}

export const EMERGENCY_NUMBERS: EmergencyInfo[] = [
  c('AL', 'Albania', '127', '112'), c('AT', 'Austria', '144', '112'), c('BA', 'Bosnia and Herzegovina', '124', '112'),
  c('BE', 'Belgium', '112', '112'), c('BG', 'Bulgaria', '112', '112'), c('CH', 'Switzerland', '144', '112'),
  c('CY', 'Cyprus', '112', '112'), c('CZ', 'Czechia', '155', '112'), c('DE', 'Germany', '112', '112'),
  c('DK', 'Denmark', '112', '112'), c('EE', 'Estonia', '112', '112'), c('ES', 'Spain', '112', '112'),
  c('FI', 'Finland', '112', '112'), c('FR', 'France', '15', '112'), c('GB', 'United Kingdom', '999', '112'),
  c('GR', 'Greece', '166', '112'), c('HR', 'Croatia', '194', '112'), c('HU', 'Hungary', '104', '112'),
  c('IE', 'Ireland', '112', '112'), c('IS', 'Iceland', '112', '112'), c('IT', 'Italy', '118', '112'),
  c('LT', 'Lithuania', '112', '112'), c('LU', 'Luxembourg', '112', '112'), c('LV', 'Latvia', '113', '112'),
  c('MD', 'Moldova', '112', '112'), c('ME', 'Montenegro', '124', '112'), c('MK', 'North Macedonia', '194', '112'),
  c('MT', 'Malta', '112', '112'), c('NL', 'Netherlands', '112', '112'), c('NO', 'Norway', '113', '112'),
  c('PL', 'Poland', '999', '112'), c('PT', 'Portugal', '112', '112'), c('RO', 'Romania', '112', '112'),
  c('RS', 'Serbia', '194', '112'), c('SE', 'Sweden', '112', '112'), c('SI', 'Slovenia', '112', '112'),
  c('SK', 'Slovakia', '155', '112'), c('TR', 'Türkiye', '112', '112'), c('UA', 'Ukraine', '103', '112'),
  c('US', 'United States', '911', '911'), c('CA', 'Canada', '911', '911'), c('MX', 'Mexico', '911', '911'),
  c('BR', 'Brazil', '192', '190'), c('AR', 'Argentina', '107', '911'), c('AU', 'Australia', '000', '000'),
  c('NZ', 'New Zealand', '111', '111'), c('JP', 'Japan', '119', '110'), c('KR', 'South Korea', '119', '112'),
  c('CN', 'China', '120', '110'), c('IN', 'India', '108', '112'), c('AE', 'United Arab Emirates', '998', '999'),
  c('IL', 'Israel', '101', '100'), c('ZA', 'South Africa', '10177', '112'), c('EG', 'Egypt', '123', '122'),
  c('TH', 'Thailand', '1669', '191')
];

export const FALLBACK: EmergencyInfo = c('', 'Unknown country', '112', '112');

export function emergencyFor(code: string | undefined): EmergencyInfo {
  if (code === undefined || code.length === 0) {
    return FALLBACK;
  }
  const up: string = code.toUpperCase();
  return EMERGENCY_NUMBERS.find((e: EmergencyInfo) => e.code === up) ?? FALLBACK;
}

// Country from the phone's region setting; '' if unavailable.
export function systemCountry(): string {
  try {
    return i18n.System.getSystemRegion();
  } catch (e) {
    return '';
  }
}
