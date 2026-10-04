// Nearby hospital / pharmacy / defibrillator (T26, fallback without a Map Kit key). Opens a map search for the
// place type; the map app or browser uses the phone's own location, so this app never sends the location anywhere.
// URL format: Google Maps URLs (documented, no API key): https://developers.google.com/maps/documentation/urls
// The full in-app map (Map Kit + Site Kit) needs an AppGallery Connect key - see docs/ARCHITECTURE.md.

export type NearbyKind = 'HOSPITAL' | 'PHARMACY' | 'AED';

const QUERY: Map<NearbyKind, string> = new Map<NearbyKind, string>([
  ['HOSPITAL', 'hospital emergency room'],
  ['PHARMACY', 'pharmacy'],
  ['AED', 'AED defibrillator']
]);

export function nearbySearchUrl(kind: NearbyKind): string {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(QUERY.get(kind) ?? 'hospital')}`;
}
