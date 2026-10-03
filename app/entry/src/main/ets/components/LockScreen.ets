// Lock overlay (F-45). Private data stays hidden; the emergency help is one tap away for anyone.

import { AppLock } from '../common/AppLock';
import { PrimaryButton, SecondaryButton } from './Common';
import { toast } from '../common/Toast';

@ComponentV2
export struct LockScreen {
  @Event onEmergency: () => void = () => {
  };

  build() {
    Column({ space: 16 }) {
      Blank()
      Image($r('app.media.ic_lock')).width(56).height(56).fillColor($r('app.color.brand_accent'))
      Text($r('app.string.lock_title'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text($r('app.string.lock_subtitle'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Blank()
      PrimaryButton({
        label: $r('app.string.lock_unlock'),
        icon: $r('app.media.ic_lock'),
        onTap: () => {
          AppLock.unlock((ok: boolean) => {
            if (!ok) {
              toast(this.getUIContext(), $r('app.string.lock_failed'));
            }
          });
        }
      })
      SecondaryButton({
        label: $r('app.string.lock_emergency'),
        icon: $r('app.media.ic_hand'),
        onTap: () => this.onEmergency()
      })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor($r('app.color.page_bg'))
    .onClick(() => {
      // swallow taps so nothing underneath is reachable
    })
  }
}
