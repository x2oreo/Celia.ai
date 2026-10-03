// Open a pushed page from code that has no NavPathStack (home-screen card taps arriving in EntryAbility).
// A request made before the app root exists (cold start) is kept and applied when it appears.

import { Listener, Listeners } from './Listeners';

export class RouteRequest {
  private static pending: string = '';
  private static listeners: Listeners<string> = new Listeners<string>();

  static open(route: string): void {
    if (RouteRequest.listeners.size() > 0) {
      RouteRequest.listeners.emit(route);
    } else {
      RouteRequest.pending = route;
    }
  }

  // Returns the pending route ('' if none) and clears it.
  static take(): string {
    const r: string = RouteRequest.pending;
    RouteRequest.pending = '';
    return r;
  }

  static onOpen(cb: Listener<string>): () => void {
    return RouteRequest.listeners.add(cb);
  }
}
