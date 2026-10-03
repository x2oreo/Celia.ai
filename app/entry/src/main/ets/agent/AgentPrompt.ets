// "Ask Celia" from any screen: the caller queues a question and switches to the Agent tab; AgentPage sends it.
// The queue survives until the chat screen is built for the first time (tabs are built lazily).

import { Listener, Listeners } from '../common/Listeners';
import { TabIndex } from '../common/Routes';
import { TabRequest } from '../common/TabRequest';

export class AgentPrompt {
  private static pending: string[] = [];
  private static listeners: Listeners<string> = new Listeners<string>();

  static ask(text: string): void {
    const t: string = text.trim();
    if (t.length === 0) {
      return;
    }
    if (AgentPrompt.listeners.size() > 0) {
      AgentPrompt.listeners.emit(t);
    } else {
      AgentPrompt.pending.push(t);
    }
    TabRequest.open(TabIndex.AGENT);
  }

  // Returns queued questions (oldest first) and clears the queue.
  static drain(): string[] {
    const out: string[] = AgentPrompt.pending;
    AgentPrompt.pending = [];
    return out;
  }

  static onAsk(cb: Listener<string>): () => void {
    return AgentPrompt.listeners.add(cb);
  }
}
