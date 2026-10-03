// Pieces shared by the doctor visit pages (DESIGN.md §10.1a "07 Doctor visits"): the specialty icon, the gallery
// card and the small pills. Everything shown comes from the saved visit and the fixed visit plan, never from AI text.

import { Specialty, specialtyName } from '../doctor/DoctorPrep';
import { DoctorVisit, visitWhen } from '../doctor/VisitStore';
import { knownNames, PlanGroup, visitPlan } from '../doctor/VisitPlan';
import { dayLabel } from '../common/Format';
import { RiskShape } from './Common';

export function specialtyIcon(s: Specialty): Resource {
  switch (s) {
    case 'CARDIOLOGIST':
      return $r('app.media.ic_tab_heart');
    case 'DENTIST':
      return $r('app.media.ic_tooth');
    case 'SURGEON':
      return $r('app.media.ic_hand');
    case 'ANESTHESIOLOGIST':
      return $r('app.media.ic_pill');
    case 'PSYCHIATRIST':
      return $r('app.media.ic_wave');
    case 'EMERGENCY':
      return $r('app.media.ic_tab_emergency');
    default:
      return $r('app.media.ic_doctor');
  }
}

// Icon well on the brand tint.
@ComponentV2
export struct SpecialtyWell {
  @Param specialty: Specialty = 'GP';
  @Param dim: number = 40;

  build() {
    Row() {
      Image(specialtyIcon(this.specialty))
        .width(this.dim / 2)
        .height(this.dim / 2)
        .fillColor($r('app.color.brand_accent'))
    }
    .width(this.dim)
    .height(this.dim)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.brand_accent_soft'))
    .borderRadius($r('app.float.radius_s'))
    .accessibilityLevel('no')
  }
}

// Small quiet pill for a fixed word ("Infection", "ICD: no").
@ComponentV2
export struct QuietPill {
  @Param label: ResourceStr = '';

  build() {
    Text(this.label)
      .fontSize($r('app.float.font_badge'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.ink_2'))
      .maxLines(1)
      .height(28)
      .padding({ left: 10, right: 10 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(14)
  }
}

// "6 to avoid": the known-risk shape with a count. The number comes from the QT dataset.
@ComponentV2
export struct AvoidCount {
  @Param count: number = 0;

  build() {
    Row({ space: 5 }) {
      RiskShape({ risk: 'KNOWN_RISK', dim: 16 })
        .accessibilityLevel('no-hide-descendants')
      Text($r('app.string.dv_avoid_count', this.count))
        .fontSize($r('app.float.font_micro'))
        .fontWeight(800)
        .fontColor($r('app.color.risk_known_text'))
    }
    .height(24)
    .padding({ left: 4, right: 8 })
    .backgroundColor($r('app.color.risk_known_tint'))
    .borderRadius(12)
    .accessibilityGroup(true)
  }
}

// One visit in the gallery. `wide` is the latest visit across the full width; the others sit in a two-column grid.
@ComponentV2
export struct VisitCard {
  @Param visit: DoctorVisit | undefined = undefined;
  @Param wide: boolean = false;
  @Event onTap: () => void = () => {
  };

  private plan(): PlanGroup[] {
    return this.visit === undefined ? [] : visitPlan(this.visit.reason, this.visit.specialty);
  }

  private reasonLine(v: DoctorVisit): ResourceStr {
    if (v.reason.length > 0) {
      return v.reason;
    }
    const titles: string[] = this.plan().map((g: PlanGroup) => g.title);
    return titles.length > 0 ? titles.join(' · ') : $r('app.string.dv_no_reason');
  }

  build() {
    if (this.visit !== undefined) {
      Column({ space: 8 }) {
        Row({ space: 10 }) {
          SpecialtyWell({ specialty: this.visit.specialty, dim: this.wide ? 44 : 40 })
          if (this.wide) {
            Column({ space: 2 }) {
              Text(specialtyName(this.visit.specialty))
                .fontSize($r('app.float.font_headline'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.visit.doctor.length > 0 ? `${this.visit.doctor} · ${dayLabel(visitWhen(this.visit), Date.now())}` :
                dayLabel(visitWhen(this.visit), Date.now()))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.ink_3'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.ic_chevron_right')).width(18).height(18).fillColor($r('app.color.ink_4'))
          } else {
            Blank()
            Text(dayLabel(visitWhen(this.visit), Date.now()))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
          }
        }
        .width('100%')

        if (!this.wide) {
          Text(specialtyName(this.visit.specialty))
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.reasonLine(this.visit))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_2'))
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (!this.wide) {
          Blank()
        }
        Row({ space: 8 }) {
          if (knownNames(this.plan()).length > 0) {
            AvoidCount({ count: knownNames(this.plan()).length })
          }
          if (this.visit.sharedAt > 0) {
            Text($r('app.string.dv_shared'))
              .fontSize($r('app.float.font_micro'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink_3'))
          }
        }
        .width('100%')
      }
      .width('100%')
      .height(this.wide ? undefined : 172)
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_l'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
      .accessibilityGroup(true)
      .onClick(() => this.onTap())
    }
  }
}
