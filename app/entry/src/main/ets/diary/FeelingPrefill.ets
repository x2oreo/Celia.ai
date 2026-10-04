// A mood picked on the home-screen feeling card (widget/pages/FeelingCard.ets): the feeling page opens with it
// selected, and the user still saves. Kept until the page takes it (cold start) or handed straight to an open page.

import { Listener, Listeners } from '../common/Listeners';
import { Mood, MOODS } from './Diary';

export class FeelingPrefill {
  private static pending: Mood | undefined = undefined;
  private static listeners: Listeners<Mood> = new Listeners<Mood>();

  // Ignores anything that is not one of the five moods.
  static set(raw: string): void {
    const m: Mood | undefined = MOODS.find((x: Mood) => x === raw);
    if (m === undefined) {
      return;
    }
    if (FeelingPrefill.listeners.size() > 0) {
      FeelingPrefill.listeners.emit(m);
    } else {
      FeelingPrefill.pending = m;
    }
  }

  static take(): Mood | undefined {
    const m: Mood | undefined = FeelingPrefill.pending;
    FeelingPrefill.pending = undefined;
    return m;
  }

  static onSet(cb: Listener<Mood>): () => void {
    return FeelingPrefill.listeners.add(cb);
  }
}
