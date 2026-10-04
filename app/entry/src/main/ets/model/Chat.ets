// Saved conversations with the agent. Stored only on this phone (LocalStore, encrypted RDB) - never uploaded.

import { ChatRole, UiAction } from './AgentTypes';

export const MAX_CHATS: number = 50;
export const MAX_CHAT_MESSAGES: number = 200;
export const TITLE_MAX_CHARS: number = 48;

export interface ChatSummary {
  id: number;
  title: string;         // '' until the first user message (then shown as "New chat")
  createdAt: number;
  updatedAt: number;
  messageCount: number;
}

export interface StoredChatMessage {
  id: number;
  chatId: number;
  role: ChatRole;
  text: string;
  ts: number;
  actions: UiAction[];   // only display cards - see keepOnRestore()
}

// A chat's title is the user's first message, shortened at a word boundary. No model involved.
export function chatTitle(firstUserText: string): string {
  const t: string = firstUserText.replace(/\s+/g, ' ').trim();
  if (t.length <= TITLE_MAX_CHARS) {
    return t;
  }
  const cut: string = t.substring(0, TITLE_MAX_CHARS);
  const space: number = cut.lastIndexOf(' ');
  return (space > TITLE_MAX_CHARS / 2 ? cut.substring(0, space) : cut).trim() + '…';
}

// Cards that only show something are kept with the message. Live cards (confirm, quick replies, emergency
// countdown, open scanner) are dropped, so reopening an old chat can never add a medicine or start an SOS.
export function keepOnRestore(a: UiAction): boolean {
  return a.type === 'SHOW_VERDICT' || a.type === 'SHOW_EMERGENCY_CARD' || a.type === 'SHOW_MEDS' ||
    a.type === 'SHOW_ALTERNATIVES' || a.type === 'OPEN_PAGE';
}
