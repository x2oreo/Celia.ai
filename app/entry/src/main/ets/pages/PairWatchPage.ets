// Pair watch (DESIGN.md 10.2): type the 6-digit code the watch shows; afterwards this phone reads only that watch.
// Logic lives in data/WatchPairing.ets; this page only shows state and errors.

import { PairOutcome, PairResult, WatchPairing, normalizeCode, shortId } from '../data/WatchPairing';
import { Config } from '../common/Config';
import { dateTime } from '../common/Format';
import { PrimaryButton, SecondaryButton } from '../components/Common';
import { toast } from '../common/Toast';
import { VitalsService } from '../vitals/VitalsService';

@ComponentV2
export struct PairWatchPage {
  @Local paired: boolean = false;
  @Local deviceShort: string = '';
  @Local pairedAt: number = 0;
  @Local replaced: boolean = false;
  @Local code: string = '';
  @Local busy: boolean = false;
  @Local error: PairOutcome | undefined = undefined;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    this.paired = WatchPairing.isPaired();
    this.deviceShort = shortId(Config.WATCH_DEVICE_ID);
    this.pairedAt = await WatchPairing.pairedAt();
    this.replaced = false;
    if (this.paired) {
      const still: boolean | undefined = await WatchPairing.stillPaired();
      this.replaced = still === false;
    }
  }

  // The watch source reads the device id once per poll; restarting it also resets its "newest row" cursor.
  private restartWatchSource(): void {
    if (VitalsService.get().sourceKind() === 'WATCH') {
      VitalsService.get().stop();
      VitalsService.get().start('WATCH');
    }
  }

  private async pair(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.error = undefined;
    const r: PairResult = await WatchPairing.claim(this.code);
    this.busy = false;
    if (r.outcome !== 'PAIRED') {
      this.error = r.outcome;
      return;
    }
    this.code = '';
    this.restartWatchSource();
    toast(this.getUIContext(), $r('app.string.pair_done'));
    await this.refresh();
  }

  private async unpair(): Promise<void> {
    await WatchPairing.unpair();
    this.restartWatchSource();
    toast(this.getUIContext(), $r('app.string.pair_unpaired'));
    await this.refresh();
  }

  private errorText(e: PairOutcome): Resource {
    switch (e) {
      case 'RATE_LIMITED':
        return $r('app.string.pair_err_rate');
      case 'OFFLINE':
        return $r('app.string.pair_err_offline');
      case 'NO_BACKEND':
        return $r('app.string.pair_err_backend');
      default:
        return $r('app.string.pair_err_code');
    }
  }

  // DESIGN.md 6.7: errors are an amber strip (never red); a missing backend is the neutral offline strip.
  @Builder
  strip(e: PairOutcome) {
    Text(this.errorText(e))
      .fontSize($r('app.float.font_small'))
      .fontColor(e === 'NO_BACKEND' ? $r('app.color.status_offline_text') : $r('app.color.risk_possible_text'))
      .width('100%')
      .padding(12)
      .backgroundColor(e === 'NO_BACKEND' ? $r('app.color.status_offline_bg') : $r('app.color.risk_possible_tint'))
      .borderRadius($r('app.float.radius_s'))
  }

  @Builder
  pairedCard() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Image($r('app.media.ic_check')).width(24).height(24).fillColor($r('app.color.ink_2'))
        Column({ space: 2 }) {
          Text($r('app.string.pair_paired_title', this.deviceShort))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          if (this.pairedAt > 0) {
            Text($r('app.string.pair_paired_since', dateTime(this.pairedAt, Date.now())))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      if (this.replaced) {
        Text($r('app.string.pair_replaced'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.risk_possible_text'))
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.risk_possible_tint'))
          .borderRadius($r('app.float.radius_s'))
      }
      SecondaryButton({ label: $r('app.string.pair_unpair'), onTap: () => this.unpair() })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  codeCard() {
    Column({ space: 12 }) {
      Text($r('app.string.pair_intro'))
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.ink'))
      Text($r('app.string.pair_step_1'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
      Text($r('app.string.pair_step_2'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
      TextInput({ text: this.code, placeholder: $r('app.string.pair_code_hint') })
        .type(InputType.Number)
        .maxLength(7)
        .height(56)
        .fontSize($r('app.float.font_title'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius($r('app.float.radius_m'))
        .onChange((v: string) => {
          this.code = v;
          this.error = undefined;
        })
        .onSubmit(() => {
          this.pair();
        })
      if (this.error !== undefined) {
        this.strip(this.error)
      }
      PrimaryButton({
        label: this.busy ? $r('app.string.pair_busy') : $r('app.string.pair_button'),
        active: !this.busy && normalizeCode(this.code) !== '',
        onTap: () => this.pair()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.paired) {
            this.pairedCard()
          }
          // Pairing again (e.g. a new watch) is always possible; the new pairing replaces the old one.
          this.codeCard()
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.pair_nav'))
    .backgroundColor($r('app.color.bg'))
  }
}
