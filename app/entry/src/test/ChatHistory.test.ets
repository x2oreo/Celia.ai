// Agent chats: storage, titles, which cards survive a restore, "new chat" phrases and switching chats.
// Runs without a backend (List.test forces Config offline) and with the memory-only store.

import { describe, it, expect } from '@ohos/hypium';
import { AgentCore } from '../main/ets/agent/AgentCore';
import { ChatCommands } from '../main/ets/agent/ChatCommands';
import { LocalStore, parseStoredActions } from '../main/ets/data/LocalStore';
import { AgentReply, ChatMessage, UiAction } from '../main/ets/model/AgentTypes';
import { ChatSummary, MAX_CHATS, MAX_CHAT_MESSAGES, StoredChatMessage, chatTitle, keepOnRestore } from '../main/ets/model/Chat';

function act(type: string): UiAction {
  const a: UiAction = { type: type as 'SHOW_VERDICT', payload: '{}' };
  return a;
}

export default function chatHistoryTest() {
  describe('ChatModel', () => {
    it('titleIsFirstMessageShortenedAtAWord', 0, () => {
      expect(chatTitle('  Can I take   ibuprofen? ')).assertEqual('Can I take ibuprofen?');
      const long: string = chatTitle('What should I avoid with my genotype when I travel to Bulgaria next summer?');
      expect(long.length <= 49).assertTrue();
      expect(long.endsWith('…')).assertTrue();
      expect(long.includes('  ')).assertFalse();
    });

    it('onlyDisplayCardsSurviveARestore', 0, () => {
      expect(keepOnRestore(act('SHOW_VERDICT'))).assertTrue();
      expect(keepOnRestore(act('SHOW_MEDS'))).assertTrue();
      expect(keepOnRestore(act('ADD_MED'))).assertFalse();
      expect(keepOnRestore(act('START_EMERGENCY'))).assertFalse();
      expect(keepOnRestore(act('QUICK_REPLIES'))).assertFalse();
      expect(keepOnRestore(act('SHARE_EMERGENCY_CARD'))).assertFalse();
    });
  });

  describe('ChatStore', () => {
    it('storesMessagesNamesAndDeletesChats', 0, async () => {
      const store: LocalStore = LocalStore.get();
      const chat: ChatSummary = await store.createChat();
      await store.addChatMessage(chat.id, 'assistant', 'Hi', []);
      await store.addChatMessage(chat.id, 'user', 'Can I take Klacid?', [act('SHOW_VERDICT'), act('ADD_MED')]);
      const msgs: StoredChatMessage[] = await store.listChatMessages(chat.id);
      expect(msgs.length).assertEqual(2);
      expect(msgs[1].actions.length).assertEqual(1);
      const saved: ChatSummary | undefined = await store.getChat(chat.id);
      expect(saved?.title).assertEqual('Can I take Klacid?');
      expect(saved?.messageCount).assertEqual(2);
      await store.renameChat(chat.id, 'Antibiotics');
      expect((await store.getChat(chat.id))?.title).assertEqual('Antibiotics');
      await store.deleteChat(chat.id);
      expect((await store.getChat(chat.id)) === undefined).assertTrue();
      expect((await store.listChatMessages(chat.id)).length).assertEqual(0);
    });

    it('keepsOnlyTheNewestMessages', 0, async () => {
      const store: LocalStore = LocalStore.get();
      const chat: ChatSummary = await store.createChat();
      for (let i = 0; i < MAX_CHAT_MESSAGES + 5; i++) {
        await store.addChatMessage(chat.id, 'user', `m${i}`, []);
      }
      const msgs: StoredChatMessage[] = await store.listChatMessages(chat.id);
      expect(msgs.length).assertEqual(MAX_CHAT_MESSAGES);
      expect(msgs[0].text).assertEqual('m5');
      expect((await store.getChat(chat.id))?.title).assertEqual('m0');
      await store.deleteChat(chat.id);
    });

    it('keepsAtMostFiftyChats', 0, async () => {
      const store: LocalStore = LocalStore.get();
      const made: number[] = [];
      for (let i = 0; i < MAX_CHATS + 3; i++) {
        const c: ChatSummary = await store.createChat();
        await store.addChatMessage(c.id, 'user', `chat ${i}`, []);
        made.push(c.id);
      }
      const all: ChatSummary[] = await store.listChats();
      expect(all.length <= MAX_CHATS).assertTrue();
      expect(all.some((c: ChatSummary) => c.id === made[made.length - 1])).assertTrue();
      for (const c of all) {
        await store.deleteChat(c.id);
      }
    });

    it('corruptCardsDropCardsNotTheMessage', 0, () => {
      expect(parseStoredActions('{oops').length).assertEqual(0);
      expect(parseStoredActions('{"type":"X"}').length).assertEqual(0);
      expect(parseStoredActions('[]').length).assertEqual(0);
    });
  });

  describe('ChatCommands', () => {
    it('matchesShortNewChatCommands', 0, () => {
      expect(ChatCommands.isNewChat('New chat')).assertTrue();
      expect(ChatCommands.isNewChat('start a new conversation please')).assertTrue();
      expect(ChatCommands.isNewChat('Save this chat and start a new one.')).assertTrue();
      expect(ChatCommands.isNewChat('start over')).assertTrue();
      expect(ChatCommands.isNewChat('Okay, new chat!')).assertTrue();
    });

    it('ignoresQuestionsThatOnlyMentionChats', 0, () => {
      expect(ChatCommands.isNewChat('Can I take ibuprofen?')).assertFalse();
      expect(ChatCommands.isNewChat('how do I start a new chat in the app and keep my medicines?')).assertFalse();
      expect(ChatCommands.isNewChat('new chat with my doctor about ondansetron')).assertFalse();
    });
  });

  describe('AgentChats', () => {
    it('newChatPhraseSavesAndSwitches', 0, async () => {
      const core: AgentCore = AgentCore.get();
      core.newChat();
      await core.send('Can I take clarithromycin?');
      await core.whenSaved();
      const first: number = core.currentChatId();
      expect(first >= 0).assertTrue();
      const r: AgentReply = await core.send('new chat');
      await core.whenSaved();
      expect(r.text.startsWith('Saved.')).assertTrue();
      const second: number = core.currentChatId();
      expect(second !== first).assertTrue();
      // The new chat starts with the agent's reply only; the command was not stored anywhere.
      const now: ChatMessage[] = core.getHistory();
      expect(now.length).assertEqual(1);
      expect(now[0].role).assertEqual('assistant');
      const old: StoredChatMessage[] = await LocalStore.get().listChatMessages(first);
      expect(old.some((m: StoredChatMessage) => m.text === 'new chat')).assertFalse();
      expect((await LocalStore.get().getChat(first))?.title).assertEqual('Can I take clarithromycin?');
    });

    it('openChatRestoresDisplayCardsOnly', 0, async () => {
      const core: AgentCore = AgentCore.get();
      core.newChat();
      await core.send('Can I take clarithromycin?');
      await core.whenSaved();
      const id: number = core.currentChatId();
      core.newChat();
      expect(core.getHistory().length).assertEqual(0);
      expect(await core.openChat(id)).assertTrue();
      const h: ChatMessage[] = core.getHistory();
      expect(h.length).assertEqual(2);
      const cards: UiAction[] = h[1].actions ?? [];
      expect(cards.some((a: UiAction) => a.type === 'SHOW_VERDICT')).assertTrue();
      expect(cards.every((a: UiAction) => keepOnRestore(a))).assertTrue();
    });

    it('deletingTheOpenChatStartsAnEmptyOne', 0, async () => {
      const core: AgentCore = AgentCore.get();
      core.newChat();
      await core.send('Can I take clarithromycin?');
      await core.whenSaved();
      const id: number = core.currentChatId();
      await core.deleteChat(id);
      expect(core.currentChatId()).assertEqual(-1);
      expect(core.getHistory().length).assertEqual(0);
      expect((await LocalStore.get().getChat(id)) === undefined).assertTrue();
    });

    it('emptyChatSaysItIsAlreadyNew', 0, async () => {
      const core: AgentCore = AgentCore.get();
      core.newChat();
      const r: AgentReply = await core.send('start over');
      expect(r.text.startsWith('This is already a new chat')).assertTrue();
    });
  });
}
