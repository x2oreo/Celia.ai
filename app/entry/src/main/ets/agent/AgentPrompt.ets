// "Ask the agent" from any screen: the caller queues a question and asks for the chat to open; AgentPage sends
// it. The chat is a pushed page, so the queue holds the question until the page is built and drains it.

import { Listener, Listeners } from '../common/Listeners';

export class AgentPrompt {
  private static pending: string[] = [];
  private static listeners: Listeners<string> = new Listeners<string>();
  private static openListeners: Listeners<string> = new Listeners<string>();

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
    AgentPrompt.openListeners.emit(t);
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

  // The app root listens here and brings the chat page to the front.
  static onOpenChat(cb: Listener<string>): () => void {
    return AgentPrompt.openListeners.add(cb);
  }
}
