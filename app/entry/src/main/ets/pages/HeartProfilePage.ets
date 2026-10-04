// Settings → Your profile: the photo (phone only, can be shown on the emergency card), then name, date of birth,
// genotype and ICD through the onboarding "About you" step without its heading. Saved on change (debounced while
// typing, flushed when the page closes); only these fields are written, onto the latest stored profile, so edits
// made elsewhere in the meantime are kept.

import { LocalStore } from '../data/LocalStore';
import { CardField, Profile } from '../model/Profile';
import { StepAbout } from '../components/onboarding/StepAbout';
import { cloneProfile, shownOnCard, withShown } from '../emergency/EmergencyDetails';
import { ProfilePhoto } from '../data/ProfilePhoto';
import { ProfileAvatar } from '../components/ProfileAvatar';
import { toast } from '../common/Toast';
import { Logger } from '../common/Logger';
import { QuietButton, ScreenHeader, SecondaryButton } from '../components/Common';

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
  @Local hasPhoto: boolean = false;
  @Local picking: boolean = false;
  private stopPhoto: () => void = () => {
  };
  private pending: Profile | undefined = undefined;
  private timer: number = -1;

  aboutToAppear(): void {
    this.load();
    this.hasPhoto = ProfilePhoto.exists();
    this.stopPhoto = ProfilePhoto.onChange(() => {
      this.hasPhoto = ProfilePhoto.exists();
    });
  }

  aboutToDisappear(): void {
    this.stopPhoto();
    this.flush();
  }

  private async pickPhoto(): Promise<void> {
    this.picking = true;
    try {
      await ProfilePhoto.pick();
    } catch (e) {
      log.warn(`photo failed: ${JSON.stringify(e)}`);
      toast(this.getUIContext(), $r('app.string.photo_failed'));
    } finally {
      this.picking = false;
    }
  }

  // The "Show on emergency card" switch: written straight away onto the stored profile.
  private async setPhotoShown(on: boolean): Promise<void> {
    const stored: Profile | undefined = await LocalStore.get().getProfile();
    if (stored === undefined) {
      return;
    }
    const p: Profile = cloneProfile(stored);
    p.hiddenOnCard = withShown(p.hiddenOnCard, CardField.PHOTO, on);
    await LocalStore.get().saveProfile(p);
    if (this.profile !== undefined) {
      const local: Profile = cloneProfile(this.profile);
      local.hiddenOnCard = p.hiddenOnCard;
      this.profile = local;
    }
  }

  @Builder
  photoBlock() {
    Column({ space: 12 }) {
      ProfileAvatar({ side: 96, name: this.profile?.name ?? '' })
      Row({ space: 8 }) {
        if (this.picking) {
          LoadingProgress().width(28).height(28).color($r('app.color.brand_accent'))
        } else {
          SecondaryButton({
            label: this.hasPhoto ? $r('app.string.photo_change') : $r('app.string.photo_add'),
            icon: $r('app.media.ic_camera'),
            fill: false,
            onTap: () => {
              this.pickPhoto();
            }
          })
          if (this.hasPhoto) {
            QuietButton({
              label: $r('app.string.photo_remove'),
              fill: false,
              onTap: () => {
                ProfilePhoto.remove();
              }
            })
          }
        }
      }
      if (this.hasPhoto && this.profile !== undefined) {
        Row({ space: 12 }) {
          Text($r('app.string.photo_on_card'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: shownOnCard(this.profile, CardField.PHOTO) })
            .selectedColor($r('app.color.brand_accent'))
            .accessibilityText($r('app.string.photo_on_card'))
            .onChange((on: boolean) => {
              this.setPhotoShown(on).catch((e: Error) => log.error(`photo switch failed: ${e.message}`));
            })
        }
        .width('100%')
        .constraintSize({ minHeight: $r('app.float.touch_min') })
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_m'))
      }
      Text($r('app.string.photo_hint'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 8 })
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
              this.photoBlock()
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
