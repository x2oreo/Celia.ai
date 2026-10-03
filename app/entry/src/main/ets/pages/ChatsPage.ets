// Saved conversations with the agent (DESIGN.md §10.2 "Chats"). On this phone only. Tap opens a chat, long press
// renames or deletes it. Opening or starting a chat goes back to the conversation page.

import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AgentCore } from '../agent/AgentCore';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { ChatSummary, TITLE_MAX_CHARS } from '../model/Chat';
import { Routes } from '../common/Routes';
import { EmptyCard, PrimaryButton, ScreenHeader } from '../components/Common';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('ChatsPage');
const DAY_MS: number = 24 * 60 * 60 * 1000;
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function pad(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// "Today 14:05", "Yesterday 09:12" or "2 Oct".
export function chatWhen(ts: number, now: number): string {
  const d: Date = new Date(ts);
  const today: Date = new Date(now);
  today.setHours(0, 0, 0, 0);
  const time: string = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  if (ts >= today.getTime()) {
    return `Today ${time}`;
  }
  if (ts >= today.getTime() - DAY_MS) {
    return `Yesterday ${time}`;
  }
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

@ComponentV2
export struct ChatsPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local chats: ChatSummary[] = [];
  @Local openId: number = -1;
  @Local renameId: number = -1;
  @Local renameText: string = '';
  @Local showRename: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'chats') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    await AgentCore.get().whenSaved();
    this.openId = AgentCore.get().currentChatId();
    this.chats = (await LocalStore.get().listChats()).filter((c: ChatSummary) => c.messageCount > 0);
  }

  private str(r: Resource): string {
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return ctx.resourceManager.getStringSync(r.id);
    } catch (e) {
      return '';
    }
  }

  // Back to the conversation, which reloads the chat that is now open.
  private toConversation(): void {
    if (this.navStack.popToName(Routes.AGENT_CHAT) < 0) {
      this.navStack.replacePath({ name: Routes.AGENT_CHAT, param: null });
    }
  }

  private async open(id: number): Promise<void> {
    if (id !== AgentCore.get().currentChatId() && !(await AgentCore.get().openChat(id))) {
      log.warn(`chat ${id} not found`);
      return;
    }
    this.toConversation();
  }

  private newChat(): void {
    AgentCore.get().newChat();
    this.toConversation();
  }

  private confirmDelete(c: ChatSummary): void {
    this.getUIContext().getPromptAction().showDialog({
      title: this.str($r('app.string.chats_delete_title')),
      message: this.str($r('app.string.chats_delete_body')),
      buttons: [
        { text: this.str($r('app.string.agent_cancel')), color: $r('app.color.ink_2') },
        { text: this.str($r('app.string.chats_delete')), color: $r('app.color.danger') }
      ]
    }).then((r: promptAction.ShowDialogSuccessResponse) => {
      if (r.index === 1) {
        AgentCore.get().deleteChat(c.id).catch((e: Error) => log.warn(`delete chat: ${e.message}`));
      }
    }).catch((e: Error) => log.warn(`delete dialog: ${e.message}`));
  }

  @Builder
  rowMenu(c: ChatSummary) {
    Menu() {
      MenuItem({ content: $r('app.string.chats_rename') })
        .onClick(() => {
          this.renameId = c.id;
          this.renameText = c.title;
          this.showRename = true;
        })
      MenuItem({ content: $r('app.string.chats_delete') })
        .contentFontColor($r('app.color.danger'))
        .onClick(() => {
          this.confirmDelete(c);
        })
    }
  }

  @Builder
  row(c: ChatSummary) {
    Column({ space: 4 }) {
      Text(c.title === '' ? $r('app.string.chats_untitled') : c.title)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 8 }) {
        Text(c.messageCount === 1 ? $r('app.string.chats_count_one', chatWhen(c.updatedAt, Date.now())) :
          $r('app.string.chats_count_many', c.messageCount, chatWhen(c.updatedAt, Date.now())))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .layoutWeight(1)
        if (c.id === this.openId) {
          Text($r('app.string.chats_open_now'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_text'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilityDescription(this.str($r('app.string.a11y_chats_row_hint')))
    .onClick(() => {
      this.open(c.id);
    })
    .bindContextMenu(this.rowMenu(c), ResponseType.LongPress)
  }

  @Builder
  renameSheet() {
    Column({ space: 16 }) {
      Text($r('app.string.chats_rename'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      TextInput({ text: this.renameText, placeholder: $r('app.string.chats_rename_hint') })
        .height(52)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius($r('app.float.radius_m'))
        .maxLength(TITLE_MAX_CHARS)
        .onChange((v: string) => {
          this.renameText = v;
        })
      PrimaryButton({
        label: $r('app.string.chats_rename_save'),
        active: this.renameText.trim().length > 0,
        onTap: () => {
          LocalStore.get().renameChat(this.renameId, this.renameText)
            .catch((e: Error) => log.warn(`rename chat: ${e.message}`));
          this.showRename = false;
        }
      })
    }
    .padding(20)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.chats_title') })
        Scroll() {
          Column({ space: 10 }) {
            PrimaryButton({
              label: $r('app.string.chats_new'),
              icon: $r('app.media.ic_plus'),
              onTap: () => {
                this.newChat();
              }
            })
              .margin({ bottom: 6 })
            if (this.chats.length === 0) {
              EmptyCard({ message: $r('app.string.chats_empty') })
            } else {
              ForEach(this.chats, (c: ChatSummary) => {
                this.row(c)
              }, (c: ChatSummary) => `${c.id}-${c.title}-${c.updatedAt}-${c.id === this.openId}`)
            }
            Text($r('app.string.chats_privacy'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
              .margin({ top: 8 })
          }
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .bindSheet(this.showRename, this.renameSheet(), {
      detents: [SheetSize.MEDIUM],
      showClose: true,
      backgroundColor: $r('app.color.bg'),
      onDisappear: () => {
        this.showRename = false;
      }
    })
  }
}
