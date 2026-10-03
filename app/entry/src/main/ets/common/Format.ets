// Small date/time formatting helpers (local time, English month names; numbers are locale-neutral).

const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function clock(ts: number): string {
  const d: Date = new Date(ts);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

export function sameDay(a: number, b: number): boolean {
  const x: Date = new Date(a);
  const y: Date = new Date(b);
  return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate();
}

// "Today", "Yesterday" or "3 Oct".
export function dayLabel(ts: number, now: number): string {
  if (sameDay(ts, now)) {
    return 'Today';
  }
  if (sameDay(ts, now - 86400000)) {
    return 'Yesterday';
  }
  const d: Date = new Date(ts);
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

export function dateTime(ts: number, now: number): string {
  return `${dayLabel(ts, now)} ${clock(ts)}`;
}

export function fullDate(ts: number): string {
  const d: Date = new Date(ts);
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}, ${clock(ts)}`;
}
