// Switch the bottom tab from code that lives outside MainTabs (pushed pages, Celia intents). A request made
// before MainTabs exists (intent cold start) is kept and applied when the tabs appear.
// It also knows which tab is selected and whether a pushed page covers the tabs, so the agent on tab 0 can end a
// live voice session when it goes out of sight.

import { Listener, Listeners } from './Listeners';

export class TabRequest {
  private static pending: number = -1;
  private static listeners: Listeners<number> = new Listeners<number>();
  private static selected: number = 0;
  private static covered: boolean = false;
  private static coverListeners: Listeners<boolean> = new Listeners<boolean>();

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

  // MainTabs reports the selected tab.
  static setCurrent(tab: number): void {
    TabRequest.selected = tab;
  }

  static current(): number {
    return TabRequest.selected;
  }

  // The root Navigation reports when a pushed page hides the tabs or gives them back.
  static setCovered(covered: boolean): void {
    if (TabRequest.covered !== covered) {
      TabRequest.covered = covered;
      TabRequest.coverListeners.emit(covered);
    }
  }

  static isCovered(): boolean {
    return TabRequest.covered;
  }

  static onCovered(cb: Listener<boolean>): () => void {
    return TabRequest.coverListeners.add(cb);
  }
}
