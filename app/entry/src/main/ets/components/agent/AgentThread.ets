// The conversation: finished turns, the turn in progress, and the welcome with starter questions shown before
// anything is said (DESIGN.md §10.1 B2). The page owns the data; this file only draws it and reports taps.

import { LengthMetrics } from '@kit.ArkUI';
import { ScanCandidate } from '../../agent/MedicineScanFlow';
import { ChatRole, UiAction } from '../../model/AgentTypes';
import { QuickReplyChip, TypingDots } from '../Common';
import { AgentAvatar } from '../AgentAvatar';
import { ToolStep, ToolStepRow } from '../AgentCards';
import { ActionCard } from './ActionCards';

export type AgentMode = 'VOICE' | 'CHAT';

export class ChatItem {
  id: number;
  role: ChatRole;
  text: string;
  actions: UiAction[];
  candidates: ScanCandidate[];
  tools: ToolStep[];
  ts: number = Date.now();

  constructor(id: number, role: ChatRole, text: string, actions: UiAction[], candidates: ScanCandidate[],
    tools: ToolStep[]) {
    this.id = id;
    this.role = role;
    this.text = text;
    this.actions = actions;
    this.candidates = candidates;
    this.tools = tools;
  }
}

@ComponentV2
export struct AgentThread {
  @Param items: ChatItem[] = [];
  @Param userLive: string = '';        // the user's words while they are still being recognised
  @Param agentLive: string = '';       // the agent's words while it is still speaking
  @Param liveTools: ToolStep[] = [];   // tools of the turn in progress
  @Param hearing: boolean = false;     // the user is talking right now
  @Param busy: boolean = false;
  @Param busyLabel: ResourceStr = '';
  @Param resolved: string[] = [];
  @Param accepted: string[] = [];
  @Param sosClosedAt: number = 0;
  @Param scroller: Scroller = new Scroller();
  @Event onSend: (text: string) => void = (text: string) => {
  };
  @Event onResolve: (actionId: string, accepted: boolean) => void = (actionId: string, accepted: boolean) => {
  };
  @Event onScan: () => void = () => {
  };
  @Event onOpenSos: (a: UiAction) => void = (a: UiAction) => {
  };
  @Event onPickCandidate: (c: ScanCandidate) => void = (c: ScanCandidate) => {
  };

  private runningTool(): ToolStep | undefined {
    return this.liveTools.find((t: ToolStep) => !t.done);
  }

  // The user's words: an ink bubble with the tail bottom-right. Dimmed while they are still being recognised.
  @Builder
  userBubble(text: string, live: boolean) {
    Row() {
      if (text.length > 0) {
        Text(text)
          .fontSize($r('app.float.font_button'))
          .lineHeight(22)
          .fontColor($r('app.color.chat_user_text'))
          .copyOption(live ? CopyOptions.None : CopyOptions.LocalDevice)
      } else {
        TypingDots()
      }
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .constraintSize({ maxWidth: '82%', minHeight: 42 })
    .backgroundColor($r('app.color.chat_user_bg'))
    .borderRadius({ topLeft: 20, topRight: 20, bottomRight: 6, bottomLeft: 20 })
    .opacity(live ? 0.6 : 1)
  }

  // The agent speaks in plain text, no bubble.
  @Builder
  agentText(text: string) {
    Text(text)
      .fontSize($r('app.float.font_body'))
      .fontWeight(FontWeight.Medium)
      .lineHeight(23)
      .fontColor($r('app.color.ink'))
      .constraintSize({ maxWidth: '92%' })
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  toolSteps(tools: ToolStep[]) {
    ForEach(tools, (t: ToolStep) => {
      ToolStepRow({ step: t })
    }, (t: ToolStep) => `${t.id}-${t.done ? 1 : 0}`)
  }

  @Builder
  turn(item: ChatItem) {
    Column({ space: 10 }) {
      this.toolSteps(item.tools)
      if (item.text.length > 0) {
        if (item.role === 'user') {
          this.userBubble(item.text, false)
        } else {
          this.agentText(item.text)
        }
      }
      ForEach(item.actions, (a: UiAction) => {
        ActionCard({
          action: a,
          ts: item.ts,
          resolved: this.resolved,
          accepted: this.accepted,
          sosClosedAt: this.sosClosedAt,
          onSend: (text: string) => {
            this.onSend(text);
          },
          onResolve: (actionId: string, accepted: boolean) => {
            this.onResolve(actionId, accepted);
          },
          onScan: () => {
            this.onScan();
          },
          onOpenSos: (action: UiAction) => {
            this.onOpenSos(action);
          }
        })
      }, (a: UiAction, i: number) => `${item.id}-${i}-${a.type}`)
      if (item.candidates.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(item.candidates, (c: ScanCandidate) => {
            QuickReplyChip({
              label: c.ingredient !== '' && c.ingredient !== c.name.toLowerCase() ? `${c.name} (${c.ingredient})` :
                c.name,
              onTap: () => {
                this.onPickCandidate(c);
              }
            })
          }, (c: ScanCandidate) => c.name)
        }
      }
    }
    .width('100%')
    .alignItems(item.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  // The turn in progress: what the user is saying, the tools that are running, what the agent is saying.
  @Builder
  liveTurn() {
    if (this.userLive !== '' || this.hearing) {
      ListItem() {
        Column() {
          this.userBubble(this.userLive, true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.End)
      }
    }
    if (this.liveTools.length > 0 || this.agentLive !== '' || this.busy) {
      ListItem() {
        Column({ space: 10 }) {
          this.toolSteps(this.liveTools)
          if (this.agentLive !== '') {
            this.agentText(this.agentLive)
          } else if (this.runningTool() === undefined && (this.busy || this.liveTools.length > 0)) {
            TypingDots({ label: this.busy ? this.busyLabel : '' })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  build() {
    List({ space: 16, scroller: this.scroller }) {
      ForEach(this.items, (item: ChatItem) => {
        ListItem() {
          this.turn(item)
        }
      }, (item: ChatItem) => `${item.id}`)
      this.liveTurn()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .contentStartOffset(4)
    .contentEndOffset(12)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

// Shown instead of the thread while nothing has been said: a hint (voice) or the avatar and intro (chat), then the
// starter questions.
@ComponentV2
export struct AgentWelcome {
  @Param mode: AgentMode = 'VOICE';
  @Event onStarter: (label: Resource) => void = (label: Resource) => {
  };

  @Builder
  starter(label: Resource) {
    QuickReplyChip({
      label: label,
      onTap: () => {
        this.onStarter(label);
      }
    })
  }

  @Builder
  starters() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center,
      space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      this.starter($r('app.string.agent_starter_ibuprofen'))
      this.starter($r('app.string.agent_starter_avoid'))
      this.starter($r('app.string.agent_starter_meds'))
    }
  }

  // One row that scrolls sideways: under the full-size orb there is no room for wrapped chips.
  @Builder
  starterRow() {
    Scroll() {
      Row({ space: 8 }) {
        this.starter($r('app.string.agent_starter_ibuprofen'))
        this.starter($r('app.string.agent_starter_avoid'))
        this.starter($r('app.string.agent_starter_meds'))
      }
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .align(Alignment.Start)
  }

  build() {
    if (this.mode === 'VOICE') {
      Column({ space: 12 }) {
        Text($r('app.string.agent_voice_idle_hint'))
          .fontSize($r('app.float.font_small'))
          .lineHeight(20)
          .fontColor($r('app.color.ink_3'))
          .textAlign(TextAlign.Center)
          .padding({ left: 20, right: 20 })
        this.starterRow()
      }
      .width('100%')
      .height('100%')
      .clip(true)
    } else {
      Scroll() {
        Column({ space: 20 }) {
          AgentAvatar({ dim: 96 })
          Text($r('app.string.agent_welcome_title'))
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text($r('app.string.agent_welcome'))
            .fontSize($r('app.float.font_small'))
            .lineHeight(20)
            .fontColor($r('app.color.ink_3'))
            .textAlign(TextAlign.Center)
          this.starters()
        }
        .width('100%')
        .padding({ top: 40, left: 28, right: 28 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
  }
}
