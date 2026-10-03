// Switch the bottom tab from code that lives outside MainTabs (pushed pages, Celia intents). A request made
// before MainTabs exists (intent cold start) is kept and applied when the tabs appear.

import { Listener, Listeners } from './Listeners';

export class TabRequest {
  private static pending: number = -1;
  private static listeners: Listeners<number> = new Listeners<number>();

  static open(tab: number): void {
    if (TabRequest.listeners.size() > 0) {
      TabRequest.listeners.emit(tab);
    } else {
      TabRequest.pending = tab;
    }
  }

  // Returns the pending tab (-1 if none) and clears it.
  static take(): number {
    const t: number = TabRequest.pending;
    TabRequest.pending = -1;
    return t;
  }

  static onOpen(cb: Listener<number>): () => void {
    return TabRequest.listeners.add(cb);
  }
}
