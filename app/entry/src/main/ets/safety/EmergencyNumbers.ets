// Agent-side view of the emergency number. The country table lives in common/EmergencyNumbers (shared with the
// SOS and emergency card screens), so Celia always says the same number those screens dial.

import { i18n } from '@kit.LocalizationKit';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';

export class EmergencyNumbers {
  // Ambulance number for an ISO 3166-1 alpha-2 region; unknown → 112.
  static forRegion(region: string): string {
    return emergencyFor(region).ambulance;
  }

  // Profile country first (set in onboarding), then the phone's region.
  static current(profileCountry?: string): string {
    const country: string = profileCountry !== undefined && profileCountry.length > 0 ? profileCountry : systemCountry();
    return EmergencyNumbers.forRegion(country);
  }

  static locale(): string {
    try {
      return `${i18n.System.getSystemLanguage()}-${i18n.System.getSystemRegion()}`;
    } catch (e) {
      return 'en-GB';
    }
  }
}
