// One card per UI action of an agent reply (DESIGN.md §6.8). Cards are drawn from deterministic tool payloads, never
// from model text. Navigation happens here; anything that changes the conversation goes back to the page as an event.

import { LengthMetrics } from '@kit.ArkUI';
import { QUICK_REPLY_UNWELL } from '../../agent/AgentCore';
import {
  AddMedPayload, AlternativesPayload, ConfirmPayload, InteractionFinding, MedsPayload, OpenPagePayload,
  QuickRepliesPayload, UiAction, VerdictCardPayload
} from '../../model/AgentTypes';
import { RiskLevel } from '../../model/DrugVerdict';
import { CheckParam, DoctorPrepParam, Routes, TabIndex } from '../../common/Routes';
import { TabRequest } from '../../common/TabRequest';
import { QuickReplyChip } from '../Common';
import { VerdictCard } from '../VerdictCard';
import { ActionTile, AlternativesCard, ConfirmCard, EmergencyNotice, MedsCard } from '../AgentCards';
import { confirmStateOf, verdictOf } from './AgentLogic';

@ComponentV2
export struct ActionCard {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Require @Param action: UiAction;
  @Param ts: number = 0;               // when the turn was shown
  @Param resolved: string[] = [];      // actionIds of confirm cards already answered
  @Param accepted: string[] = [];      // of those, the confirmed ones
  @Param sosClosedAt: number = 0;      // last time the SOS countdown was cancelled
  @Event onSend: (text: string) => void = (text: string) => {
  };
  @Event onResolve: (actionId: string, accepted: boolean) => void = (actionId: string, accepted: boolean) => {
  };
  @Event onScan: () => void = () => {
  };
  @Event onOpenSos: (a: UiAction) => void = (a: UiAction) => {
  };

  private vp(): VerdictCardPayload {
    return JSON.parse(this.action.payload) as VerdictCardPayload;
  }

  private addMed(): AddMedPayload {
    return JSON.parse(this.action.payload) as AddMedPayload;
  }

  private confirmId(): string {
    return (JSON.parse(this.action.payload) as ConfirmPayload).actionId;
  }

  private pagePayload(): OpenPagePayload {
    return JSON.parse(this.action.payload) as OpenPagePayload;
  }

  @Builder
  verdictCard() {
    Column({ space: 8 }) {
      VerdictCard({
        verdict: verdictOf(this.vp()),
        variant: 'INLINE',
        actionLabel: $r('app.string.agent_open_check'),
        onAction: () => {
          this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(this.vp().query, false, 'CHAT'));
        }
      })
      if (this.vp().findings.length > 0) {
        Column({ space: 4 }) {
          Text($r('app.string.agent_findings'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.risk_possible_text'))
          ForEach(this.vp().findings, (f: InteractionFinding) => {
            Text(`• ${f.detail}`)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
          }, (f: InteractionFinding, i: number) => `${i}-${f.kind}`)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.risk_possible_tint'))
        .borderRadius($r('app.float.radius_s'))
      }
    }
    .width('100%')
  }

  // OPEN_PAGE: one tile per page value (model/AgentTypes OpenPagePayload.page). Add new pages here.
  @Builder
  openPage() {
    if (this.pagePayload().page === 'DOCTOR_PREP') {
      ActionTile({
        icon: $r('app.media.ic_doctor'),
        title: $r('app.string.home_doctor'),
        subtitle: $r('app.string.agent_open_brief_sub'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.DOCTOR_PREP, new DoctorPrepParam(this.pagePayload().specialty));
        }
      })
    } else if (this.pagePayload().page === 'REMINDERS') {
      ActionTile({
        icon: $r('app.media.ic_bell'),
        title: $r('app.string.rem_title'),
        subtitle: $r('app.string.agent_open_reminders_sub'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.REMINDERS, null);
        }
      })
    } else if (this.pagePayload().page === 'TRENDS') {
      ActionTile({
        icon: $r('app.media.ic_wave'),
        title: $r('app.string.trends_title'),
        subtitle: $r('app.string.trends_subtitle'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.TRENDS, null);
        }
      })
    }
  }

  build() {
    if (this.action.type === 'SHOW_VERDICT') {
      this.verdictCard()
    } else if (this.action.type === 'QUICK_REPLIES') {
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach((JSON.parse(this.action.payload) as QuickRepliesPayload).options, (o: string) => {
          QuickReplyChip({
            label: o,
            chipStyle: o === QUICK_REPLY_UNWELL ? 'ESCALATION' : 'DEFAULT',
            onTap: () => {
              this.onSend(o);
            }
          })
        }, (o: string) => o)
      }
    } else if (this.action.type === 'ADD_MED') {
      ConfirmCard({
        icon: $r('app.media.ic_pill'),
        title: $r('app.string.agent_add_med_title'),
        detail: `${this.addMed().name} ${this.addMed().dose}`.trim(),
        risk: this.addMed().risk as RiskLevel,
        state: confirmStateOf(this.resolved, this.accepted, this.addMed().actionId),
        onConfirm: () => {
          this.onResolve(this.addMed().actionId, true);
        },
        onCancel: () => {
          this.onResolve(this.addMed().actionId, false);
        }
      })
    } else if (this.action.type === 'SHARE_EMERGENCY_CARD') {
      ConfirmCard({
        icon: $r('app.media.ic_share'),
        title: $r('app.string.agent_share_card_title'),
        detail: $r('app.string.agent_share_card_sub'),
        state: confirmStateOf(this.resolved, this.accepted, this.confirmId()),
        onConfirm: () => {
          this.onResolve(this.confirmId(), true);
        },
        onCancel: () => {
          this.onResolve(this.confirmId(), false);
        }
      })
    } else if (this.action.type === 'SHOW_MEDS') {
      MedsCard({
        meds: JSON.parse(this.action.payload) as MedsPayload,
        onOpen: () => {
          this.navStack.clear();
          TabRequest.open(TabIndex.MEDICINES);
        }
      })
    } else if (this.action.type === 'SHOW_ALTERNATIVES') {
      AlternativesCard({ alts: JSON.parse(this.action.payload) as AlternativesPayload })
    } else if (this.action.type === 'START_EMERGENCY') {
      EmergencyNotice({
        active: this.ts > this.sosClosedAt,
        onOpen: () => {
          this.onOpenSos(this.action);
        }
      })
    } else if (this.action.type === 'SHOW_EMERGENCY_CARD') {
      ActionTile({
        icon: $r('app.media.ic_qr'),
        title: $r('app.string.agent_card_title'),
        subtitle: $r('app.string.agent_card_sub'),
        onTap: () => {
          this.navStack.clear();
          TabRequest.open(TabIndex.EMERGENCY);
        }
      })
    } else if (this.action.type === 'OPEN_MED_SCAN') {
      ActionTile({
        icon: $r('app.media.ic_camera'),
        title: $r('app.string.agent_scan'),
        subtitle: $r('app.string.agent_scan_sub'),
        onTap: () => {
          this.onScan();
        }
      })
    } else if (this.action.type === 'OPEN_PAGE') {
      this.openPage()
    }
  }
}
