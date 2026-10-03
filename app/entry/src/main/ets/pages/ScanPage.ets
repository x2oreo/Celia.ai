// Scan a box (design B5): the system scanner reads the barcode, then the verdict rises as a sheet over the dark
// scan surface. The verdict comes from CheckService (deterministic data). A box we cannot read is not an error:
// amber strip plus a "type the name" fallback. A real box we don't know yet (any country) is looked up online
// (/box-identify: registries first, AI web search last) and confirmed by the user; otherwise it is taught once. A
// Celia emergency-card QR opens the card.

import { common } from '@kit.AbilityKit';
import { Routes } from '../common/Routes';
import { BarcodeResult, learnOnlineBox, scanBox } from '../drugs/BarcodeService';
import { BoxCandidate, confirmBox, identifyBox, IdentifyReply } from '../drugs/BoxIdentifyClient';
import { BoxCandidateSheet, LookupPhase } from '../components/BoxCandidateSheet';
import { Config } from '../common/Config';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { BoxInfo } from '../model/BoxInfo';
import { Genotype, Profile } from '../model/Profile';
import { VerdictCard } from '../components/VerdictCard';
import { MedicineInfoCard } from '../components/MedicineInfoCard';
import { TeachBoxForm } from '../components/TeachBoxForm';
import { CardPayload, parseCardLink, parsePayloadJson } from '../emergency/CardLink';
import { parseShareLink, ShareService, viewerUrl } from '../share/ShareService';
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
  @Local teachGtin: string = '';
  @Local showTeach: boolean = false;
  @Local showLookup: boolean = false;
  @Local lookupPhase: LookupPhase = 'FAST';
  @Local candidate: BoxCandidate | undefined = undefined;
  private lookupId: number = 0;   // a newer scan or "type instead" makes older lookups stale

  // Unknown barcode: quick lookup first (registries, product databases), AI web search only if that misses.
  private async lookUp(gtin: string): Promise<void> {
    const id: number = ++this.lookupId;
    this.candidate = undefined;
    this.lookupPhase = 'FAST';
    this.showLookup = true;
    const quick: IdentifyReply = await identifyBox(gtin, 'fast', '');
    if (id !== this.lookupId) {
      return;
    }
    let found: BoxCandidate | undefined = quick.candidate;
    if (found === undefined) {
      this.lookupPhase = 'DEEP';
      const deep: IdentifyReply = await identifyBox(gtin, 'deep', quick.hint);
      if (id !== this.lookupId) {
        return;
      }
      found = deep.candidate;
    }
    if (found === undefined) {
      this.teachInstead();
      return;
    }
    this.candidate = found;
    this.lookupPhase = 'FOUND';
  }

  private teachInstead(): void {
    this.lookupId++;
    this.showLookup = false;
    this.showTeach = true;
  }

  private async acceptCandidate(): Promise<void> {
    const c: BoxCandidate | undefined = this.candidate;
    if (c === undefined) {
      return;
    }
    this.lookupId++;
    this.showLookup = false;
    await learnOnlineBox(c.gtin, c.brand, c.ingredients, c.strength, c.form, c.source, c.sourceUrl);
    confirmBox(c).catch((e: Error) => log.warn(`confirm failed: ${e.message}`));
    await this.check(c.gtin);
  }

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
      if (r.box === undefined && r.gtin !== '') {
        // A real product code we don't know yet: look it up online, else teach it once; then check it.
        this.teachGtin = r.gtin;
        if (Config.hasBackend()) {
          this.lookUp(r.gtin).catch((e: Error) => {
            log.warn(`box lookup failed: ${e.message}`);
            this.teachInstead();
          });
        } else {
          this.showTeach = true;
        }
        return;
      }
      // A short encrypted Celia link: a card opens here (fetched and decrypted on this phone).
      const share: string[] | undefined = r.box === undefined ? parseShareLink(r.raw) : undefined;
      if (share !== undefined && share[0] === 'card') {
        const json: string | undefined = await ShareService.fetchShared(share[1], share[2]);
        const shared: CardPayload | undefined = json !== undefined ? parsePayloadJson(json) : undefined;
        if (shared !== undefined) {
          this.navStack.replacePath({ name: Routes.CARD_VIEW, param: shared });
          return;
        }
        this.unreadable = true;
        return;
      }
      if (share !== undefined && share[0] === 'report') {
        // A doctor report link: it is a web page for a doctor, so open it in the browser (decrypted there). The URL
        // is rebuilt from the parsed id and key on our own viewer, never the scanned text, so a crafted QR that
        // merely ends like a Celia link can't send the user to another site.
        const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await ctx.openLink(viewerUrl('report', share[1], share[2]));
        return;
      }
      const card: CardPayload | undefined = r.box === undefined ? parseCardLink(r.raw) : undefined;
      if (card !== undefined) {
        // Someone's emergency-card QR: show the card (decoded on device, nothing stored).
        this.navStack.replacePath({ name: Routes.CARD_VIEW, param: card });
        return;
      }
      // Not a product code (e.g. a QR with text): check the text itself.
      await this.check(r.box !== undefined ? r.gtin : r.raw);
    } catch (e) {
      log.warn(`scan check failed: ${JSON.stringify(e)}`);
      this.unreadable = true;
    } finally {
      this.scanning = false;
    }
  }

  private async check(query: string): Promise<void> {
    const profile: Profile | undefined = await LocalStore.get().getProfile();
    this.genotype = profile?.genotype ?? 'UNKNOWN';
    const result: CheckOutcome = await CheckService.run(query, 'BARCODE');
    const meds: Medication[] = await LocalStore.get().listMeds();
    const key: string = result.verdict.ingredient !== '' ? result.verdict.ingredient :
      (result.box?.ingredients ?? '');
    this.alreadyMine = key !== '' && meds.some((m: Medication) => m.ingredient === key);
    this.outcome = result;
    this.showSheet = true;
  }

  private async addToMine(): Promise<void> {
    if (this.outcome === undefined) {
      return;
    }
    // From a box: keep the brand as the name and the strength as the dose.
    const box: BoxInfo | undefined = this.outcome.box;
    const ingredient: string = this.outcome.verdict.ingredient !== '' ? this.outcome.verdict.ingredient :
      (box?.ingredients ?? '');
    await LocalStore.get().addMed(box?.brand ?? this.outcome.verdict.query, ingredient, box?.strength ?? '');
    this.alreadyMine = true;
    toast(this.getUIContext(), $r('app.string.meds_added'));
  }

  private found(): string {
    if (this.outcome === undefined) {
      return '';
    }
    if (this.outcome.box !== undefined) {
      return this.outcome.box.brand;
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
            actionLabel: (this.outcome.verdict.ingredient !== '' || this.outcome.box !== undefined) &&
              !this.alreadyMine ? $r('app.string.check_add_to_mine') : '',
            onAction: () => {
              this.addToMine();
            }
          })
          if (this.outcome.box !== undefined) {
            MedicineInfoCard({
              box: this.outcome.box,
              onForgotten: () => {
                this.showSheet = false;
                this.outcome = undefined;
              }
            })
              .margin({ top: 16 })
          }
        }
      }
      .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')   // fill the sheet so a long verdict scrolls instead of being clipped
    .align(Alignment.Top)
  }

  @Builder
  lookupSheet() {
    BoxCandidateSheet({
      gtin: this.teachGtin,
      phase: this.lookupPhase,
      candidate: this.candidate,
      onYes: () => {
        this.acceptCandidate().catch((e: Error) => {
          log.warn(`online box check failed: ${e.message}`);
          this.unreadable = true;
        });
      },
      onNo: () => {
        this.teachInstead();
      }
    })
  }

  @Builder
  teachSheet() {
    TeachBoxForm({
      gtin: this.teachGtin,
      onSaved: (gtin: string) => {
        this.showTeach = false;
        this.check(gtin).catch((e: Error) => {
          log.warn(`taught box check failed: ${JSON.stringify(e)}`);
          this.unreadable = true;
        });
      }
    })
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
          if (this.outcome !== undefined && (this.outcome.verdict.ingredient !== '' || this.outcome.box !== undefined)) {
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
        .bindSheet(this.showLookup, this.lookupSheet(), {
          detents: [SheetSize.MEDIUM, SheetSize.LARGE],
          showClose: true,
          backgroundColor: $r('app.color.bg'),
          radius: { topLeft: 28, topRight: 28 },
          onDisappear: () => {
            if (this.showLookup) {
              this.lookupId++;   // closed by the user: drop the pending lookup
              this.showLookup = false;
            }
          }
        })

        Blank()
        Blank()
      }
      .width('100%')
      .height('100%')
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
    .hideTitleBar(true)
    .backgroundColor($r('app.color.scan_bg'))
    .onReady(() => {
      this.scan();
    })
    // One sheet per node: a second bindSheet on the same node replaces the first (the verdict sheet never opened),
    // so the verdict sheet sits on the page column, the online-lookup sheet on the scan frame, the teach sheet here.
    .bindSheet(this.showTeach, this.teachSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: true,
      backgroundColor: $r('app.color.bg'),
      onDisappear: () => {
        this.showTeach = false;
      }
    })
  }
}
