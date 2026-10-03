// The conversation: finished turns, the turn in progress, and the welcome with starter questions shown before
// anything is said (DESIGN.md §10.1 B2). The page owns the data; this file only draws it and reports taps.

import { LengthMetrics } from '@kit.ArkUI';
import { ScanCandidate } from '../../agent/MedicineScanFlow';
import { ChatRole, UiAction } from '../../model/AgentTypes';
import { QuickReplyChip, TypingDots } from '../Common';
import { AgentAvatar } from '../AgentAvatar';
import { ToolStep, ToolStepRow } from '../AgentCards';
import { ActionCard } from './ActionCards';
import { Motion } from '../../common/Motion';
import { Routes } from '../../common/Routes';

export type AgentMode = 'VOICE' | 'CHAT';

const LONG_CAPTION: number = 140;   // characters; above this the live caption uses the smaller size

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
  @Param endPad: number = 12;          // room at the end, so the last turn clears a floating dock
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
    .contentEndOffset(this.endPad)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

// Live captions (DESIGN.md §10.1a, screen 03): the turn in progress instead of a chat list. "You: …" in small ink-3,
// the agent's sentence large and growing word by word, the tool steps as pills, then the cards of this turn sliding
// in under the captions, so a verdict never needs a page change. Cards come from deterministic payloads only.
@ComponentV2
export struct AgentCaptions {
  @Param items: ChatItem[] = [];
  @Param userLive: string = '';
  @Param agentLive: string = '';
  @Param liveTools: ToolStep[] = [];
  @Param hearing: boolean = false;
  @Param busy: boolean = false;
  @Param busyLabel: ResourceStr = '';
  @Param resolved: string[] = [];
  @Param accepted: string[] = [];
  @Param sosClosedAt: number = 0;
  @Param endPad: number = 12;
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

  private lastIndex(role: ChatRole): number {
    for (let i = this.items.length - 1; i >= 0; i--) {
      if (this.items[i].role === role) {
        return i;
      }
    }
    return -1;
  }

  // What the user said last: the words being recognised, else their last finished turn.
  private youText(): string {
    if (this.userLive !== '') {
      return this.userLive;
    }
    const i: number = this.lastIndex('user');
    return i >= 0 ? this.items[i].text : '';
  }

  // The agent's finished answer to that, if it has arrived. While the user is talking again it steps aside.
  private answer(): ChatItem | undefined {
    if (this.userLive !== '' || this.hearing) {
      return undefined;
    }
    const a: number = this.lastIndex('assistant');
    return a >= 0 && a > this.lastIndex('user') ? this.items[a] : undefined;
  }

  private agentText(): string {
    if (this.agentLive !== '') {
      return this.agentLive;
    }
    return this.answer()?.text ?? '';
  }

  private tools(): ToolStep[] {
    if (this.liveTools.length > 0) {
      return this.liveTools;
    }
    return this.answer()?.tools ?? [];
  }

  private waiting(): boolean {
    return this.agentText() === '' && this.tools().every((t: ToolStep) => t.done) &&
      (this.busy || this.liveTools.length > 0);
  }

  @Builder
  cards(item: ChatItem) {
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
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
          .animation({ duration: Motion.REVEAL_MS, curve: Curve.EaseOut }))
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

  build() {
    Scroll() {
      Column({ space: 14 }) {
        if (this.youText() !== '' || this.hearing) {
          Text(this.youText() === '' ? $r('app.string.agent_you_blank') :
            $r('app.string.agent_you_said', this.youText()))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .lineHeight(23)
            .fontColor($r('app.color.ink_3'))
            .opacity(this.userLive !== '' ? 0.6 : 1)
            .width('100%')
        }
        if (this.agentText() !== '') {
          // Large for a sentence or two; a longer answer steps down so it stays readable without scrolling far.
          Text(this.agentText())
            .fontSize(this.agentText().length > LONG_CAPTION ? $r('app.float.font_subtitle') : $r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .lineHeight(this.agentText().length > LONG_CAPTION ? 25 : 31)
            .fontColor($r('app.color.ink'))
            .copyOption(CopyOptions.LocalDevice)
            .width('100%')
        }
        ForEach(this.tools(), (t: ToolStep) => {
          ToolStepRow({ step: t })
        }, (t: ToolStep) => `${t.id}-${t.done ? 1 : 0}`)
        if (this.waiting()) {
          TypingDots({ label: this.busy ? this.busyLabel : '' })
        }
        if (this.agentLive === '' && this.answer() !== undefined) {
          this.cards(this.answer() as ChatItem)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 8, bottom: this.endPad })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

// Shown while nothing has been said (DESIGN.md §10.1a, screen 02). Voice: the agent's line, the starter questions
// ("Ask me") and the features one tap away ("Or go straight to"). Typing: the same without the line's orb above it.
@ComponentV2
export struct AgentWelcome {
  @Param mode: AgentMode = 'VOICE';
  @Param line: string = '';            // the agent's sentence, same as on Today
  @Param endPad: number = 12;
  @Event onStarter: (label: Resource) => void = (label: Resource) => {
  };
  @Event onOpen: (route: string) => void = (route: string) => {
  };

  @Builder
  caps(text: Resource) {
    Text(text)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.7)
      .fontColor($r('app.color.ink_3'))
      .textCase(TextCase.UpperCase)
      .margin({ top: 6 })
  }

  @Builder
  starter(label: Resource) {
    QuickReplyChip({
      label: label,
      onTap: () => {
        this.onStarter(label);
      }
    })
  }

  // Feature chip: surface-alt, no border, so it reads as "a place" next to the outlined questions.
  @Builder
  place(label: Resource, route: string) {
    Text(label)
      .fontSize($r('app.float.font_button'))
      .fontWeight(600)
      .fontColor($r('app.color.ink'))
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(22)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .accessibilityText(label)
      .onClick(() => {
        this.onOpen(route);
      })
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        if (this.mode === 'CHAT') {
          AgentAvatar({ dim: 40 })
            .margin({ top: 16 })
        }
        Text(this.line === '' ? $r('app.string.agent_welcome_title') : this.line)
          .fontSize($r('app.float.font_title_3'))
          .fontWeight(FontWeight.Bold)
          .lineHeight(27)
          .fontColor($r('app.color.ink'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 6 })
        Column({ space: 10 }) {
          this.caps($r('app.string.agent_ask_me'))
          this.starter($r('app.string.agent_starter_ibuprofen'))
          this.starter($r('app.string.agent_starter_week'))
          this.starter($r('app.string.agent_starter_avoid'))
          this.caps($r('app.string.agent_go_to'))
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            this.place($r('app.string.home_scan_box'), Routes.SCAN)
            this.place($r('app.string.home_log_feel'), Routes.SYMPTOM_LOG)
            this.place($r('app.string.doctor_visit'), Routes.DOCTOR_PREP)
            this.place($r('app.string.trends_title'), Routes.TRENDS)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: this.endPad })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
