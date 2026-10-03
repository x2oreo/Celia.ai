// Emergency details (Workstream B4), opened from Settings. Hosts the shared EmergencyDetailsForm and saves what it
// emits: debounced while typing, and once more when the page closes so nothing is lost.

import { LocalStore } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { EmergencyDetailsForm } from '../components/EmergencyDetailsForm';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('EmergencyProfilePage');
const SAVE_DELAY_MS: number = 400;

@ComponentV2
export struct EmergencyProfilePage {
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
    this.profile = p;
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
    const p: Profile | undefined = this.pending;
    if (p === undefined) {
      return;
    }
    this.pending = undefined;
    LocalStore.get().saveProfile(p).then(() => {
      this.saved = true;
    }).catch((e: Error) => log.error(`save failed: ${e.message}`));
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text($r('app.string.em_profile_intro'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
            .width('100%')
          if (this.profile !== undefined) {
            EmergencyDetailsForm({
              profile: this.profile,
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
        .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.em_profile_title'))
    .backgroundColor($r('app.color.bg'))
  }
}
