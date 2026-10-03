// What the agent's tools look like in the conversation (DESIGN.md §6.8): a step line while a tool runs, and one
// card per result. Everything shown here comes from deterministic tool payloads, never from model text.

import { LengthMetrics } from '@kit.ArkUI';
import { AlternativesPayload, MedLinePayload, MedsPayload } from '../model/AgentTypes';
import { RiskLevel } from '../model/DrugVerdict';
import { InkButton, RiskBadge, RiskShape, SecondaryButton, TypingDots } from './Common';
import { Motion } from '../common/Motion';

// One tool call, as kept on a conversation turn.
export class ToolStep {
  id: number;
  name: string;
  arg: string;      // the medicine the tool is about (the page fills in "this medicine" when unknown)
  done: boolean;

  constructor(id: number, name: string, arg: string, done: boolean) {
    this.id = id;
    this.name = name;
    this.arg = arg;
    this.done = done;
  }
}

interface ToolArgs {
  name?: string;
  drug_name?: string;
}

// The medicine name out of a tool's JSON arguments ('' if there is none or it doesn't parse).
export function toolArg(argsJson: string): string {
  try {
    const a: ToolArgs = JSON.parse(argsJson) as ToolArgs;
    const raw: string = typeof a.name === 'string' ? a.name : (typeof a.drug_name === 'string' ? a.drug_name : '');
    const t: string = raw.trim().slice(0, 40);
    return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : '';
  } catch (e) {
    return '';
  }
}

export class ToolUi {
  static icon(name: string): Resource {
    switch (name) {
      case 'check_drug':
        return $r('app.media.ic_search');
      case 'get_my_meds':
      case 'add_med':
      case 'suggest_alternatives':
        return $r('app.media.ic_pill');
      case 'get_vitals_summary':
      case 'get_trends':
        return $r('app.media.ic_heart_fill');
      case 'explain_condition':
      case 'prepare_doctor_visit':
        return $r('app.media.ic_doctor');
      case 'get_dose_status':
      case 'open_reminders':
        return $r('app.media.ic_bell');
      case 'open_symptom_log':
        return $r('app.media.ic_history');
      case 'scan_medicine':
        return $r('app.media.ic_camera');
      case 'show_emergency_card':
        return $r('app.media.ic_qr');
      case 'share_emergency_card':
        return $r('app.media.ic_share');
      case 'start_emergency':
        return $r('app.media.ic_phone');
      default:
        return $r('app.media.ic_wave');
    }
  }

  static label(step: ToolStep): ResourceStr {
    const arg: string = step.arg;
    switch (step.name) {
      case 'check_drug':
        return step.done ? $r('app.string.tool_check_drug_done', arg) : $r('app.string.tool_check_drug', arg);
      case 'get_my_meds':
        return step.done ? $r('app.string.tool_get_my_meds_done') : $r('app.string.tool_get_my_meds');
      case 'suggest_alternatives':
        return step.done ? $r('app.string.tool_suggest_alternatives_done', arg) :
          $r('app.string.tool_suggest_alternatives', arg);
      case 'explain_condition':
        return step.done ? $r('app.string.tool_explain_condition_done') : $r('app.string.tool_explain_condition');
      case 'get_vitals_summary':
        return step.done ? $r('app.string.tool_get_vitals_summary_done') : $r('app.string.tool_get_vitals_summary');
      case 'scan_medicine':
        return step.done ? $r('app.string.tool_scan_medicine_done') : $r('app.string.tool_scan_medicine');
      case 'add_med':
        return step.done ? $r('app.string.tool_add_med_done', arg) : $r('app.string.tool_add_med', arg);
      case 'show_emergency_card':
        return step.done ? $r('app.string.tool_show_emergency_card_done') :
          $r('app.string.tool_show_emergency_card');
      case 'start_emergency':
        return step.done ? $r('app.string.tool_start_emergency_done') : $r('app.string.tool_start_emergency');
      case 'share_emergency_card':
        return step.done ? $r('app.string.tool_share_emergency_card_done') :
          $r('app.string.tool_share_emergency_card');
      case 'prepare_doctor_visit':
        return step.done ? $r('app.string.tool_prepare_doctor_visit_done') :
          $r('app.string.tool_prepare_doctor_visit');
      case 'get_dose_status':
        return step.done ? $r('app.string.tool_get_dose_status_done') : $r('app.string.tool_get_dose_status');
      case 'get_trends':
        return step.done ? $r('app.string.tool_get_trends_done') : $r('app.string.tool_get_trends');
      case 'open_symptom_log':
        return step.done ? $r('app.string.tool_open_symptom_log_done') : $r('app.string.tool_open_symptom_log');
      case 'open_reminders':
        return step.done ? $r('app.string.tool_open_reminders_done') : $r('app.string.tool_open_reminders');
      default:
        return step.done ? $r('app.string.tool_generic_done') : $r('app.string.tool_generic');
    }
  }
}

// Square icon well used by the step line and the cards.
@Builder
function iconWell(icon: Resource, dim: number, tint: ResourceColor) {
  Row() {
    Image(icon).width(dim * 0.5).height(dim * 0.5).fillColor(tint)
  }
  .width(dim)
  .height(dim)
  .justifyContent(FlexAlign.Center)
  .backgroundColor($r('app.color.surface_alt'))
  .borderRadius(dim * 0.3)
}

// "Checking Klacid against the QT list …" → "Checked Klacid against the QT list ✓". Neutral ink: a finished
// step is not a verdict, so it never borrows a risk colour or shape.
@ComponentV2
export struct ToolStepRow {
  @Param step: ToolStep = new ToolStep(0, '', '', false);

  build() {
    Row({ space: 8 }) {
      iconWell(ToolUi.icon(this.step.name), 28, $r('app.color.ink_2'))
      Text(ToolUi.label(this.step))
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.step.done ? $r('app.color.ink_3') : $r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      if (this.step.done) {
        Image($r('app.media.ic_check')).width(16).height(16).fillColor($r('app.color.ink_4'))
      } else {
        TypingDots()
      }
    }
    .height(36)
    .padding({ left: 4, right: 12 })
    .constraintSize({ maxWidth: '100%' })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius(18)
    .accessibilityGroup(true)
  }
}

// Shared card shell: surface, 1 vp border, radius 20, with the verdict-reveal motion.
@ComponentV2
struct CardShell {
  @BuilderParam content: () => void = this.emptyContent;
  @Local shown: boolean = false;

  @Builder
  emptyContent() {
  }

  build() {
    Column({ space: 12 }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .borderRadius($r('app.float.radius_ml'))
    .border({ width: 1, color: $r('app.color.border') })
    .opacity(this.shown ? 1 : 0)
    .translate({ y: this.shown ? 0 : 12 })
    .animation(Motion.reduced ? undefined : { duration: Motion.REVEAL_MS, curve: Curve.EaseOut })
    .onAppear(() => {
      this.shown = true;
    })
  }
}

export type ConfirmState = 'OPEN' | 'ACCEPTED' | 'DECLINED';

// Confirm-before-write card (add a medicine, share the emergency card). Ink + secondary, never coral.
@ComponentV2
export struct ConfirmCard {
  @Param icon: Resource = $r('app.media.ic_pill');
  @Param title: ResourceStr = '';
  @Param detail: ResourceStr = '';
  @Param risk: RiskLevel | undefined = undefined;   // deterministic risk of the medicine being added
  @Param state: ConfirmState = 'OPEN';
  @Event onConfirm: () => void = () => {
  };
  @Event onCancel: () => void = () => {
  };

  build() {
    CardShell() {
      Row({ space: 12 }) {
        iconWell(this.icon, 40, $r('app.color.ink'))
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          if (this.detail !== '') {
            Text(this.detail)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_2'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .accessibilityGroup(true)

      if (this.risk !== undefined) {
        RiskBadge({ risk: this.risk, compact: true })
      }

      if (this.state === 'OPEN') {
        Row({ space: 8 }) {
          InkButton({ label: $r('app.string.agent_confirm'), onTap: () => this.onConfirm() })
            .layoutWeight(1)
          SecondaryButton({ label: $r('app.string.agent_cancel'), onTap: () => this.onCancel() })
            .layoutWeight(1)
        }
        .width('100%')
      } else {
        Row({ space: 6 }) {
          if (this.state === 'ACCEPTED') {
            Image($r('app.media.ic_check')).width(16).height(16).fillColor($r('app.color.ink_3'))
          }
          Text(this.state === 'ACCEPTED' ? $r('app.string.agent_confirm_done') :
            $r('app.string.agent_confirm_cancelled'))
            .fontSize($r('app.float.font_badge'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_3'))
        }
      }
    }
  }
}

// "My medicines" as the get_my_meds tool returned them: name, dose and the list's risk badge per line.
@ComponentV2
export struct MedsCard {
  @Param meds: MedsPayload = { medicines: [] };
  @Event onOpen: () => void = () => {
  };

  build() {
    CardShell() {
      Text($r('app.string.agent_meds_title', this.meds.medicines.length))
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_3'))
        .letterSpacing(0.5)
        .textCase(TextCase.UpperCase)

      if (this.meds.medicines.length === 0) {
        Text($r('app.string.agent_meds_empty'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      } else {
        Column() {
          ForEach(this.meds.medicines, (m: MedLinePayload, i: number) => {
            Row({ space: 10 }) {
              Column({ space: 1 }) {
                Text(m.name)
                  .fontSize($r('app.float.font_button'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (m.dose !== '') {
                  Text(m.dose)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.ink_3'))
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              RiskBadge({ risk: m.risk as RiskLevel, compact: true })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { top: i === 0 ? 0 : 1 }, color: $r('app.color.divider') })
            .accessibilityGroup(true)
          }, (m: MedLinePayload, i: number) => `${i}-${m.name}`)
        }
        .width('100%')
      }

      SecondaryButton({ label: $r('app.string.agent_meds_open'), onTap: () => this.onOpen() })
    }
  }
}

// Options the list verified as Not listed. Always carries the caveat: not listed is not a guarantee.
@ComponentV2
export struct AlternativesCard {
  @Param alts: AlternativesPayload = { forDrug: '', alternatives: [], note: '' };

  build() {
    CardShell() {
      Column({ space: 2 }) {
        Text($r('app.string.agent_alt_title'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink_3'))
          .letterSpacing(0.5)
          .textCase(TextCase.UpperCase)
        Text($r('app.string.agent_alt_for', this.alts.forDrug))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
      }
      .alignItems(HorizontalAlign.Start)

      if (this.alts.alternatives.length === 0) {
        Text($r('app.string.agent_alt_none'))
          .fontSize($r('app.float.font_small'))
          .lineHeight(20)
          .fontColor($r('app.color.ink_2'))
      } else {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.alts.alternatives, (name: string) => {
            Row({ space: 6 }) {
              RiskShape({ risk: 'NOT_LISTED', dim: 18 })
              Text(name)
                .fontSize($r('app.float.font_small'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
            }
            .height(36)
            .padding({ left: 10, right: 14 })
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border_strong') })
            .borderRadius(18)
            .accessibilityGroup(true)
            .accessibilityText(name)
          }, (name: string) => name)
        }
        if (this.alts.note !== '') {
          Text(this.alts.note)
            .fontSize($r('app.float.font_small'))
            .lineHeight(20)
            .fontColor($r('app.color.ink_2'))
        }
      }

      Text($r('app.string.agent_alt_caveat'))
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_4'))
    }
  }
}

// The SOS countdown is running (or was cancelled). Risk red is allowed here: this is a real emergency.
@ComponentV2
export struct EmergencyNotice {
  @Param active: boolean = true;
  @Event onOpen: () => void = () => {
  };

  build() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_phone'))
        .width(20)
        .height(20)
        .fillColor(this.active ? $r('app.color.risk_known_text') : $r('app.color.ink_3'))
      Text(this.active ? $r('app.string.agent_emergency_started') : $r('app.string.agent_emergency_cancelled'))
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.active ? $r('app.color.risk_known_text') : $r('app.color.ink_3'))
        .layoutWeight(1)
      if (this.active) {
        Text($r('app.string.agent_open_sos'))
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.risk_known_text'))
          .height($r('app.float.chip_height'))
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1.5, color: $r('app.color.danger') })
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
          .accessibilityText($r('app.string.agent_open_sos'))
          .onClick(() => this.onOpen())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 10, top: 10, bottom: 10 })
    .constraintSize({ minHeight: 56 })
    .backgroundColor(this.active ? $r('app.color.risk_known_tint') : $r('app.color.surface_alt'))
    .border({ width: 1, color: this.active ? $r('app.color.risk_known_border') : $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }
}

// A tappable result the agent put on screen: open the scanner, open the emergency card.
@ComponentV2
export struct ActionTile {
  @Param icon: Resource = $r('app.media.ic_camera');
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      iconWell(this.icon, 40, $r('app.color.ink'))
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.subtitle)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('app.color.ink_4'))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .onClick(() => this.onTap())
  }
}
