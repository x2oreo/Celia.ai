// Feeling diary (B15): a quick "How are you feeling?" entry — a mood and an optional note — stored as an AppEvent
// of kind FEELING next to the symptoms. Manual, no AI, never leaves the phone. Pure and unit-tested.

export type Mood = 'GREAT' | 'GOOD' | 'OKAY' | 'LOW' | 'UNWELL';
export const MOODS: Mood[] = ['GREAT', 'GOOD', 'OKAY', 'LOW', 'UNWELL'];
export const FEELING_NOTE_MAX: number = 120;

export interface FeelingEntry {
  mood: Mood;
  note: string;
}

export function moodLabel(m: Mood): string {
  switch (m) {
    case 'GREAT':
      return 'Great';
    case 'GOOD':
      return 'Good';
    case 'LOW':
      return 'Low';
    case 'UNWELL':
      return 'Unwell';
    default:
      return 'Okay';
  }
}

// LOW and UNWELL are worth a second look (the page offers the symptom log); they are counted separately per day.
export function isLowMood(m: Mood): boolean {
  return m === 'LOW' || m === 'UNWELL';
}

export function buildFeeling(mood: Mood, note: string): FeelingEntry {
  const e: FeelingEntry = { mood: mood, note: note.trim().replace(/\s+/g, ' ').slice(0, FEELING_NOTE_MAX) };
  return e;
}

interface RawFeeling {
  mood?: string;
  note?: string;
}

// Stored detail → entry, or undefined when the detail is broken or the mood unknown.
export function parseFeeling(detail: string): FeelingEntry | undefined {
  let raw: RawFeeling;
  try {
    raw = JSON.parse(detail) as RawFeeling;
  } catch (e) {
    return undefined;
  }
  if (raw === null || typeof raw !== 'object') {
    return undefined;
  }
  const mood: Mood | undefined = MOODS.find((m: Mood) => m === raw.mood);
  if (mood === undefined) {
    return undefined;
  }
  return buildFeeling(mood, typeof raw.note === 'string' ? raw.note : '');
}
