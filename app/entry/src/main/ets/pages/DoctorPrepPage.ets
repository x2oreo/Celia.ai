// Doctor visit prep (F-31): pick the specialist → safety brief from my own data → copy or share.

import { common } from '@kit.AbilityKit';
import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { BriefSection, briefText, buildBrief, Specialty, SPECIALTIES, specialtyName } from '../doctor/DoctorPrep';
import { copyText } from '../common/Clipboard';
import { shareText } from '../common/Share';
import { toast } from '../common/Toast';
import { PrimaryButton, SecondaryButton } from '../components/Common';

@ComponentV2
export struct DoctorPrepPage {
  @Local specialty: Specialty = 'GP';
  @Local sections: BriefSection[] = [];
  @Local profile: Profile | undefined = undefined;

  aboutToAppear(): void {
    this.build_();
  }

  private async build_(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    if (this.profile === undefined) {
      this.sections = [];
      return;
    }
    this.sections = buildBrief(this.profile, await LocalStore.get().listMeds(), await LocalStore.get().listScans(),
      await LocalStore.get().listEvents(), this.specialty, Date.now());
  }

  private text(): string {
    return briefText(this.sections, this.specialty, Date.now());
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text($r('app.string.dp_intro'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(SPECIALTIES, (s: Specialty) => {
              Text(specialtyName(s))
                .fontSize($r('app.float.font_small'))
                .fontColor(this.specialty === s ? $r('app.color.chat_user_text') : $r('app.color.ink'))
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.specialty === s ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
                .border({ width: this.specialty === s ? 0 : 1.5, color: $r('app.color.border_strong') })
                .borderRadius(100)
                .onClick(() => {
                  this.specialty = s;
                  this.build_();
                })
            }, (s: Specialty) => s)
          }
          .width('100%')

          if (this.profile === undefined) {
            Text($r('app.string.emergency_no_profile'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_3'))
          } else {
            ForEach(this.sections, (sec: BriefSection) => {
              Column({ space: 6 }) {
                Text(sec.title)
                  .fontSize($r('app.float.font_small'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_text'))
                ForEach(sec.lines, (l: string) => {
                  Row({ space: 8 }) {
                    Text('•').fontColor($r('app.color.ink_3'))
                    Text(l)
                      .fontSize($r('app.float.font_body'))
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                  }
                  .alignItems(VerticalAlign.Top)
                  .width('100%')
                }, (l: string, i: number) => `${i}-${l}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_m'))
            }, (sec: BriefSection) => `${this.specialty}-${sec.title}`)

            PrimaryButton({
              label: $r('app.string.dp_share'),
              icon: $r('app.media.ic_share'),
              onTap: () => {
                shareText(this.getUIContext().getHostContext() as common.UIAbilityContext, 'Long QT safety brief',
                  this.text());
              }
            })
            SecondaryButton({
              label: $r('app.string.dp_copy'),
              onTap: async () => {
                const ok: boolean = await copyText(this.text());
                toast(this.getUIContext(), ok ? $r('app.string.dp_copied') : $r('app.string.error_generic'));
              }
            })
            Text($r('app.string.disclaimer'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_4'))
              .width('100%')
              .textAlign(TextAlign.Center)
          }
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.home_doctor'))
    .backgroundColor($r('app.color.bg'))
  }
}
