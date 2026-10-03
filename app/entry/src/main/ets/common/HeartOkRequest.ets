// "I'm OK" on a heart-alert notification (B7). EntryAbility has no access to the check-in sheet, so it asks the
// app root (pages/Index.ets) to answer the open check-in the same way the sheet's "I'm fine" does.

import { Listener, Listeners } from './Listeners';

export class HeartOkRequest {
  private static listeners: Listeners<number> = new Listeners<number>();

  static send(now: number): void {
    HeartOkRequest.listeners.emit(now);
  }

  static onSend(cb: Listener<number>): () => void {
    return HeartOkRequest.listeners.add(cb);
  }
}
