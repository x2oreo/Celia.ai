// Pure output checks for /med-info (unit-tested in logic.test.ts; the app repeats them in drugs/MedInfoClient.ets).

export const MAX_FIELD = 240;
export const MAX_TIP = 120;
export const MAX_TIPS = 3;

export interface MedInfo {
  recognised: boolean;
  summary: string;
  contains: string;
  usedFor: string;
  tips: string[];
}

// Safety talk the model was told not to produce; a reply containing it is dropped rather than shown.
// Stems match whole word families: "arrhythmia(s)", "torsades", "QTc", "500mg", "2.5 mg".
export const BANNED =
  /\b(qtc?\b|torsade|arrhythmi|heart rhythm|safe for (your|the) heart|stop taking|start taking|\d+([.,]\d+)?\s?(mg|mcg|µg|ml)\b)/i;

export function clip(s: string, max: number): string {
  const t = s.trim().replace(/\s+/g, ' ');
  return t.length > max ? `${t.slice(0, max - 1)}…` : t;
}

// Model JSON → clipped reply, or undefined when it is unrecognised or contains banned talk.
export function cleanReply(p: Partial<MedInfo>): MedInfo | undefined {
  const out: MedInfo = {
    recognised: p.recognised === true,
    summary: clip(typeof p.summary === 'string' ? p.summary : '', MAX_FIELD),
    contains: clip(typeof p.contains === 'string' ? p.contains : '', MAX_FIELD),
    usedFor: clip(typeof p.usedFor === 'string' ? p.usedFor : '', MAX_FIELD),
    tips: (Array.isArray(p.tips) ? p.tips : []).filter((t) => typeof t === 'string').slice(0, MAX_TIPS)
      .map((t) => clip(t, MAX_TIP)).filter((t) => t !== ''),
  };
  if (!out.recognised || out.summary === '') return undefined;
  return BANNED.test([out.summary, out.contains, out.usedFor, ...out.tips].join(' ')) ? undefined : out;
}
