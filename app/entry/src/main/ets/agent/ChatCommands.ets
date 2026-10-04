// Chat commands the agent understands without the model (works offline): "new chat", "start over",
// "save this chat (and start a new one)". Only short, whole-message commands match - anything longer goes to the
// model, which can call start_new_chat. Runs after SafetyGate, so an emergency always wins.

const NEW_CHAT: RegExp = new RegExp(
  '^(please |ok |okay )?(' +
    '(start|open|begin|make)( a)? (new|fresh) (chat|conversation)( please)?' +
    '|new (chat|conversation)( please)?' +
    '|start over|start again|clear (the |this )?(chat|conversation)' +
    '|save (this|the|my) (chat|conversation)( and (start|open) (a )?(new|fresh)( one| chat| conversation)?)?' +
    ')$');

export class ChatCommands {
  static isNewChat(text: string): boolean {
    const t: string = text.toLowerCase().replace(/[’']/g, '').replace(/[.!?,]+/g, ' ').replace(/\s+/g, ' ').trim();
    return t.length <= 64 && NEW_CHAT.test(t);
  }
}
