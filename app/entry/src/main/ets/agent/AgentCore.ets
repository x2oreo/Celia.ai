// OWNER: Kaloyan — STUB. Replace with AgentClient (/agent Edge Function) + ResponseValidator + fallback.
// Rules: verdicts come from DrugChecker only; emergency keywords bypass the LLM. See docs/ARCHITECTURE.md.

import { AgentReply } from '../model/AgentTypes';
import { Listener, Listeners } from '../common/Listeners';

export class AgentCore {
  private static instance: AgentCore | undefined = undefined;

  private proactive: Listeners<AgentReply> = new Listeners<AgentReply>();

  static get(): AgentCore {
    if (AgentCore.instance === undefined) {
      AgentCore.instance = new AgentCore();
    }
    return AgentCore.instance;
  }

  async send(text: string): Promise<AgentReply> {
    const reply: AgentReply = {
      text: `Stub agent: I received "${text}". The real agent is not connected yet.`,
      actions: [],
      fallback: true
    };
    return reply;
  }

  // Triggered by VitalsAlert in the real implementation. Returns an unsubscribe function.
  onProactive(cb: Listener<AgentReply>): () => void {
    return this.proactive.add(cb);
  }
}
