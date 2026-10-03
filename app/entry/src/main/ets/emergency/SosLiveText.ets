// Pure pieces of the SOS live status (B13), unit tested. emergency/LiveStatus.ets builds the Live View and the
// notification fallback from them. No model text: everything is fixed copy or the alert's own reason.

// Live View Kit replaces this placeholder with its own ticking timer, so one start call is enough.
export const TIMER_PLACEHOLDER: string = '${placeholder.timer}';

export type SosEnd = 'OK' | 'SENT' | 'CLOSED';

// The second line: the alert's reason, or the fixed hint for a manual SOS (empty text is rejected by the system).
export function liveContent(reason: string, fallback: string): string {
  return reason.trim().length > 0 ? reason.trim() : fallback;
}

// The Live View title template (resource text with the placeholder) with a seconds fallback for the notification,
// which has no timer of its own.
export function notificationTitle(template: string, seconds: number): string {
  return template.replace(TIMER_PLACEHOLDER, `${seconds} s`);
}

// Resource name of the title shown when the Live View ends.
export function endTitleKey(end: SosEnd): string {
  if (end === 'OK') {
    return 'ntf_live_end_ok';
  }
  return end === 'SENT' ? 'ntf_live_end_sent' : 'ntf_live_end_closed';
}

// A colour resource (ARGB number from resourceManager) as the '#AARRGGBB' string Live View expects.
export function argbHex(argb: number): string {
  const v: number = argb >>> 0;
  let s: string = v.toString(16).toUpperCase();
  while (s.length < 8) {
    s = '0' + s;
  }
  return `#${s}`;
}
