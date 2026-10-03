// Scan a box (design B5): the system scanner reads the barcode, then the verdict rises as a sheet over the dark
// scan surface. The verdict comes from CheckService (deterministic data). A box we cannot read is not an error:
// amber strip plus a "type the name" fallback.

import { CheckParam, Routes } from '../common/Routes';
import { BarcodeResult, scanBox } from '../drugs/BarcodeService';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { Genotype, Profile } from '../model/Profile';
import { VerdictCard } from '../components/VerdictCard';
import { PrimaryButton, StatusStrip } from '../components/Common';
import { Logger } from '../common/Logger';
import { toast } from '../common/Toast';

const log: Logger = new Logger('ScanPage');

@ComponentV2
export struct ScanPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local outcome: CheckOutcome | undefined = undefined;
  @Local genotype: Genotype = 'UNKNOWN';
  @Local alreadyMine: boolean = false;
  @Local unreadable: boolean = false;
  @Local scanning: boolean = false;
  @Local showSheet: boolean = false;

  private async scan(): Promise<void> {
    if (this.scanning) {
      return;
    }
    this.scanning = true;
    this.unreadable = false;
    try {
      const r: BarcodeResult | undefined = await scanBox(this.getUIContext().getHostContext()!);
      if (r === undefined) {
        return;   // cancelled: stay on the scan surface
      }
      if (r.entry === undefined && r.gtin !== '') {
        this.unreadable = true;
        return;
      }
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      this.genotype = profile?.genotype ?? 'UNKNOWN';
      // Not a product code (e.g. a QR with text): check the text itself.
      const result: CheckOutcome = await CheckService.run(r.entry !== undefined ? r.gtin : r.raw, 'BARCODE');
      const meds: Medication[] = await LocalStore.get().listMeds();
      this.alreadyMine = meds.some((m: Medication) => m.ingredient === result.verdict.ingredient);
      this.outcome = result;
      this.showSheet = true;
    } catch (e) {
      log.warn(`scan check failed: ${JSON.stringify(e)}`);
      this.unreadable = true;
    } finally {
      this.scanning = false;
    }
  }

  private async addToMine(): Promise<void> {
    if (this.outcome === undefined) {
      return;
    }
    await LocalStore.get().addMed(this.outcome.verdict.query, this.outcome.verdict.ingredient, '');
    this.alreadyMine = true;
    toast(this.getUIContext(), $r('app.string.meds_added'));
  }

  private found(): string {
    if (this.outcome === undefined) {
      return '';
    }
    return this.outcome.verdict.ingredient === '' ? this.outcome.verdict.query : this.outcome.verdict.ingredient;
  }

  @Builder
  verdictSheet() {
    Scroll() {
      Column() {
        if (this.outcome !== undefined) {
          VerdictCard({
            verdict: this.outcome.verdict,
            combo: this.outcome.combo,
            genotype: this.genotype,
            variant: 'SHEET',
            actionLabel: this.outcome.verdict.ingredient !== '' && !this.alreadyMine ?
              $r('app.string.check_add_to_mine') : '',
            onAction: () => {
              this.addToMine();
            }
          })
        }
      }
      .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          Row() {
            Image($r('app.media.ic_close')).width(20).height(20).fillColor($r('app.color.on_accent'))
          }
          .width($r('app.float.touch_min'))
          .height($r('app.float.touch_min'))
          .justifyContent(FlexAlign.Center)
          .borderRadius(24)
          .backgroundColor($r('app.color.scan_frame'))
          .accessibilityText($r('app.string.a11y_close'))
          .onClick(() => {
            this.navStack.pop();
          })
          if (this.outcome !== undefined && this.outcome.verdict.ingredient !== '') {
            // "Found" is about identification only; the risk is on the sheet.
            Text(`✓ Found: ${this.found()}`)
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.on_accent'))
              .height(36)
              .padding({ left: 14, right: 14 })
              .borderRadius(18)
              .backgroundColor($r('app.color.risk_not_listed'))
              .maxLines(1)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

        Blank()

        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Image($r('app.media.ic_scan')).width(40).height(40).fillColor($r('app.color.scan_text'))
            Text($r('app.string.scan_hint'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.scan_text'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(180)
          .justifyContent(FlexAlign.Center)
          .padding(20)
          .backgroundColor($r('app.color.scan_frame'))
          .border({
            width: 2,
            color: this.outcome !== undefined ? $r('app.color.risk_not_listed') : $r('app.color.scan_text'),
            style: this.outcome !== undefined ? BorderStyle.Solid : BorderStyle.Dashed
          })
          .borderRadius($r('app.float.radius_ml'))

          if (this.unreadable) {
            StatusStrip({
              kind: 'ERROR',
              label: $r('app.string.scan_unknown_box'),
              action: $r('app.string.scan_type_instead'),
              onAction: () => {
                this.navStack.pop();
              }
            })
          }

          PrimaryButton({
            label: this.outcome === undefined && !this.unreadable ? $r('app.string.scan_title') :
              $r('app.string.scan_again'),
            icon: $r('app.media.ic_camera'),
            active: !this.scanning,
            onTap: () => {
              this.scan();
            }
          })
        }
        .padding({ left: 32, right: 32 })

        Blank()
        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.scan_bg'))
    .onReady(() => {
      this.scan();
    })
    .bindSheet(this.showSheet, this.verdictSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.bg'),
      radius: { topLeft: 28, topRight: 28 },
      maskColor: $r('app.color.scrim'),
      onDisappear: () => {
        this.showSheet = false;
      }
    })
  }
}
