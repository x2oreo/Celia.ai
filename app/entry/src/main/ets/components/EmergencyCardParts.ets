// Shared parts of the emergency card (DESIGN.md §11, "For first responders" v3 and "Emergency tab card"). Used by
// the Emergency tab (glance layer) and the responder view (full card). Always light: card_fixed_* only. Plain
// design-system shapes: cards with a 1 vp border, caps labels, the risk shape + word; no bands or side rules.

import { AvoidGroup } from '../emergency/Responder';
import { GenotypeFacts, GENERAL_PRECAUTIONS, LQTS_OVERVIEW, ProtocolStep } from '../emergency/LqtsFacts';
import { RiskShape } from './Common';

// Caps label in a card colour: 12 fp / 700, +0.06em; alert colour for the critical ones.
@ComponentV2
export struct CardCaps {
  @Param text: ResourceStr = '';
  @Param alert: boolean = false;

  build() {
    Text(this.text)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.7)
      .textCase(TextCase.UpperCase)
      .fontColor(this.alert ? $r('app.color.card_fixed_alert') : $r('app.color.card_fixed_ink_3'))
  }
}

// Who this is: initial avatar, name, condition, quiet chips (genotype, age, ICD).
@ComponentV2
export struct CardIdentity {
  @Param initial: string = '';     // '' → heart icon in the avatar
  @Param name: string = '';        // '' → condition only
  @Param condition: string = '';
  @Param chips: string[] = [];

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          if (this.initial.length > 0) {
            Text(this.initial)
              .fontSize($r('app.float.font_title_3'))
              .fontWeight(800)
              .fontColor($r('app.color.card_fixed_alert'))
          } else {
            Image($r('app.media.ic_heart_fill')).width(22).height(22).fillColor($r('app.color.card_fixed_alert'))
          }
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor($r('app.color.card_fixed_alert_tint'))
        .accessibilityLevel('no')
        Column({ space: 2 }) {
          if (this.name.length > 0) {
            Text(this.name)
              .fontSize($r('app.float.font_title'))
              .fontWeight(800)
              .fontColor($r('app.color.card_fixed_ink'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(this.condition)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.card_fixed_ink_2'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.chips, (c: string) => {
          Text(c)
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.card_fixed_ink'))
            .height(28)
            .padding({ left: 12, right: 12 })
            .border({ width: 1, color: $r('app.color.card_fixed_border') })
            .borderRadius(14)
            .margin({ right: 6, bottom: 6 })
        }, (c: string) => c)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
  }
}

// "Do not give": the Known-risk notice (risk tint, 1 vp known-risk border, radius 16) with the risk shape + word.
// Either grouped drug lists (responder view, from the dataset) or one translated sentence (Emergency tab card).
@ComponentV2
export struct AvoidPanel {
  @Param title: ResourceStr = '';   // '' → the translated sentence carries "Do NOT give" itself
  @Param sub: ResourceStr = '';
  @Param text: string = '';
  @Param groups: AvoidGroup[] = [];
  @Param firstGroups: number = 0;   // > 0: show this many groups, the rest behind "Show all"
  @Local all: boolean = false;

  private shown(): AvoidGroup[] {
    return this.all || this.firstGroups <= 0 ? this.groups : this.groups.slice(0, this.firstGroups);
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        RiskShape({ risk: 'KNOWN_RISK', dim: 24 })
          .accessibilityLevel('no-hide-descendants')
        if (this.title !== '') {
          Text(this.title)
            .fontSize($r('app.float.font_headline'))
            .fontWeight(800)
            .fontColor($r('app.color.card_fixed_alert'))
            .layoutWeight(1)
        } else {
          Text(this.text)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
            .layoutWeight(1)
        }
      }
      .alignItems(this.title === '' ? VerticalAlign.Top : VerticalAlign.Center)
      .width('100%')
      if (this.sub !== '') {
        Text(this.sub)
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.card_fixed_ink_2'))
      }
      ForEach(this.shown(), (g: AvoidGroup) => {
        Column({ space: 2 }) {
          Text(g.title)
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
          Text(g.drugs.join(', '))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.card_fixed_ink'))
          if (g.note.length > 0) {
            Text(g.note)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.card_fixed_alert'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (g: AvoidGroup) => g.title)
      if (this.firstGroups > 0 && this.groups.length > this.firstGroups) {
        Text(this.all ? $r('app.string.em_avoid_less') : $r('app.string.em_avoid_more', this.groups.length))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_alert'))
          .height($r('app.float.touch_min'))
          .onClick(() => {
            this.all = !this.all;
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.card_fixed_alert_tint'))
    .border({ width: 1, color: $r('app.color.card_fixed_alert_border') })
    .borderRadius(16)
  }
}

// For clinicians: one plain card. Numbered steps, then torsades, do not use and the genotype notes, each under a
// caps label and split by a divider. Everything comes from emergency/LqtsFacts.ets.
@ComponentV2
export struct ClinicianBlock {
  @Param steps: ProtocolStep[] = [];
  @Param torsadesIntro: string = '';
  @Param torsades: string[] = [];
  @Param doNotUse: string[] = [];
  @Param typeTitle: ResourceStr = '';
  @Param typeNotes: string[] = [];

  @Builder
  line(mark: string, text: string, alert: boolean) {
    Row({ space: 10 }) {
      Text(mark)
        .fontSize($r('app.float.font_small'))
        .fontWeight(800)
        .fontColor(alert ? $r('app.color.card_fixed_alert') : $r('app.color.card_fixed_ink_3'))
        .width(16)
      Text(text)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.card_fixed_ink'))
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      Column({ space: 2 }) {
        CardCaps({ text: $r('app.string.em_clin_title'), alert: true })
        Text($r('app.string.em_clin_sub'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.card_fixed_ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      ForEach(this.steps, (s: ProtocolStep, i: number) => {
        Row({ space: 12 }) {
          Text(`${i + 1}`)
            .fontSize($r('app.float.font_small'))
            .fontWeight(800)
            .fontColor($r('app.color.card_fixed_bg'))
            .textAlign(TextAlign.Center)
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_fixed_ink'))
          Column({ space: 2 }) {
            Text(s.step)
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.card_fixed_ink'))
            Text(s.detail)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.card_fixed_ink_2'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .accessibilityGroup(true)
      }, (s: ProtocolStep, i: number) => `${i}-${s.step}`)

      Divider().color($r('app.color.card_fixed_border'))
      CardCaps({ text: $r('app.string.em_clin_torsades') })
      Text(this.torsadesIntro)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.card_fixed_ink_2'))
      ForEach(this.torsades, (t: string, i: number) => {
        this.line(String.fromCharCode(65 + i), t, false)
      }, (t: string, i: number) => `${i}-${t}`)

      Divider().color($r('app.color.card_fixed_border'))
      CardCaps({ text: $r('app.string.em_clin_do_not'), alert: true })
      ForEach(this.doNotUse, (t: string) => {
        this.line('✕', t, true)
      }, (t: string) => t)

      if (this.typeNotes.length > 0) {
        Divider().color($r('app.color.card_fixed_border'))
        CardCaps({ text: this.typeTitle })
        ForEach(this.typeNotes, (t: string) => {
          this.line('•', t, false)
        }, (t: string) => t)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.card_fixed_bg'))
    .border({ width: 1, color: $r('app.color.card_fixed_border') })
    .borderRadius(20)
  }
}

// "About long QT syndrome": a plain card whose header row folds it; inside, the overview and this person's type
// (or general precautions when the type is not known).
@ComponentV2
export struct AboutLqts {
  @Param facts: GenotypeFacts | undefined = undefined;
  @Local open: boolean = false;

  @Builder
  bullets(items: string[]) {
    Column({ space: 6 }) {
      ForEach(items, (t: string) => {
        Row({ space: 10 }) {
          Text('•')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.card_fixed_ink_3'))
          Text(t)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.card_fixed_ink'))
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (t: string) => t)
    }
    .width('100%')
  }

  @Builder
  fact(label: ResourceStr, value: string) {
    Column({ space: 4 }) {
      CardCaps({ text: label })
      Text(value)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.card_fixed_ink'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text($r('app.string.em_about_title'))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_ink'))
          .layoutWeight(1)
        Image($r('app.media.ic_chevron_down'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.card_fixed_ink_3'))
          .rotate({ angle: this.open ? 180 : 0 })
          .animation({ duration: 180, curve: Curve.EaseOut })
      }
      .width('100%')
      .constraintSize({ minHeight: $r('app.float.touch_min') })
      .accessibilityGroup(true)
      .accessibilityDescription(this.open ? $r('app.string.a11y_expanded') : $r('app.string.a11y_collapsed'))
      .onClick(() => {
        this.open = !this.open;
      })

      if (this.open) {
        ForEach(LQTS_OVERVIEW, (p: string) => {
          Text(p)
            .fontSize($r('app.float.font_body'))
            .lineHeight(22)
            .fontColor($r('app.color.card_fixed_ink_2'))
        }, (p: string) => p)
        if (this.facts !== undefined) {
          Divider().color($r('app.color.card_fixed_border'))
          CardCaps({ text: this.facts.genotype === 'UNKNOWN' ? $r('app.string.em_about_general') :
            $r('app.string.em_about_this_type') })
          Column({ space: 2 }) {
            Text(this.facts.name)
              .fontSize($r('app.float.font_headline'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.card_fixed_ink'))
            if (this.facts.gene.length > 0) {
              Text(`${this.facts.gene}. ${this.facts.share}.`)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.card_fixed_ink_3'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          CardCaps({ text: $r('app.string.em_about_triggers') })
          this.bullets(this.facts.triggers)
          if (this.facts.ecg.length > 0) {
            this.fact($r('app.string.em_about_ecg'), this.facts.ecg)
          }
          this.fact($r('app.string.em_about_treatment'), this.facts.treatment)
          if (this.facts.genotype === 'UNKNOWN') {
            CardCaps({ text: $r('app.string.em_about_precautions') })
            this.bullets(GENERAL_PRECAUTIONS)
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 6, bottom: this.open ? 16 : 6 })
    .backgroundColor($r('app.color.card_fixed_bg'))
    .border({ width: 1, color: $r('app.color.card_fixed_border') })
    .borderRadius(20)
  }
}
