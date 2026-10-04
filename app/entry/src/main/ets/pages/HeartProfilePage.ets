// Settings → Your profile: name, date of birth, genotype and ICD, through the onboarding "About you" step without
// its heading. Saved on change (debounced while typing, flushed when the page closes); only these fields are
// written, onto the latest stored profile, so edits made elsewhere in the meantime are kept.

import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { StepAbout } from '../components/onboarding/StepAbout';
import { cloneProfile } from '../emergency/EmergencyDetails';
import { Logger } from '../common/Logger';
import { ScreenHeader } from '../components/Common';

const log: Logger = new Logger('HeartProfilePage');
const SAVE_DELAY_MS: number = 400;

function sameAbout(a: Profile, b: Profile): boolean {
  return (a.name ?? '') === (b.name ?? '') && a.dateOfBirth === b.dateOfBirth && a.genotype === b.genotype &&
    a.hasIcd === b.hasIcd && (a.icdModel ?? '') === (b.icdModel ?? '');
}

@ComponentV2
export struct HeartProfilePage {
  @Local profile: Profile | undefined = undefined;
  @Local loaded: boolean = false;
  @Local saved: boolean = false;
  private pending: Profile | undefined = undefined;
  private timer: number = -1;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.flush();
  }

  private async load(): Promise<void> {
    this.profile = await LocalStore.get().getProfile();
    this.loaded = true;
  }

  private changed(p: Profile): void {
    const was: Profile | undefined = this.profile;
    this.profile = p;
    if (was !== undefined && sameAbout(was, p)) {
      return;   // the step echoes its fields back on first layout: nothing to save
    }
    this.pending = p;
    this.saved = false;
    if (this.timer >= 0) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout(() => {
      this.flush();
    }, SAVE_DELAY_MS);
  }

  private flush(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
    const edited: Profile | undefined = this.pending;
    if (edited === undefined) {
      return;
    }
    this.pending = undefined;
    this.write(edited).then(() => {
      this.saved = true;
    }).catch((e: Error) => log.error(`save failed: ${e.message}`));
  }

  private async write(edited: Profile): Promise<void> {
    const stored: Profile | undefined = await LocalStore.get().getProfile();
    const p: Profile = cloneProfile(stored ?? edited);
    p.name = (edited.name ?? '').trim();
    p.dateOfBirth = edited.dateOfBirth;
    p.genotype = edited.genotype;
    p.hasIcd = edited.hasIcd;
    p.icdModel = edited.icdModel;
    await LocalStore.get().saveProfile(p);
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.profile_title'), settings: false })
        Scroll() {
          Column({ space: 12 }) {
            if (this.profile !== undefined) {
              StepAbout({
                profile: this.profile,
                heading: false,
                onChange: (p: Profile) => {
                  this.changed(p);
                }
              })
              if (this.saved) {
                Text($r('app.string.em_profile_saved'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.ink_3'))
              }
            } else if (this.loaded) {
              Text($r('app.string.emergency_no_profile'))
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink_3'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), top: 8, bottom: 32 })
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
  }
}
