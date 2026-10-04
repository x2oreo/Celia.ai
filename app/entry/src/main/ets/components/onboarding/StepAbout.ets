// Onboarding step 3 "About you": name, date of birth, genotype, ICD and its model. Also hosted by Settings →
// Your profile (pages/HeartProfilePage.ets) without the step heading.
// Never saves: every edit goes back to the page's single draft through onChange.
// Genotype wording: lqts-domain skill (options LQT1 / LQT2 / LQT3 / unknown; unknown → most conservative advice).

import { Genotype, Profile } from '../../model/Profile';
import { copyProfile, GENOTYPES, isoDate, parseIsoDate } from '../../onboarding/OnboardingFlow';
import { OnbHeading, OnbInput } from './OnbParts';

@ComponentV2
export struct StepAbout {
  @Param @Require profile: Profile;
  @Param heading: boolean = true;   // false on Settings → Your profile, which has its own title
  @Event onChange: (profile: Profile) => void = (profile: Profile) => {
  };

  private edit(apply: (p: Profile) => void): void {
    const p: Profile = copyProfile(this.profile);
    apply(p);
    this.onChange(p);
  }

  private pickDate(): void {
    const now: Date = new Date();
    const current: Date | undefined = parseIsoDate(this.profile.dateOfBirth ?? '');
    this.getUIContext().showDatePickerDialog({
      start: new Date(1900, 0, 1),
      end: now,
      selected: current ?? new Date(now.getFullYear() - 30, 0, 1),
      onDateAccept: (d: Date) => {
        this.edit((p: Profile) => {
          p.dateOfBirth = isoDate(d);
        });
      }
    });
  }

  @Builder
  label(text: Resource) {
    Text(text)
      .fontSize($r('app.float.font_small'))
      .fontColor($r('app.color.ink_3'))
  }

  build() {
    Column({ space: 16 }) {
      if (this.heading) {
        OnbHeading({ heading: $r('app.string.onb_about_title'), subtitle: $r('app.string.onb_about_subtitle') })
      }

      OnbInput({
        value: this.profile.name ?? '',
        hint: $r('app.string.onb_name_hint'),
        onInput: (v: string) => this.edit((p: Profile) => {
          p.name = v;
        })
      })

      Row({ space: 8 }) {
        Column({ space: 2 }) {
          this.label($r('app.string.onb_dob'))
          if (this.profile.dateOfBirth !== undefined && this.profile.dateOfBirth !== '') {
            Text(this.profile.dateOfBirth)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
          } else {
            Text($r('app.string.onb_dob_none'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_4'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button($r('app.string.onb_dob_pick'))
          .type(ButtonType.Normal)
          .height($r('app.float.touch_min'))
          .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m') })
          .borderRadius($r('app.float.radius_btn'))
          .fontSize($r('app.float.font_button'))
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.surface_alt'))
          .onClick(() => this.pickDate())
      }
      .width('100%')
      .padding($r('app.float.space_m'))
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_m'))

      Column({ space: 8 }) {
        this.label($r('app.string.onb_genotype'))
        Row({ space: 8 }) {
          ForEach(GENOTYPES, (g: Genotype) => {
            Text(g === 'UNKNOWN' ? $r('app.string.onb_genotype_unknown') : g)
              .fontSize($r('app.float.font_body'))
              .fontColor(this.profile.genotype === g ? $r('app.color.on_accent') : $r('app.color.ink'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height($r('app.float.chip_height'))
              .backgroundColor(this.profile.genotype === g ? $r('app.color.ink') : $r('app.color.surface'))
              .border({ width: this.profile.genotype === g ? 0 : 1.5, color: $r('app.color.border_strong') })
              .borderRadius($r('app.float.radius_s'))
              .accessibilityGroup(true)
              .accessibilitySelected(this.profile.genotype === g)
              .onClick(() => this.edit((p: Profile) => {
                p.genotype = g;
              }))
          }, (g: Genotype) => g)
        }
        .width('100%')
        Text($r('app.string.onb_genotype_help'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Column({ space: 12 }) {
        Row() {
          Column({ space: 2 }) {
            Text($r('app.string.onb_icd'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
            Text($r('app.string.onb_icd_hint'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.profile.hasIcd })
            .selectedColor($r('app.color.brand_accent'))
            .onChange((on: boolean) => this.edit((p: Profile) => {
              p.hasIcd = on;
            }))
        }
        .width('100%')
        if (this.profile.hasIcd) {
          OnbInput({
            value: this.profile.icdModel ?? '',
            hint: $r('app.string.onb_icd_model_hint'),
            onInput: (v: string) => this.edit((p: Profile) => {
              p.icdModel = v;
            })
          })
        }
      }
      .width('100%')
      .padding($r('app.float.space_m'))
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_m'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
